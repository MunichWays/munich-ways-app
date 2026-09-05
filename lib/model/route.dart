import 'package:latlong2/latlong.dart';

class CycleRoute {
  List<LatLng> points;
  double distance;
  double duration;
  List<RouteManeuver> maneuvers;
  bool supportsVoiceGuidance;
  List<LatLng> destinationConnector;
  RouteComfort? comfort;
  final RouteAnalysisContext? analysisContext;

  CycleRoute(
    this.points,
    this.distance,
    this.duration, {
    this.maneuvers = const [],
    this.supportsVoiceGuidance = true,
    this.destinationConnector = const [],
    this.comfort,
    this.analysisContext,
  });
}

/// Exact node annotations of the returned route, preserving leg boundaries.
class RouteAnalysisContext {
  RouteAnalysisContext(List<List<int>> legNodeIds)
      : legNodeIds = List.unmodifiable(
          legNodeIds.map((nodes) => List<int>.unmodifiable(nodes)),
        );

  final List<List<int>> legNodeIds;
}

/// Radl-Komfort metadata calculated by the RadlNavi backend.
///
/// The app deliberately stores and displays these values without calculating
/// an index from the route geometry or local rating data.
class RouteComfort {
  const RouteComfort({
    required this.index,
    required this.coverage,
    required this.sufficientCoverage,
    required this.distribution,
  });

  final int? index;
  final int coverage;
  final bool sufficientCoverage;
  final RouteComfortDistribution distribution;
}

class RouteComfortDistribution {
  const RouteComfortDistribution({
    required this.black,
    required this.red,
    required this.yellow,
    required this.green,
    required this.unrated,
  });

  final int black;
  final int red;
  final int yellow;
  final int green;
  final int unrated;
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
