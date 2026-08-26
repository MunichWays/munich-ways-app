import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';
import 'package:munich_ways/routing/routing_service.dart';

void main() {
  const munich = LatLng(48.137, 11.575);
  const rosenheim = LatLng(47.856, 12.128);
  const berlin = LatLng(52.52, 13.405);

  test('automatic mode uses RadlNavi when all coordinates are covered',
      () async {
    final radlNavi = _FakeProvider();
    final bRouter = _FakeProvider();
    final service = RoutingService(
      radlNavi: radlNavi,
      bRouter: bRouter,
      radlNaviCoverage: _FakeCoverage({munich, rosenheim}),
    );

    await service.route(
      const [munich, rosenheim],
      mode: RoutingMode.automatic,
      bRouterProfile: BRouterProfile.trekking,
    );

    expect(radlNavi.calls, 1);
    expect(bRouter.calls, 0);
  });

  test('automatic mode uses BRouter when one coordinate is outside', () async {
    final radlNavi = _FakeProvider();
    final bRouter = _FakeProvider();
    final service = RoutingService(
      radlNavi: radlNavi,
      bRouter: bRouter,
      radlNaviCoverage: _FakeCoverage({munich}),
    );

    await service.route(
      const [munich, berlin],
      mode: RoutingMode.automatic,
      bRouterProfile: BRouterProfile.fastBike,
    );

    expect(radlNavi.calls, 0);
    expect(bRouter.calls, 1);
    expect(bRouter.lastProfile, BRouterProfile.fastBike);
  });

  test('BRouter everywhere bypasses coverage and RadlNavi', () async {
    final radlNavi = _FakeProvider();
    final bRouter = _FakeProvider();
    final service = RoutingService(
      radlNavi: radlNavi,
      bRouter: bRouter,
      radlNaviCoverage: _FakeCoverage({munich, rosenheim}),
    );

    await service.route(
      const [munich, rosenheim],
      mode: RoutingMode.bRouterEverywhere,
      bRouterProfile: BRouterProfile.shortest,
    );

    expect(radlNavi.calls, 0);
    expect(bRouter.lastProfile, BRouterProfile.shortest);
  });

  test('falls back to BRouter after a RadlNavi error', () async {
    final radlNavi = _FakeProvider(error: Exception('unavailable'));
    final bRouter = _FakeProvider();
    final service = RoutingService(
      radlNavi: radlNavi,
      bRouter: bRouter,
      radlNaviCoverage: _FakeCoverage({munich, rosenheim}),
    );

    await service.route(
      const [munich, rosenheim],
      mode: RoutingMode.automatic,
      bRouterProfile: BRouterProfile.trekking,
    );

    expect(radlNavi.calls, 1);
    expect(bRouter.calls, 1);
  });

  test('falls back to BRouter after the RadlNavi timeout', () async {
    final radlNavi = _FakeProvider(result: Completer<CycleRoute>().future);
    final bRouter = _FakeProvider();
    final service = RoutingService(
      radlNavi: radlNavi,
      bRouter: bRouter,
      radlNaviCoverage: _FakeCoverage({munich, rosenheim}),
      requestTimeout: const Duration(milliseconds: 10),
    );

    await service.route(
      const [munich, rosenheim],
      mode: RoutingMode.automatic,
      bRouterProfile: BRouterProfile.trekking,
    );

    expect(bRouter.calls, 1);
  });

  testWidgets('bundled Oberbayern polygon contains Munich but not Berlin',
      (tester) async {
    final coverage = OberbayernCoverage();

    final geoJson = await coverage.featureCollection;
    expect(geoJson['type'], 'FeatureCollection');
    final features = geoJson['features'] as List<dynamic>;
    expect(features, hasLength(1));
    expect(
      (features.single as Map<String, dynamic>)['geometry']['type'],
      'Polygon',
    );
    expect(await coverage.contains(munich), isTrue);
    expect(await coverage.contains(berlin), isFalse);
  });
}

class _FakeCoverage implements RoutingCoverage {
  _FakeCoverage(this.covered);

  final Set<LatLng> covered;

  @override
  Future<bool> contains(LatLng point) async => covered.contains(point);
}

class _FakeProvider implements RoutingProvider {
  _FakeProvider({
    this.error,
    Future<CycleRoute>? result,
  }) : _result = result;

  final Object? error;
  final Future<CycleRoute>? _result;
  int calls = 0;
  BRouterProfile? lastProfile;

  @override
  Future<CycleRoute> route(
    List<LatLng> coordinates, {
    BRouterProfile profile = BRouterProfile.trekking,
  }) async {
    calls++;
    lastProfile = profile;
    if (error case final error?) throw error;
    final result = _result;
    if (result != null) return result;
    return CycleRoute(
      coordinates,
      100,
      20,
    );
  }
}
