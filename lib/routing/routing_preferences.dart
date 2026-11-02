enum RoutingMode {
  automatic,
  bRouterEverywhere,
}

enum RouteRecommendation {
  standard,
  discovery,
  aloneAfterDark,
  hotWeather,
  snowAndMud,
  trekking,
  roadBike,
  shortest,
}

enum BRouterProfile {
  trekking('trekking'),
  fastBike('fastbike'),
  shortest('shortest');

  const BRouterProfile(this.apiName);

  final String apiName;
}

/// Route-scoped alternatives in the planner; independent of saved wishes.
enum RouteVariant { standard, discovery, direct }
