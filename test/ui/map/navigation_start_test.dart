import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/model/route_transfer.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';
import 'package:munich_ways/routing/routing_service.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

import '../../support/wakelock_stub.dart';

const _start = LatLng(48.14, 11.57);
const _current = LatLng(48.13, 11.56);
final _plannedStart = Place('Start', _start);
final _stop = Place('Zwischenziel', const LatLng(48.15, 11.58));
final _destination = Place('Ziel', const LatLng(48.16, 11.59));

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(stubWakelock);

  test('fixed start at current location starts original route offline',
      () async {
    final h = _Harness();
    final original = h.model.route.route;
    h.model.position = Future.value(_position(_start));
    expect(await h.model.startNavigation(), isTrue);
    expect(h.provider.requests, isEmpty);
    expect(h.model.route.route, same(original));
    expect(h.model.routeStart, isNull);
    expect(h.model.waypoints, [_stop]);
    expect(h.model.navigationPaused, isFalse);
  });

  test('GPS offset inside start area does not add an extra stop', () async {
    final h = _Harness();
    h.model.position = Future.value(_position(const LatLng(48.1401, 11.57)));
    expect(await h.model.startNavigation(), isTrue);
    expect(h.provider.requests, isEmpty);
    expect(h.model.waypoints, [_stop]);
  });

  test('remote start becomes first stop before navigation starts', () async {
    final h = _Harness();
    final first = h.model.startNavigation();
    final second = h.model.startNavigation();
    expect(second, same(first));
    await _flush();
    expect(h.provider.requests.single,
        [_current, _start, _stop.latLng, _destination.latLng]);
    expect(h.model.navigationStarted, isFalse);
    expect(h.model.navigationStartPending, isTrue);
    final routed = CycleRoute(h.provider.requests.single, 2000, 600);
    h.provider.reply.complete(routed);
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(h.model.navigationStartPending, isFalse);
    expect(h.model.route.route, same(routed));
    expect(h.model.routeStart, isNull);
    expect(h.model.waypoints, [_plannedStart, _stop]);
    expect(h.model.positionLookups, 1);
  });

  test('failed approach keeps plan and original route; retry recovers',
      () async {
    final h = _Harness();
    final original = h.model.route.route;
    h.provider.fail = true;
    expect(await h.model.startNavigation(), isFalse);
    expect(h.model.navigationStarted, isFalse);
    expect(h.model.navigationStartPending, isFalse);
    expect(h.model.routeStart, _plannedStart);
    expect(h.model.waypoints, [_stop]);
    expect(h.model.route.route, same(original));
    expect(h.model.route.state, MapRouteState.SHOWN);
    h.provider.fail = false;
    final retry = h.model.startNavigation();
    await _flush();
    h.provider.reply.complete(CycleRoute(h.provider.requests.last, 2000, 600));
    expect(await retry, isTrue);
    expect(h.model.waypoints, [_plannedStart, _stop]);
  });

  test('comfort still completes while the approach fails', () async {
    final h = _Harness();
    final planning = h.model.refreshRoute();
    await _flush();
    final original = CycleRoute([_start, _destination.latLng], 1000, 300,
        analysisContext: RouteAnalysisContext([
          [1, 2]
        ]));
    h.provider.reply.complete(original);
    expect(await planning, isTrue);
    expect(h.model.route.comfortState, RouteComfortState.loading);
    h.provider.reply = Completer<CycleRoute>();
    final starting = h.model.startNavigation();
    await _flush();
    expect(h.model.route.route, same(original));
    const comfort = RouteComfort(
        index: 70,
        coverage: 100,
        sufficientCoverage: true,
        distribution: RouteComfortDistribution(
            black: 0, red: 0, yellow: 0, green: 100, unrated: 0));
    h.provider.comfortReply.complete(comfort);
    await _flush();
    expect(original.comfort, same(comfort));
    h.provider.reply.completeError(StateError('offline'));
    expect(await starting, isFalse);
    expect(h.model.route.route, same(original));
    expect(h.model.route.comfortState, RouteComfortState.ready);
    expect(h.model.routeStart, _plannedStart);
  });

  test('missing GPS and lookup errors retain route and allow another start',
      () async {
    final h = _Harness();
    final original = h.model.route.route;
    h.model.position = Future.value(null);
    expect(await h.model.startNavigation(), isFalse);
    h.model.positionError = StateError('GPS unavailable');
    expect(await h.model.startNavigation(), isFalse);
    expect(h.provider.requests, isEmpty);
    expect(h.model.routeStart, _plannedStart);
    expect(h.model.route.route, same(original));
    expect(h.model.navigationStartPending, isFalse);
    h.model.positionError = null;
    h.model.position = Future.value(_position(_start));
    expect(await h.model.startNavigation(), isTrue);
  });

  test('denied permission preserves the plan and can recover', () async {
    final h = _Harness();
    h.model.permissionGranted = false;
    expect(await h.model.startNavigation(), isFalse);
    expect(h.model.positionLookups, 0);
    expect(h.model.routeStart, _plannedStart);
    h.model.permissionGranted = true;
    h.model.position = Future.value(_position(_start));
    expect(await h.model.startNavigation(), isTrue);
  });

  test('ending plan during GPS lookup cannot start or restore it', () async {
    final h = _Harness();
    final gps = Completer<Position?>();
    h.model.position = gps.future;
    final starting = h.model.startNavigation();
    await _flush();
    h.model.clearDestination();
    gps.complete(_position(_current));
    expect(await starting, isFalse);
    expect(h.provider.requests, isEmpty);
    expect(h.model.destination, isNull);
    expect(h.model.navigationStarted, isFalse);
  });

  test('ending plan during approach ignores its late response', () async {
    final h = _Harness();
    final starting = h.model.startNavigation();
    await _flush();
    h.model.clearDestination();
    h.provider.reply.complete(CycleRoute([_current, _start], 1000, 300));
    expect(await starting, isFalse);
    expect(h.model.destination, isNull);
    expect(h.model.route.route, isNull);
    expect(h.model.routeStart, isNull);
    expect(h.model.waypoints, isEmpty);
    expect(h.model.navigationStarted, isFalse);
  });

  for (final atStart in [true, false]) {
    test('imported snapshot remains immutable on navigation start ($atStart)',
        () async {
      final h = _Harness();
      final snapshot = RouteTransfer.fromJson(jsonDecode(
          File('test_resources/routing/route-transfer.json')
              .readAsStringSync()));
      final saved = SavedRoute(
          name: snapshot.name,
          start: snapshot.plan.first,
          stops: snapshot.plan.sublist(1, snapshot.plan.length - 1),
          destination: snapshot.plan.last,
          snapshot: snapshot);
      h.model.setSavedRoutePlan(saved);
      h.model.position = Future.value(
          _position(atStart ? snapshot.plan.first.latLng : _current));
      final starting = h.model.startNavigation();
      if (!atStart) {
        await _flush();
        expect(h.provider.requests.single, [
          _current,
          ...snapshot.plan.map((place) => place.latLng),
        ]);
        h.provider.reply
            .complete(CycleRoute(h.provider.requests.single, 2000, 600));
      }
      expect(await starting, isTrue);
      expect(saved.snapshot, same(snapshot));
      expect(h.model.isOriginalRoute, atStart);
      if (atStart) {
        expect(h.provider.requests, isEmpty);
        expect(h.model.route.route, same(snapshot.route));
      }
    });
  }
}

