import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';

import 'api_exception.dart';

class NominatimApi {
  Client? client;
  final String baseUrl;

  static const String NOMINATIM_PROXY_URL = "nominatim.svendroid.net";

  NominatimApi({this.baseUrl = NOMINATIM_PROXY_URL, this.client}) {
    if (client == null) {
      client = Client();
    }
  }

  // https://nominatim.org/release-docs/latest/api/Search/
  Future<List<Place>> search(String query, {LatLng? searchCenter}) async {
    final center = searchCenter ?? const LatLng(48.137154, 11.576124);
    final localPlaces = await _request(
      query,
      localOnly: true,
      center: center,
    );
    if (localPlaces.isNotEmpty) {
      return localPlaces;
    }
    return _request(query, localOnly: false, center: center);
  }

  Future<List<Place>> _request(
    String query, {
    required bool localOnly,
    required LatLng center,
  }) async {
    final queryParameters = {
      'q': query,
      // GeoCodeJSON omits namedetails even when requested. JSONv2 retains aliases.
      'format': 'jsonv2',
      'namedetails': '1',
      'addressdetails': '1',
      'limit': '15',
      if (localOnly) ...{
        'viewbox': _viewBox(center),
        'bounded': '1',
      },
    };
    Uri uri = Uri.https(baseUrl, 'search', queryParameters);
    Response response = await client!.get(uri, headers: {
      "Accept": "application/json",
      "User-Agent": "com.munichways.app/flutter"
    }).timeout(const Duration(seconds: 8));
    switch (response.statusCode) {
      case 200:
        log.d(response.body);
        log.d(response.jsonBody());
        return _parsePlaces(response.jsonBody());
      default:
        throw ApiException("Error retrieving places: " + response.body);
    }
  }

  static List<String> _alternativeNames(Map<String, dynamic> result) {
    final details = result['namedetails'];
    if (details is! Map) return const [];
    final primary = (result['name'] ?? details['name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final names = <String, String>{};
    for (final key in [
      'alt_name',
      'loc_name',
      'short_name',
      'official_name',
      'old_name'
    ]) {
      final value = details[key];
      if (value is! String) continue;
      for (final part in value.split(';')) {
        final name = part.trim();
        final normalized = name.toLowerCase();
        if (name.isNotEmpty && normalized != primary) {
          names.putIfAbsent(normalized, () => name);
        }
      }
    }
    return names.values.toList(growable: false);
  }

  static String _viewBox(LatLng center) =>
      '${center.longitude - 0.35},${center.latitude + 0.25},'
      '${center.longitude + 0.35},${center.latitude - 0.25}';

  static List<Place> _parsePlaces(dynamic json) {
    if (json is Map<String, dynamic>) {
      final features = json['features'];
      if (features is! List) return const [];
      return features
          .whereType<Map<String, dynamic>>()
          .map(_placeFromFeature)
          .whereType<Place>()
          .toList();
    }

    // JSONv2 preserves the full name details requested above.
    if (json is List) {
      return json.whereType<Map<String, dynamic>>().map((result) {
        return Place(
          _displayName(result),
          LatLng(
            double.parse(result['lat'].toString()),
            double.parse(result['lon'].toString()),
          ),
          alternativeNames: _alternativeNames(result),
        );
      }).toList();
    }
    return const [];
  }

  static Place? _placeFromFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'];
    final properties = feature['properties'];
    if (geometry is! Map || properties is! Map) return null;
    final coordinates = geometry['coordinates'];
    final geocoding = properties['geocoding'];
    if (coordinates is! List || coordinates.length < 2 || geocoding is! Map) {
      return null;
    }
    final longitude = coordinates[0];
    final latitude = coordinates[1];
    if (longitude is! num || latitude is! num) return null;
    final details = Map<String, dynamic>.from(geocoding);
    return Place(
      _geocodeJsonDisplayName(details),
      LatLng(latitude.toDouble(), longitude.toDouble()),
    );
  }

  static String _geocodeJsonDisplayName(Map<String, dynamic> details) {
    String value(String key) => details[key]?.toString().trim() ?? '';
    final streetPart = [value('street'), value('housenumber')]
        .where((part) => part.isNotEmpty)
        .join(' ');
    final city = value('city').isNotEmpty ? value('city') : value('locality');
    final cityPart =
        [value('postcode'), city].where((part) => part.isNotEmpty).join(' ');
    final adminName = _mostLocalAdministrativeName(details['admin']);
    final compact = [value('name'), streetPart, adminName, cityPart]
        .where((part) => part.isNotEmpty)
        .toSet()
        .join(', ');
    return compact.isNotEmpty ? compact : value('label');
  }

  static String _mostLocalAdministrativeName(dynamic admin) {
    if (admin is! Map) return '';
    var highestLevel = -1;
    var name = '';
    for (final entry in admin.entries) {
      final match =
          RegExp(r'^(?:level)?(\d+)$').firstMatch(entry.key.toString());
      final level = match == null ? null : int.tryParse(match.group(1)!);
      final candidate = entry.value?.toString().trim() ?? '';
      if (level != null && level > highestLevel && candidate.isNotEmpty) {
        highestLevel = level;
        name = candidate;
      }
    }
    return name;
  }

  static String _displayName(Map<String, dynamic> result) {
    final address = result['address'];
    if (address is! Map) {
      return result['display_name']?.toString().trim() ?? '';
    }

    String value(String key) => address[key]?.toString().trim() ?? '';
    final street = value('road').isNotEmpty
        ? value('road')
        : value('pedestrian').isNotEmpty
            ? value('pedestrian')
            : value('place');
    final houseNumber = value('house_number');
    final streetPart =
        [street, houseNumber].where((part) => part.isNotEmpty).join(' ');
    final city = [
      value('city'),
      value('town'),
      value('village'),
      value('municipality'),
    ].firstWhere((part) => part.isNotEmpty, orElse: () => '');
    final cityPart =
        [value('postcode'), city].where((part) => part.isNotEmpty).join(' ');
    final resultName = result['name']?.toString().trim() ?? '';
    final name = resultName.isNotEmpty
        ? resultName
        : value('amenity').isNotEmpty
            ? value('amenity')
            : value('shop');

    final localArea = [
      value('neighbourhood'),
      value('quarter'),
      value('suburb'),
    ].firstWhere((part) => part.isNotEmpty, orElse: () => '');
    final compact = [name, streetPart, localArea, cityPart]
        .where((part) => part.isNotEmpty)
        .toSet()
        .join(', ');
    return compact.isNotEmpty
        ? compact
        : result['display_name']?.toString().trim() ?? '';
  }
}
