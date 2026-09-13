import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/routing/routing_preferences.dart';

abstract interface class RouteComfortProvider {
  Future<RouteComfort> analyzeComfort(RouteAnalysisContext context);
}

/// Direct routing uses the same route and navigation contract as standard.
abstract interface class DirectRoutingProvider {
  Future<CycleRoute> routeDirect(List<LatLng> coordinates);
}

abstract interface class RoutingProvider {
  Future<CycleRoute> route(
    List<LatLng> coordinates, {
    BRouterProfile profile = BRouterProfile.trekking,
  });
}
