import 'package:munich_ways/model/route.dart';

/// Navigation route shown on the map (RadlNavi) plus UI/load state.
class MapRoute {
  MapRoute(this.route, this.state)
      : comfortState = route?.comfort == null
            ? RouteComfortState.unavailable
            : RouteComfortState.ready;

  CycleRoute? route;
  MapRouteState state;
  RouteComfortState comfortState;
}

enum RouteComfortState { unavailable, loading, ready, error }

enum MapRouteState { NO_ROUTE, LOADING, ERROR, SHOWN }
