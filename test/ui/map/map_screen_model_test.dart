import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';
import 'package:munich_ways/routing/routing_service.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

import '../../support/wakelock_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(stubWakelock);

  test('uses a direction arrow only for reliable movement heading', () {
    expect(
      hasReliableMovementHeading(
        accuracy: 5,
        heading: 90,
        headingAccuracy: 5,
        speed: 2,
      ),
      isTrue,
    );
    expect(
      hasReliableMovementHeading(
        accuracy: 5,
        heading: 90,
        headingAccuracy: 5,
        speed: 0,
      ),
      isFalse,
    );
    expect(
      hasReliableMovementHeading(
        accuracy: 80,
        heading: 90,
        headingAccuracy: 5,
        speed: 2,
      ),
      isFalse,
    );
  });

  test('accepts a coarse initial position but rejects unusable fixes', () {
    expect(
      isUsableMapPosition(
        latitude: 48.14,
        longitude: 11.57,
        accuracy: 250,
      ),
      isTrue,
    );
    expect(
      isUsableMapPosition(
        latitude: 48.14,
        longitude: 11.57,
        accuracy: 1001,
      ),
      isFalse,
    );
    expect(
      isUsableMapPosition(
        latitude: 91,
        longitude: 11.57,
        accuracy: 10,
      ),
      isFalse,
    );
  });

  test('uses only recent cached positions at startup', () {
    final now = DateTime(2026, 8, 29, 12);

    expect(
      isFreshCachedPosition(
        now.subtract(const Duration(minutes: 15)),
        now,
      ),
      isTrue,
    );
    expect(
      isFreshCachedPosition(
        now.subtract(const Duration(minutes: 16)),
        now,
      ),
      isFalse,
    );
    expect(
      isFreshCachedPosition(now.add(const Duration(seconds: 1)), now),
      isFalse,
    );
  });

  test('halves the tracking update rate while saving energy', () {
    expect(
      trackingIntervalForEnergySaving(false),
      const Duration(seconds: 1),
    );
    expect(
      trackingIntervalForEnergySaving(true),
      const Duration(seconds: 2),
    );
    final now = DateTime(2026, 8, 29, 12);
    expect(
      shouldAcceptTrackingUpdate(
        energySaving: true,
        previousUpdate: now,
        currentUpdate: now.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      shouldAcceptTrackingUpdate(
        energySaving: true,
        previousUpdate: now,
        currentUpdate: now.add(const Duration(seconds: 2)),
      ),
      isTrue,
    );
  });

  test('provides the energy saving announcement in both languages', () {
    expect(
      energySavingAnnouncement(false),
      'Energiesparmodus aktiviert. Standort wird seltener aktualisiert.',
    );
    expect(
      energySavingAnnouncement(true),
      'Energy saving mode enabled. Location updates are reduced.',
    );
  });

  test('allows the optional initial network load longer in background',
      () async {
    final api = _RecordingMunichwaysApi();
    final model = MapScreenViewModel(
      store: _MemorySettingsStore(),
      munichwaysApi: api,
    );

    model.startInitialLoad();
    await Future<void>.delayed(Duration.zero);

    expect(api.responseTimeout, const Duration(seconds: 30));
  });

  test('finishes initial loading when ratings stream stalls offline', () async {
    final model = MapScreenViewModel(
      store: _MemorySettingsStore(),
      munichwaysApi: _StalledMunichwaysApi(),
    );

    final result = await model.refreshRadlnetze(
      requestTimeout: const Duration(milliseconds: 20),
    );

    expect(result, isFalse);
    expect(model.loading, isFalse);
    expect(model.initialLoadComplete, isTrue);
    expect(model.initialRatingsLoadFailed, isTrue);
  });

  test('offers retry when only the bundled fallback was loaded', () async {
    final model = MapScreenViewModel(
      store: _MemorySettingsStore(),
      munichwaysApi: _FallbackOnlyMunichwaysApi(),
    );

    final result = await model.refreshRadlnetze(
      requestTimeout: const Duration(milliseconds: 20),
    );

    expect(result, isFalse);
    expect(model.loading, isFalse);
    expect(model.initialRatingsLoadFailed, isTrue);
  });

  test('keeps retry available when reloading the full network fails', () async {
    final model = MapScreenViewModel(
      store: _MemorySettingsStore(),
      munichwaysApi: _ReloadFailureMunichwaysApi(),
    )..initialRatingsLoadFailed = true;

    final result = await model.reloadRadnetz();

    expect(result, isFalse);
    expect(model.loading, isFalse);
    expect(model.initialRatingsLoadFailed, isTrue);
  });

  test('temporary shortest route survives refresh and restores settings',
      () async {
    const start = LatLng(48.14, 11.56);
    const destination = LatLng(48.16, 11.60);
    final radlNavi = _RecordingRoutingProvider();
    final bRouter = _RecordingRoutingProvider();
    final store = _MemorySettingsStore(
      SettingsData.defaults.copyWith(
        routingMode: RoutingMode.bRouterEverywhere,
        bRouterProfile: BRouterProfile.fastBike,
        routeRecommendation: RouteRecommendation.roadBike,
      ),
    );
    final model = MapScreenViewModel(
      store: store,
      routingService: RoutingService(
        radlNavi: radlNavi,
        bRouter: bRouter,
        radlNaviCoverage: _AlwaysCovered(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    model
      ..routeStart = Place('Start', start)
      ..destination = Place('Ziel', destination);

    expect(await model.setTemporaryShortestRouteEnabled(true), isTrue);
    expect(model.temporaryShortestRouteEnabled, isTrue);
    expect(bRouter.profiles, [BRouterProfile.shortest]);

    // Manual refresh and automatic rerouting share this request path.
    expect(await model.refreshRoute(), isTrue);
    expect(
      bRouter.profiles,
      [BRouterProfile.shortest, BRouterProfile.shortest],
    );

    expect(await model.setTemporaryShortestRouteEnabled(false), isTrue);
    expect(model.temporaryShortestRouteEnabled, isFalse);
    expect(bRouter.profiles.last, BRouterProfile.fastBike);
    expect(model.routingMode, RoutingMode.bRouterEverywhere);
    expect(model.bRouterProfile, BRouterProfile.fastBike);
    expect(store.routingPreferenceWrites, 0);
  });

  test('ending a route clears its temporary shortest choice', () async {
    final model = MapScreenViewModel(store: _MemorySettingsStore());

    await model.setTemporaryShortestRouteEnabled(true);
    expect(model.temporaryShortestRouteEnabled, isTrue);

    model.clearDestination();

    expect(model.temporaryShortestRouteEnabled, isFalse);
  });
}

class _StalledMunichwaysApi extends MunichwaysApi {
  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
  }) =>
      StreamController<Set<MPolyline>>()
          .stream
          .timeout(responseTimeout ?? const Duration(seconds: 6));

  @override
  Future<Map<String, StreetDetails>> getStreetDetails() async => {};
}

class _RecordingMunichwaysApi extends MunichwaysApi {
  Duration? responseTimeout;

  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
  }) async* {
    this.responseTimeout = responseTimeout;
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails() async => {};
}

