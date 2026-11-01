import 'package:geolocator/geolocator.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
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

  test('map inspection changes camera follow without pausing navigation',
      () async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    addTearDown(model.dispose);

    expect(await model.startNavigation(), isTrue);
    expect(model.navigationPaused, isFalse);

    model.onUserStoppedFollowingLocation();
    expect(model.locationState, LocationState.DISPLAY);
    expect(model.navigationActive, isTrue);
    expect(model.navigationPaused, isFalse);

    expect(model.resumeNavigationCameraFollowing(), isTrue);
    expect(model.locationState, LocationState.FOLLOW_AND_ROTATE_MAP);
    model.onCompassNorthUpPressed();
    expect(model.navigationPaused, isFalse);

    model.pauseNavigation();
    expect(model.navigationPaused, isTrue);
    expect(model.navigationActive, isFalse);
    expect(model.resumeNavigationCameraFollowing(), isFalse);

    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    expect(model.navigationPaused, isTrue);
    expect(await model.startNavigation(), isTrue);
    expect(model.navigationPaused, isFalse);

    model.clearDestination();
    expect(model.navigationPaused, isFalse);
    expect(model.navigationActive, isFalse);
  });

  test('camera modes cannot resume an explicit pause or unavailable location',
      () async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    addTearDown(model.dispose);
    expect(model.resumeNavigationCameraFollowing(), isFalse);
    await model.startNavigation();
    model.locationState = LocationState.FOLLOW;
    expect(model.navigationActive, isTrue);
    expect(model.resumeNavigationCameraFollowing(), isFalse);
    model.locationState = LocationState.NOT_AVAILABLE;
    expect(model.navigationPaused, isTrue);
    expect(model.resumeNavigationCameraFollowing(), isFalse);
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    expect(model.navigationActive, isTrue);
    model.pauseNavigation();
    model.clearDestination();
    expect(model.navigationPaused, isFalse);
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    expect(model.navigationPaused, isFalse);
  });

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

  test('secret tips survive failed V20 refresh and recover with fresh data',
      () async {
    final api = _SecretTipsApi();
    final model =
        MapScreenViewModel(store: _MemorySettingsStore(), munichwaysApi: api);
    addTearDown(model.dispose);
    Future<void> refresh() async {
      await model.refreshRadlnetze(minimumLoadingDuration: Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    await refresh();
    final original = model.secretTipsGeoJson;
    expect((original['features'] as List).single['properties']['name'],
        'Isarblick');
    api.fail = true;
    await refresh();
    expect(identical(model.secretTipsGeoJson, original), isTrue);
    expect(model.hasRatings, isTrue);
    api.fail = false;
    api.name = 'Neuer Geheimtipp';
    await refresh();
    expect(
        (model.secretTipsGeoJson['features'] as List).single['properties']
            ['name'],
        'Neuer Geheimtipp');
  });

  test(
      'detail destination previews first and enters history once on successful start',
      () async {
    final history = _DetailHistory();
    final model = _DetailRouteModel(history);
    addTearDown(model.dispose);
    final place = Place('Isarblick', const LatLng(48.2, 11.6));
    expect(await model.previewDetailDestination(place), isTrue);
    expect(model.navigationStarted, isFalse);
    expect(history.places, isEmpty);
    model.locationState = LocationState.NOT_AVAILABLE;
    expect(await model.startNavigation(), isFalse);
    expect(history.places, isEmpty);
    model.locationState = LocationState.FOLLOW;
    expect(await model.startNavigation(), isTrue);
    expect(history.places, [place]);
    await model.startNavigation();
    expect(history.places, [place]);
  });

  test(
      'discarded detail preview does not enter history for another destination',
      () async {
    final history = _DetailHistory();
    final model = _DetailRouteModel(history);
    addTearDown(model.dispose);
    await model.previewDetailDestination(
        Place('Geheimtipp', const LatLng(48.2, 11.6)));
    model.clearDestination();
    expect(
        await model.setDestinationAndCalculateRoute(
            Place('Other POI', const LatLng(48.3, 11.7))),
        isTrue);
    model.locationState = LocationState.FOLLOW;
    expect(await model.startNavigation(), isTrue);
    expect(history.places, isEmpty);
  });

  test(
      'street detail destination uses V20 midpoint or bundled fallback geometry',
      () async {
    final model = MapScreenViewModel(
        store: _MemorySettingsStore(), munichwaysApi: _SecretTipsApi());
    addTearDown(model.dispose);
    final details = StreetDetails.fromV20Json({
      'properties': {'osm_name': 'Street'},
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [11, 0],
          [11.1, 0]
        ]
      },
    });
    expect(model.destinationForStreet(details)!.latLng.longitude,
        closeTo(11.05, .00001));
    await model.refreshRadlnetze(minimumLoadingDuration: Duration.zero);
    expect(model.destinationForStreet(_localRatings.first.details!), isNotNull);
    expect(model.destinationForStreet(StreetDetails(name: 'Missing geometry')),
        isNull);
  });

  test('allows slow initial and manual downloads the same inactivity deadline',
      () async {
    final api = _RecordingMunichwaysApi();
    final model = MapScreenViewModel(
      store: _MemorySettingsStore(),
      munichwaysApi: api,
    );

    model.startInitialLoad();
    await Future<void>.delayed(Duration.zero);

    expect(api.responseTimeout, const Duration(seconds: 90));
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
    expect(model.hasRatings, isTrue);
    expect(model.polylines, _localRatings);
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

  test('reload joins initial enrichment and revalidates without deleting cache',
      () async {
    final api = _ControlledMunichwaysApi();
    final model =
        MapScreenViewModel(store: _MemorySettingsStore(), munichwaysApi: api);
    addTearDown(model.dispose);
    final initial = model.refreshRadlnetze();
    await Future<void>.delayed(Duration.zero);
    api.responses.add(_localRatings);
    await Future<void>.delayed(Duration.zero);
    expect(model.loading, isFalse);
    expect(model.hasRatings, isTrue);
    final reload = model.reloadRadnetz();
    expect(identical(initial, reload), isTrue);
    expect(api.requests, 1);
    await api.responses.close();
    expect(await initial, isTrue);
    api.responses = StreamController<Set<MPolyline>>();
    final revalidation = model.reloadRadnetz();
    await Future<void>.delayed(Duration.zero);
    expect(api.requests, 2);
    expect(api.forceRefresh, isTrue);
    expect(api.responseTimeout, const Duration(seconds: 90));
    expect(api.cacheRemovals, 0);
    api.responses.add(_localRatings);
    api.responses.addError(TimeoutException('offline'));
    await api.responses.close();
    expect(await revalidation, isFalse);
    expect(model.hasRatings, isTrue);
    expect(model.loading, isFalse);
    expect(model.initialRatingsLoadFailed, isTrue);
    api.responses = StreamController<Set<MPolyline>>();
    final recovery = model.refreshRadlnetze(forceRefresh: true);
    await Future<void>.delayed(Duration.zero);
    api.responses.add(_localRatings);
    await api.responses.close();
    expect(await recovery, isTrue);
    expect(model.initialRatingsLoadFailed, isFalse);
  });

  test('disposing during enrichment ignores late results and ends loading',
      () async {
    final api = _ControlledMunichwaysApi();
    final model =
        MapScreenViewModel(store: _MemorySettingsStore(), munichwaysApi: api);
    final pending = model.refreshRadlnetze();
    await Future<void>.delayed(Duration.zero);
    model.dispose();
    api.responses.add(_localRatings);
    await api.responses.close();
    expect(await pending, isFalse);
    expect(model.loading, isFalse);
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
    expect(bRouter.profiles, [BRouterProfile.fastBike]);

    // Manual refresh and automatic rerouting share this request path.
    expect(await model.refreshRoute(), isTrue);
    expect(
      bRouter.profiles,
      [BRouterProfile.fastBike, BRouterProfile.fastBike],
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
    bool forceRefresh = false,
  }) =>
      StreamController<Set<MPolyline>>()
          .stream
          .timeout(responseTimeout ?? const Duration(seconds: 6));

  @override
  Future<Map<String, StreetDetails>> getStreetDetails(
          {bool forceRefresh = false}) async =>
      {};
}

class _RecordingMunichwaysApi extends MunichwaysApi {
  Duration? responseTimeout;

  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
    bool forceRefresh = false,
  }) async* {
    this.responseTimeout = responseTimeout;
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails(
          {bool forceRefresh = false}) async =>
      {};
}

class _FallbackOnlyMunichwaysApi extends MunichwaysApi {
  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
    bool forceRefresh = false,
  }) async* {
    yield _localRatings;
    await Completer<void>().future.timeout(
          responseTimeout ?? const Duration(seconds: 6),
        );
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails(
          {bool forceRefresh = false}) async =>
      {};
}

