import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';

import 'api_exception.dart';

class GeoapifyApi {
  static const String defaultBaseUrl = 'api.geoapify.com';
  static const String apiKeyFromEnvironment =
      String.fromEnvironment('GEOAPIFY_API_KEY');

  // Munich city centre. A bias changes ranking without excluding other places.
  static const double _munichLatitude = 48.137154;
  static const double _munichLongitude = 11.576124;
  static const LatLng _munichCenter = LatLng(_munichLatitude, _munichLongitude);

  final String apiKey;
  final String baseUrl;
  final Client client;
  final Map<String, List<Place>> _cache = {};

  GeoapifyApi({
    this.apiKey = apiKeyFromEnvironment,
    this.baseUrl = defaultBaseUrl,
    Client? client,
  }) : client = client ?? Client();

  Future<List<Place>> search(String query, {LatLng? searchCenter}) async {
    if (apiKey.isEmpty) {
      throw ApiException(
        'Geoapify API key is missing. '
        'Set GEOAPIFY_API_KEY with --dart-define.',
      );
    }

    final normalizedQuery = query.trim();
    final center = searchCenter ?? _munichCenter;
    final cacheKey =
        '${normalizedQuery.toLowerCase()}|${center.latitude.toStringAsFixed(3)},'
        '${center.longitude.toStringAsFixed(3)}';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    var places = await _requestAutocomplete(
      normalizedQuery,
      localOnly: true,
      center: center,
    );
    if (places.isEmpty) {
      places = await _requestAutocomplete(
        normalizedQuery,
        localOnly: false,
        center: center,
      );
    }
    _cache[cacheKey] = places;
    return places;
  }

  Future<List<Place>> _requestAutocomplete(
    String query, {
    required bool localOnly,
    required LatLng center,
  }) async {
    final uri = Uri.https(baseUrl, '/v1/geocode/autocomplete', {
      'text': query,
      'format': 'json',
      'lang': 'de',
      'limit': '15',
      'filter': localOnly ? 'rect:${_boundingBox(center)}' : 'countrycode:de',
      'bias': 'proximity:${center.longitude},${center.latitude}',
      'apiKey': apiKey,
    });
    final response = await client.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'com.munichways.app/flutter',
    }).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw ApiException('Error retrieving places: ${response.body}');
    }

    log.d(response.body);
    final json = response.jsonBody() as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? const [];
    final placesByAddress = <String, Place>{};
    final queryContainsHouseNumber =
        RegExp(r'\b\d+\s*[a-zA-Z]?\b').hasMatch(query);

    for (final result in results.cast<Map<String, dynamic>>()) {
      final lat = result['lat'];
      final lon = result['lon'];
      if (lat is! num || lon is! num) {
        continue;
      }

      final generalizeStreet =
          !queryContainsHouseNumber && _isStreetAddress(result);
      final displayName = _displayName(
        result,
        generalizeStreet: generalizeStreet,
      );
      if (displayName.isEmpty) {
        continue;
      }

      final place = Place(
        displayName,
        LatLng(lat.toDouble(), lon.toDouble()),
      );
      placesByAddress.putIfAbsent(
        _addressKey(result, generalizeStreet: generalizeStreet),
        () => place,
      );
    }

    return placesByAddress.values.toList();
  }

  static String _boundingBox(LatLng center) =>
      '${center.longitude - 0.35},${center.latitude - 0.25},'
      '${center.longitude + 0.35},${center.latitude + 0.25}';

  static String _displayName(
    Map<String, dynamic> result, {
    required bool generalizeStreet,
  }) {
    final addressLine1 = _value(result, 'address_line1');
    final name = _value(result, 'name');
    final street = _value(result, 'street');
    final houseNumber = _value(result, 'housenumber');
    final postcode = _value(result, 'postcode');
    final city = _value(result, 'city');

    final mainPart = generalizeStreet
        ? street
        : addressLine1.isNotEmpty
            ? addressLine1
            : [name, street, houseNumber]
                .where((part) => part.isNotEmpty)
                .toSet()
                .join(' ');
    final cityPart =
        [postcode, city].where((part) => part.isNotEmpty).join(' ');
    return [mainPart, cityPart]
        .where((part) => part.isNotEmpty)
        .toSet()
        .join(', ');
  }

  /// Postcode and district are intentionally ignored so minor OSM address
  /// differences do not produce duplicate entries.
  static String _addressKey(
    Map<String, dynamic> result, {
    required bool generalizeStreet,
  }) {
    final street = _normalizedValue(result, 'street');
    final houseNumber = _normalizedValue(result, 'housenumber');
    final city = _normalizedValue(result, 'city');
    final name = _normalizedValue(result, 'name');
    final key = [
      street,
      if (!generalizeStreet) houseNumber,
      city,
      if (!generalizeStreet) name,
    ].where((part) => part.isNotEmpty).join('|');
    return key.isNotEmpty ? key : _value(result, 'place_id');
  }

  static String _normalizedValue(
    Map<String, dynamic> result,
    String key,
  ) =>
      _value(result, key).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _value(Map<String, dynamic> result, String key) =>
      result[key]?.toString().trim() ?? '';

  static bool _isStreetAddress(Map<String, dynamic> result) {
    final street = _normalizedValue(result, 'street');
    final addressLine = _normalizedValue(result, 'address_line1');
    if (street.isEmpty || addressLine.isEmpty) return false;
    return addressLine == street ||
        addressLine.startsWith('$street ') &&
            RegExp(r'\d').hasMatch(addressLine.substring(street.length));
  }
}
