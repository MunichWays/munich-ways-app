import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Projects a GPS position onto the closest route segment when it is plausible
/// that the rider is still on that route.
class RoutePositionSnapper {
  const RoutePositionSnapper._();

  static LatLng snap(
    LatLng position,
    List<LatLng> route, {
    required double maxDistanceMeters,
  }) {
    if (route.length < 2 || maxDistanceMeters <= 0) return position;

    final metersPerLatitudeDegree = 111320.0;
    final metersPerLongitudeDegree =
        metersPerLatitudeDegree * cos(position.latitude * pi / 180);

    var shortestDistanceSquared = double.infinity;
    LatLng? closest;

    for (var index = 0; index < route.length - 1; index++) {
      final start = route[index];
      final end = route[index + 1];
      final startX =
          (start.longitude - position.longitude) * metersPerLongitudeDegree;
      final startY =
          (start.latitude - position.latitude) * metersPerLatitudeDegree;
      final endX =
          (end.longitude - position.longitude) * metersPerLongitudeDegree;
      final endY = (end.latitude - position.latitude) * metersPerLatitudeDegree;
      final segmentX = endX - startX;
      final segmentY = endY - startY;
      final segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;
      if (segmentLengthSquared == 0) continue;

      final projection =
          (-(startX * segmentX + startY * segmentY) / segmentLengthSquared)
              .clamp(0.0, 1.0);
      final projectedX = startX + segmentX * projection;
      final projectedY = startY + segmentY * projection;
      final distanceSquared = projectedX * projectedX + projectedY * projectedY;

      if (distanceSquared < shortestDistanceSquared) {
        shortestDistanceSquared = distanceSquared;
        closest = LatLng(
          start.latitude + (end.latitude - start.latitude) * projection,
          start.longitude + (end.longitude - start.longitude) * projection,
        );
      }
    }

    if (closest == null ||
        shortestDistanceSquared > maxDistanceMeters * maxDistanceMeters) {
      return position;
    }
    return closest;
  }
}