class _ReloadFailureMunichwaysApi extends MunichwaysApi {
  @override
  Future<void> removeRatingsCache() async {}

  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
    bool forceRefresh = false,
  }) async* {
    yield _localRatings;
    throw TimeoutException('offline');
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails(
          {bool forceRefresh = false}) async =>
      {};
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

final _localRatings = {
  MPolyline(
      points: const [LatLng(48.1, 11.5), LatLng(48.2, 11.6)],
      details: StreetDetails(farbe: 'grün', isMunichWaysRadlVorrangNetz: true)),
};

class _ControlledMunichwaysApi extends MunichwaysApi {
  var responses = StreamController<Set<MPolyline>>();
  var requests = 0;
  var cacheRemovals = 0;
  bool? forceRefresh;
  Duration? responseTimeout;
  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates(
      {Duration? responseTimeout, bool forceRefresh = false}) {
    requests++;
    this.forceRefresh = forceRefresh;
    this.responseTimeout = responseTimeout;
    return responses.stream;
  }

  @override
  Future<void> removeRatingsCache() async {
    cacheRemovals++;
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails(
          {bool forceRefresh = false}) async =>
      {};
}

class _SecretTipsApi extends MunichwaysApi {
  bool fail = false;
  String name = 'Isarblick';
  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates(
      {Duration? responseTimeout, bool forceRefresh = false}) async* {
    yield _localRatings;
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails(
      {bool forceRefresh = false}) async {
    if (fail) throw StateError('Temporary network failure');
    return {
      'tip': StreetDetails.fromV20Json({
        'properties': {
          'munichways_id': 'MW-tip',
          'munichways_name': name,
          'munichways_neuralgic_point': 'Geheimtipp'
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [11.5, 48.1]
        },
      })
    };
  }
}

class _DetailHistory extends RecentSearchesStore {
  final places = <Place>[];
  @override
  Future<void> add(Place place,
      {int maxEntries = RecentSearchesStore.maxEntries}) async {
    places.add(place);
  }
}

class _DetailRouteModel extends MapScreenViewModel {
  _DetailRouteModel(RecentSearchesStore history)
      : super(
          store: _MemorySettingsStore(),
          detailDestinationsStore: history,
          routingService: RoutingService(
              radlNavi: _RecordingRoutingProvider(),
              bRouter: _RecordingRoutingProvider(),
              radlNaviCoverage: _AlwaysCovered()),
        );
  @override
  Future<Position?> resolveRouteStartPosition() async => Position(
        latitude: 48.1,
        longitude: 11.5,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
  @override
  Future<void> onPressLocationBtn(
      {bool permissionCheck = true, bool followLocation = true}) async {}
}
