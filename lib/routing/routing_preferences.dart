enum RoutingMode {
  automatic,
  bRouterEverywhere,
}

enum RouteRecommendation {
  standard,
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