class _FallbackOnlyMunichwaysApi extends MunichwaysApi {
  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
  }) async* {
    yield <MPolyline>{};
    await Completer<void>().future.timeout(
          responseTimeout ?? const Duration(seconds: 6),
        );
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails() async => {};
}

class _ReloadFailureMunichwaysApi extends MunichwaysApi {
  @override
  Future<void> removeRatingsCache() async {}

  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
  }) async* {
    yield <MPolyline>{};
    throw TimeoutException('offline');
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails() async => {};
}

class _MemorySettingsStore extends SettingsStore {
  _MemorySettingsStore([this.data = SettingsData.defaults]);

  final SettingsData data;
  int routingPreferenceWrites = 0;

  @override
  Future<SettingsData> load() async => data;

  @override
  Future<void> saveRoutingMode(RoutingMode routingMode) async {
    routingPreferenceWrites++;
  }

  @override
  Future<void> saveBRouterProfile(BRouterProfile profile) async {
    routingPreferenceWrites++;
  }

  @override
  Future<void> saveRouteRecommendation(
    RouteRecommendation? recommendation,
  ) async {
    routingPreferenceWrites++;
  }
}

class _AlwaysCovered implements RoutingCoverage {
  @override
  Future<bool> contains(LatLng point) async => true;
}

class _RecordingRoutingProvider implements RoutingProvider {
  final List<BRouterProfile> profiles = [];

  @override
  Future<CycleRoute> route(
    List<LatLng> coordinates, {
    BRouterProfile profile = BRouterProfile.trekking,
  }) async {
    profiles.add(profile);
    return CycleRoute(coordinates, 1000, 300);
  }
}
