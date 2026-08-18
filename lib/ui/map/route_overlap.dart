import 'package:latlong2/latlong.dart';

/// Undirected route segments that occur more than once, rounded to roughly
/// one metre so outbound and return geometry can be matched reliably.
Set<String> repeatedRouteSegmentKeys(List<LatLng> points) {
  final counts = <String, int>{};
  for (var index = 0; index < points.length - 1; index++) {
    final key = routeSegmentKey(points[index], points[index + 1]);
    if (key != null) counts[key] = (counts[key] ?? 0) + 1;
  }
  return {
    for (final entry in counts.entries)
      if (entry.value > 1) entry.key,
  };
}

String? routeSegmentKey(LatLng start, LatLng end) {
  final startKey = _routePointKey(start);
  final endKey = _routePointKey(end);
  if (startKey == endKey) return null;
  return startKey.compareTo(endKey) < 0
      ? '$startKey|$endKey'
      : '$endKey|$startKey';
}

/// GeoJSON containing each physical overlapping section once. Consecutive
/// repeated segments are joined so MapLibre can place arrow pairs along them.
Map<String, dynamic> buildRouteOverlapGeoJson(List<LatLng> points) {
  final repeatedKeys = repeatedRouteSegmentKeys(points);
  final emittedKeys = <String>{};
  final sections = <List<LatLng>>[];
  var current = <LatLng>[];

  void finishCurrent() {
    if (current.length >= 2) sections.add(current);
    current = <LatLng>[];
  }

  for (var index = 0; index < points.length - 1; index++) {
    final start = points[index];
    final end = points[index + 1];
    final key = routeSegmentKey(start, end);
    if (key == null || !repeatedKeys.contains(key) || !emittedKeys.add(key)) {
      finishCurrent();
      continue;
    }
    if (current.isEmpty) {
      current = [start, end];
    } else if (current.last == start) {
      current.add(end);
    } else {
      finishCurrent();
      current = [start, end];
    }
  }
  finishCurrent();

  return {
    'type': 'FeatureCollection',
    'features': [
      for (final section in sections)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final point in section) [point.longitude, point.latitude],
            ],
          },
        },
    ],
  };
}

String _routePointKey(LatLng point) => '${(point.latitude * 100000).round()}:'
    '${(point.longitude * 100000).round()}';