class _Harness {
  final provider = _Provider();
  late final _Model model;
  _Harness() {
    model = _Model(RoutingService(
        radlNavi: provider, bRouter: provider, radlNaviCoverage: _Coverage()))
      ..routeStart = _plannedStart
      ..destination = _destination
      ..route = MapRoute(CycleRoute([_start, _destination.latLng], 1000, 300),
          MapRouteState.SHOWN);
    model.waypoints.add(_stop);
    addTearDown(model.dispose);
  }
}

class _Model extends MapScreenViewModel {
  _Model(RoutingService service)
      : super(store: _Settings(), routingService: service);
  Future<Position?> position = Future.value(_position(_current));
  var permissionGranted = true;
  var positionLookups = 0;
  Object? positionError;
  @override
  Future<Position?> resolveRouteStartPosition() {
    positionLookups++;
    if (positionError != null) throw positionError!;
    return position;
  }

  @override
  Future<void> onPressLocationBtn(
      {bool permissionCheck = true, bool followLocation = true}) async {
    locationState =
        permissionGranted ? LocationState.FOLLOW : LocationState.NOT_AVAILABLE;
  }
}

Position _position(LatLng point) => Position(
    latitude: point.latitude,
    longitude: point.longitude,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0);

class _Settings extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

class _Provider implements RoutingProvider, RouteComfortProvider {
  final requests = <List<LatLng>>[];
  var reply = Completer<CycleRoute>();
  final comfortReply = Completer<RouteComfort>();
  var fail = false;
  @override
  Future<CycleRoute> route(List<LatLng> coordinates,
      {BRouterProfile profile = BRouterProfile.trekking}) {
    requests.add(List.of(coordinates));
    if (fail) return Future.error(StateError('offline'));
    return reply.future;
  }

  @override
  Future<RouteComfort> analyzeComfort(RouteAnalysisContext context) =>
      comfortReply.future;
}

class _Coverage implements RoutingCoverage {
  @override
  Future<bool> contains(LatLng point) async => true;
}
