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

  test('legacy shortest uses fastbike when direct provider is unavailable',
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
      mode: RoutingMode.bRouterEverywhere,
      bRouterProfile: BRouterProfile.shortest,
    );

    expect(radlNavi.calls, 0);
    expect(bRouter.lastProfile, BRouterProfile.fastBike);
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

  test(
      'persisted shortest and explicit direct use RadlNavi with fastbike fallback',
      () async {
    final primary = _DirectProvider();
    final fallback = _FakeProvider();
    final service = RoutingService(
        radlNavi: primary,
        bRouter: fallback,
        radlNaviCoverage: _FakeCoverage({munich, rosenheim}));
    await service.route([munich, rosenheim],
        mode: RoutingMode.bRouterEverywhere,
        bRouterProfile: BRouterProfile.shortest);
    expect(primary.directCalls, 1);
    expect(primary.calls, 0);
    expect(fallback.calls, 0);
    primary.fail = true;
    await service.route([munich, rosenheim],
        mode: RoutingMode.automatic,
        bRouterProfile: BRouterProfile.fastBike,
        direct: true);
    expect(fallback.lastProfile, BRouterProfile.fastBike);
    primary.fail = false;
    await service.route([munich, rosenheim],
        mode: RoutingMode.automatic,
        bRouterProfile: BRouterProfile.trekking,
        direct: true);
    expect(primary.directCalls, 3);
    expect(fallback.calls, 1);
    await service.route([munich, berlin],
        mode: RoutingMode.automatic,
        bRouterProfile: BRouterProfile.trekking,
        direct: true);
    expect(primary.directCalls, 3);
    expect(fallback.lastProfile, BRouterProfile.fastBike);
  });

  test('direct has its own timeout and falls back when its budget expires',
      () async {
    final pending = Completer<CycleRoute>();
    final primary = _DirectProvider(result: pending.future);
    final fallback = _FakeProvider();
    final service = RoutingService(
        radlNavi: primary,
        bRouter: fallback,
        radlNaviCoverage: _FakeCoverage({munich, rosenheim}),
        requestTimeout: const Duration(milliseconds: 1),
        directRequestTimeout: const Duration(seconds: 2));
    final request = service.route([munich, rosenheim],
        mode: RoutingMode.automatic,
        bRouterProfile: BRouterProfile.trekking,
        direct: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(fallback.calls, 0);
    final direct = CycleRoute([munich, rosenheim], 100, 20);
    pending.complete(direct);
    expect(await request, same(direct));

    final stalled = Completer<CycleRoute>();
    final timedService = RoutingService(
        radlNavi: _DirectProvider(result: stalled.future),
        bRouter: fallback,
        radlNaviCoverage: _FakeCoverage({munich, rosenheim}),
        directRequestTimeout: const Duration(milliseconds: 10));
    await timedService.route([munich, rosenheim],
        mode: RoutingMode.automatic,
        bRouterProfile: BRouterProfile.trekking,
        direct: true);
    expect(fallback.calls, 1);
    expect(fallback.lastProfile, BRouterProfile.fastBike);
    stalled.complete(direct);
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

class _DirectProvider extends _FakeProvider implements DirectRoutingProvider {
  _DirectProvider({this.result});
  final Future<CycleRoute>? result;
  int directCalls = 0;
  bool fail = false;
  @override
  Future<CycleRoute> routeDirect(List<LatLng> coordinates) async {
    directCalls++;
    if (fail) throw StateError('unavailable');
    if (result != null) return result!;
    return CycleRoute(coordinates, 100, 20);
  }
}
