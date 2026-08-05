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
  static const int _maxReverseAddressLookups = 5;

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

    final results = await Future.wait([
      _requestAutocomplete(
        normalizedQuery,
        localOnly: false,
        center: center,
      ),
      _requestAutocomplete(
        normalizedQuery,
        localOnly: true,
        center: center,
      ),
    ]);
    final places = _mergePlaces(
      worldwide: results[0],
      local: results[1],
    );
    _cache[cacheKey] = places;
    return places;
  }

  /// Worldwide results come first so an exact city such as "Berlin" is not
  /// hidden by loosely matching streets or POIs inside the Munich bounds.
  static List<Place> _mergePlaces({
    required List<Place> worldwide,
    required List<Place> local,
  }) {
    final placesByName = <String, Place>{};
    for (final place in [...worldwide, ...local]) {
      final normalizedName = place.displayName?.toLowerCase().trim();
      final key = normalizedName != null && normalizedName.isNotEmpty
          ? normalizedName
          : '${place.latLng.latitude},${place.latLng.longitude}';
      placesByName.putIfAbsent(
        key,
        () => place,
      );
    }
    return placesByName.values.toList(growable: false);
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
      if (localOnly) 'filter': 'rect:${_boundingBox(center)}',
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
    final rawResults = results.cast<Map<String, dynamic>>();
    var reverseLookups = 0;
    final enrichedResults = await Future.wait(rawResults.map((result) {
      if (_needsReverseAddress(result) &&
          reverseLookups < _maxReverseAddressLookups) {
        reverseLookups++;
        return _withReverseAddress(result);
      }
      return Future.value(result);
    }));
    final placesByAddress = <String, Place>{};
    final queryContainsHouseNumber =
        RegExp(r'\b\d+\s*[a-zA-Z]?\b').hasMatch(query);

    for (final result in enrichedResults) {
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

  static bool _needsReverseAddress(Map<String, dynamic> result) =>
      _value(result, 'name').isNotEmpty &&
      _value(result, 'street').isEmpty &&
      _value(result, 'housenumber').isEmpty &&
      result['lat'] is num &&
      result['lon'] is num;

  Future<Map<String, dynamic>> _withReverseAddress(
    Map<String, dynamic> result,
  ) async {
    final uri = Uri.https(baseUrl, '/v1/geocode/reverse', {
      'lat': result['lat'].toString(),
      'lon': result['lon'].toString(),
      'format': 'json',
      'lang': 'de',
      'limit': '1',
      'apiKey': apiKey,
    });
    try {
      final response = await client.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'com.munichways.app/flutter',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return result;

      final json = response.jsonBody() as Map<String, dynamic>;
      final reverseResults = json['results'] as List<dynamic>? ?? const [];
      if (reverseResults.isEmpty) return result;
      final address = reverseResults.first as Map<String, dynamic>;
      return {
        ...result,
        for (final key in ['street', 'housenumber', 'postcode', 'city'])
          if (_value(result, key).isEmpty && _value(address, key).isNotEmpty)
            key: address[key],
      };
    } catch (_) {
      // Address enrichment is optional; keep the original search result if it
      // is unavailable or times out.
      return result;
    }
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
    final formatted = _value(result, 'formatted');

    if (!generalizeStreet &&
        name.isNotEmpty &&
        addressLine1 == name &&
        street.isNotEmpty) {
      final streetAddress = [street, houseNumber]
          .where((part) => part.isNotEmpty)
          .join(' ');
      final cityPart =
          [postcode, city].where((part) => part.isNotEmpty).join(' ');
      return [name, streetAddress, cityPart]
          .where((part) => part.isNotEmpty)
          .toSet()
          .join(', ');
    }

    // Some POIs expose only their name in address_line1 even though formatted
    // still contains the complete street address. Prefer that information so
    // equally named branches remain distinguishable in search results.
    if (!generalizeStreet &&
        street.isEmpty &&
        houseNumber.isEmpty &&
        name.isNotEmpty &&
        addressLine1 == name &&
        formatted.isNotEmpty) {
      return _formattedWithoutCountry(result, formatted);
    }

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

  static String _formattedWithoutCountry(
    Map<String, dynamic> result,
    String formatted,
  ) {
    final parts = formatted
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final country = _value(result, 'country');
    if (country.isNotEmpty &&
        parts.isNotEmpty &&
        parts.last.toLowerCase() == country.toLowerCase()) {
      parts.removeLast();
    }
    return parts.join(', ');
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
