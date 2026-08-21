import 'dart:convert';

import 'package:latlong2/latlong.dart';

class PoiDetails {
  const PoiDetails({
    required this.title,
    required this.tags,
    this.location,
  });

  factory PoiDetails.fromGeoJsonFeature(Map<dynamic, dynamic> feature) {
    final rawProperties = feature['properties'];
    final tags = <String, String>{};
    if (rawProperties is Map) {
      for (final entry in rawProperties.entries) {
        final key = entry.key.toString();
        final value = _displayValue(entry.value);
        if (key.isNotEmpty && value.isNotEmpty) tags[key] = value;
      }
    }
    final name = tags['name']?.trim();
    final geometry = feature['geometry'];
    final coordinates = geometry is Map ? geometry['coordinates'] : null;
    final location = coordinates is List &&
            coordinates.length >= 2 &&
            coordinates[0] is num &&
            coordinates[1] is num
        ? LatLng(
            (coordinates[1] as num).toDouble(),
            (coordinates[0] as num).toDouble(),
          )
        : null;
    return PoiDetails(
      title: name == null || name.isEmpty ? 'Trinkwasserbrunnen' : name,
      tags: tags,
      location: location,
    );
  }

  final String title;
  final Map<String, String> tags;
  final LatLng? location;

  String? get osmUrl {
    final explicitUrl = tags['osm_url'];
    if (_isWebUrl(explicitUrl)) return explicitUrl;
    final id = tags['osm_id']?.trim();
    final rawType = tags['osm_type']?.trim().toLowerCase();
    if (id == null || id.isEmpty || rawType == null) return null;
    final type = switch (rawType) {
      'n' || 'node' => 'node',
      'w' || 'way' => 'way',
      'r' || 'relation' => 'relation',
      _ => null,
    };
    return type == null ? null : 'https://www.openstreetmap.org/$type/$id';
  }

  static bool isWebUrl(String? value) => _isWebUrl(value);

  static bool _isWebUrl(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  static String _displayValue(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return jsonEncode(value);
  }
}
