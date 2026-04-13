import 'package:munich_ways/model/route.dart';

/// Navigation route shown on the map (RadlNavi) plus UI/load state.
class MapRoute {
  MapRoute(this.route, this.state);

  CycleRoute? route;
  MapRouteState state;
}

enum MapRouteState { NO_ROUTE, LOADING, ERROR, SHOWN }
