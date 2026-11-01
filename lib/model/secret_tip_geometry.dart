import 'package:latlong2/latlong.dart';

/// Halfway along the complete line length, never halfway across a bounding box.
/// Disconnected MultiLineString parts do not add artificial connecting edges.
LatLng? secretTipLocationFromGeometry(dynamic geometry) {
  if (geometry is! Map) return null;
  LatLng? point(dynamic value) {
    if (value is! List ||
        value.length < 2 ||
        value[0] is! num ||
        value[1] is! num) return null;
    final lon = (value[0] as num).toDouble();
    final lat = (value[1] as num).toDouble();
    if (!lon.isFinite || !lat.isFinite || lon.abs() > 180 || lat.abs() > 90)
      return null;
    return LatLng(lat, lon);
  }

  final coordinates = geometry['coordinates'];
  if (geometry['type'] == 'Point') return point(coordinates);
  final parts = switch (geometry['type']) {
    'LineString' => [coordinates],
    'MultiLineString' when coordinates is List => coordinates,
    _ => <dynamic>[],
  };
  final edges = <(LatLng, LatLng, double)>[];
  LatLng? first;
  var total = 0.0;
  const distance = Distance();
  for (final part in parts) {
    if (part is! List) return null;
    LatLng? previous;
    for (final coordinate in part) {
      final current = point(coordinate);
      if (current == null) return null;
      first ??= current;
      if (previous != null) {
        final length = distance(previous, current);
        edges.add((previous, current, length));
        total += length;
      }
      previous = current;
    }
  }
  if (total == 0) return first;
  var remaining = total / 2;
  for (final (start, end, length) in edges) {
    if (length > 0 && remaining <= length) {
      return distance.offset(start, remaining, distance.bearing(start, end));
    }
    remaining -= length;
  }
  return edges.last.$2;
}
