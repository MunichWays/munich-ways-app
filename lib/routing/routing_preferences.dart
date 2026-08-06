enum RoutingMode {
  automatic,
  bRouterEverywhere,
}

enum RouteRecommendation {
  standard,
  shortest,
  aloneAfterDark,
  hotWeather,
  snowAndMud,
  trekking,
  roadBike,
}

enum BRouterProfile {
  trekking('trekking'),
  fastBike('fastbike'),
  shortest('shortest');

  const BRouterProfile(this.apiName);

  final String apiName;
}
