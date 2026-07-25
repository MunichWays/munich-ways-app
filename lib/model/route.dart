import 'package:latlong2/latlong.dart';

class CycleRoute {
  List<LatLng> points;
  double distance;
  double duration;
  List<RouteManeuver> maneuvers;

  CycleRoute(
    this.points,
    this.distance,
    this.duration, {
    this.maneuvers = const [],
  });
}

class RouteManeuver {
  const RouteManeuver({
    required this.location,
    required this.type,
    this.modifier,
    this.roadName = '',
    this.exit,
  });

  final LatLng location;
  final String type;
  final String? modifier;
  final String roadName;
  final int? exit;
}
