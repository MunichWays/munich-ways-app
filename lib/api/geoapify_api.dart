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

  final String apiKey;
  final String baseUrl;
  final Client client;
  final Map<String, List<Place>> _cache = {};

  GeoapifyApi({
    this.apiKey = apiKeyFromEnvironment,
    this.baseUrl = defaultBaseUrl,
    Client? client,
  }) : client = client ?? Client();

  Future<List<Place>> search(String query) async {
    if (apiKey.isEmpty) {
      throw ApiException(
        'Geoapify API key is missing. '
        'Set GEOAPIFY_API_KEY with --dart-define.',
      );
    }

    final normalizedQuery = query.trim();
    final cached = _cache[normalizedQuery.toLowerCase()];
    if (cached != null) {
      return cached;
    }

    final places = await _requestAutocomplete(normalizedQuery);
    _cache[normalizedQuery.toLowerCase()] = places;
    return places;
  }

  Future<List<Place>> _requestAutocomplete(String query) async {
    final uri = Uri.https(baseUrl, '/v1/geocode/autocomplete', {
      'text': query,
      'format': 'json',
      'lang': 'de',
      'limit': '15',
      'filter': 'countrycode:de',
      'bias': 'proximity:$_munichLongitude,$_munichLatitude',
      'apiKey': apiKey,
    });
    final response = await client.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'com.munichways.app/flutter',
    });

    if (response.statusCode != 200) {
      throw ApiException('Error retrieving places: ${response.body}');
    }

    log.d(response.body);
    final json = response.jsonBody() as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? const [];
    final placesByAddress = <String, Place>{};

    for (final result in results.cast<Map<String, dynamic>>()) {
      final lat = result['lat'];
      final lon = result['lon'];
      if (lat is! num || lon is! num) {
        continue;
      }

      final displayName = _displayName(result);
      if (displayName.isEmpty) {
        continue;
      }

      final place = Place(
        displayName,
        LatLng(lat.toDouble(), lon.toDouble()),
      );
      placesByAddress.putIfAbsent(_addressKey(result), () => place);
    }

    final places = placesByAddress.values.toList();
    _cache[query.toLowerCase()] = places;
    return places;
  }

  static String _displayName(Map<String, dynamic> result) {
    final addressLine1 = _value(result, 'address_line1');
    final name = _value(result, 'name');
    final street = _value(result, 'street');
    final houseNumber = _value(result, 'housenumber');
    final postcode = _value(result, 'postcode');
    final city = _value(result, 'city');

    final mainPart = addressLine1.isNotEmpty
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
  static String _addressKey(Map<String, dynamic> result) {
    final street = _normalizedValue(result, 'street');
    final houseNumber = _normalizedValue(result, 'housenumber');
    final city = _normalizedValue(result, 'city');
    final name = _normalizedValue(result, 'name');
    final key = [street, houseNumber, city, name]
        .where((part) => part.isNotEmpty)
        .join('|');
    return key.isNotEmpty ? key : _value(result, 'place_id');
  }

  static String _normalizedValue(
    Map<String, dynamic> result,
    String key,
  ) =>
      _value(result, key).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _value(Map<String, dynamic> result, String key) =>
      result[key]?.toString().trim() ?? '';
}
