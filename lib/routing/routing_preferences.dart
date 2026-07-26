enum RoutingMode {
  automatic,
  bRouterEverywhere,
}

enum BRouterProfile {
  trekking('trekking'),
  fastBike('fastbike'),
  shortest('shortest');

  const BRouterProfile(this.apiName);

  final String apiName;
}
