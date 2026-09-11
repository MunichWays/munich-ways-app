import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';

class RoutingService {
  RoutingService({
    required this.radlNavi,
    required this.bRouter,
    required this.radlNaviCoverage,
    this.requestTimeout = const Duration(seconds: 20),
    this.directRequestTimeout = const Duration(seconds: 45),
    this.bRouterRequestTimeout = const Duration(seconds: 75),
    this.comfortRequestTimeout = const Duration(seconds: 60),
  });

  final RoutingProvider radlNavi;
  final RoutingProvider bRouter;
  final RoutingCoverage radlNaviCoverage;
  final Duration requestTimeout;
  // Optional direct work may need a cold start; standard keeps its own budget.
  final Duration directRequestTimeout;
  final Duration bRouterRequestTimeout;
  final Duration comfortRequestTimeout;

  bool get supportsVariants => radlNavi is DirectRoutingProvider;

  bool canAnalyzeComfort(CycleRoute route) =>
      route.analysisContext != null && radlNavi is RouteComfortProvider;

  /// Optional metadata never participates in routing-provider fallback.
  Future<RouteComfort> analyzeComfort(CycleRoute route) {
    final provider = radlNavi is RouteComfortProvider
        ? radlNavi as RouteComfortProvider
        : null;
    final context = route.analysisContext;
    if (provider == null || context == null) {
      throw StateError('Route does not support comfort analysis');
    }
    return provider.analyzeComfort(context).timeout(comfortRequestTimeout);
  }

  Future<CycleRoute> route(
    List<LatLng> coordinates, {
    required RoutingMode mode,
    required BRouterProfile bRouterProfile,
    bool direct = false,
  }) async {
    if (coordinates.length < 2) {
      throw ArgumentError.value(
        coordinates,
        'coordinates',
        'At least two coordinates are required.',
      );
    }

    // Migrate the persisted shortest preference as well as the trip choice.
    final useDirect = direct ||
        (mode == RoutingMode.bRouterEverywhere &&
            bRouterProfile == BRouterProfile.shortest);
    final fallbackProfile =
        useDirect ? BRouterProfile.shortest : bRouterProfile;
    if ((!useDirect && mode == RoutingMode.bRouterEverywhere) ||
        !await _allCoordinatesCovered(coordinates)) {
      return _routeWithBRouter(coordinates, fallbackProfile);
    }

    try {
      if (useDirect) {
        final provider = radlNavi;
        if (provider is! DirectRoutingProvider) {
          return _routeWithBRouter(coordinates, fallbackProfile);
        }
        return await (provider as DirectRoutingProvider)
            .routeDirect(coordinates)
            .timeout(directRequestTimeout);
      }
      return await radlNavi.route(coordinates).timeout(requestTimeout);
    } catch (error, stackTrace) {
      log.i(
        'RadlNavi routing unavailable; falling back to BRouter',
        error: error,
        stackTrace: stackTrace,
      );
      return _routeWithBRouter(coordinates, fallbackProfile);
    }
  }

  Future<bool> _allCoordinatesCovered(List<LatLng> coordinates) async {
    for (final coordinate in coordinates) {
      if (!await radlNaviCoverage.contains(coordinate)) return false;
    }
    return true;
  }

  Future<CycleRoute> _routeWithBRouter(
    List<LatLng> coordinates,
    BRouterProfile profile,
  ) =>
      bRouter
          .route(coordinates, profile: profile)
          .timeout(bRouterRequestTimeout);
}
