import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

abstract interface class RoutingCoverage {
  Future<bool> contains(LatLng point);
}

class OberbayernCoverage implements RoutingCoverage {
  OberbayernCoverage({
    Future<String> Function()? loadGeoJson,
  }) : _loadGeoJson = loadGeoJson ??
            (() => rootBundle.loadString(
                  'assets/routing/oberbayern.json',
                ));

  final Future<String> Function() _loadGeoJson;
  Future<List<LatLng>>? _polygon;

  @override
  Future<bool> contains(LatLng point) async {
    final polygon = await (_polygon ??= _loadPolygon());
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final current = polygon[i];
      final previous = polygon[j];
      final crossesLatitude = (current.latitude > point.latitude) !=
          (previous.latitude > point.latitude);
      if (!crossesLatitude) continue;
      final crossingLongitude = (previous.longitude - current.longitude) *
              (point.latitude - current.latitude) /
              (previous.latitude - current.latitude) +
          current.longitude;
      if (point.longitude < crossingLongitude) inside = !inside;
    }
    return inside;
  }

  Future<List<LatLng>> _loadPolygon() async {
    final json = jsonDecode(await _loadGeoJson()) as Map<String, dynamic>;
    final features = json['features'] as List;
    final geometry = (features.first as Map<String, dynamic>)['geometry']
        as Map<String, dynamic>;
    final rings = geometry['coordinates'] as List;
    final outerRing = rings.first as List;
    return outerRing.map((raw) {
      final coordinate = raw as List;
      return LatLng(
        (coordinate[1] as num).toDouble(),
        (coordinate[0] as num).toDouble(),
      );
    }).toList(growable: false);
  }
}
