import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
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
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/navigation_screen_awake.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
  tearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

  test('foreground lifecycle restores an externally released screen flag',
      () async {
    var active = true;
    var nativeEnabled = false;
    final calls = <bool>[];
    final controller = NavigationScreenAwake(
      navigationActive: () => active,
      setEnabled: (enabled) async {
        calls.add(enabled);
        nativeEnabled = enabled;
      },
    );
    addTearDown(controller.dispose);
    await controller.synchronize();
    expect(nativeEnabled, isTrue);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _settle();
    expect(nativeEnabled, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _settle();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle();
    expect(nativeEnabled, isTrue);
    nativeEnabled = false; // The OS changed the flag while our cache says true.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle();
    expect(nativeEnabled, isTrue);
    active = false;
    await controller.synchronize();
    expect(nativeEnabled, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle();
    expect(nativeEnabled, isFalse);
    expect(calls, [true, false, true, true, false, false]);
  });

  test('pause releases a delayed enable without racing native calls', () async {
    var active = true;
    final enabling = Completer<void>();
    final calls = <bool>[];
    final controller = NavigationScreenAwake(
      navigationActive: () => active,
      setEnabled: (enabled) async {
        calls.add(enabled);
        if (enabled) await enabling.future;
      },
    );
    addTearDown(controller.dispose);
    final start = controller.synchronize();
    await _settle();
    active = false;
    final pause = controller.synchronize();
    expect(calls, [true]);
    enabling.complete();
    await Future.wait([start, pause]);
    expect(calls, [true, false]);
  });

  test('dispose releases pending work and cannot reenable on app resume',
      () async {
    final enabling = Completer<void>();
    final calls = <bool>[];
    final controller = NavigationScreenAwake(
      navigationActive: () => true,
      setEnabled: (enabled) async {
        calls.add(enabled);
        if (enabled) await enabling.future;
      },
    );
    final start = controller.synchronize();
    await _settle();
    controller.dispose();
    enabling.complete();
    await start;
    await _settle();
    expect(calls, [true, false]);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle();
    expect(calls, [true, false]);
  });

  test('queued start/pause/start applies only the final authoritative state',
      () async {
    var active = true;
    final calls = <bool>[];
    final controller = NavigationScreenAwake(
        navigationActive: () => active,
        setEnabled: (enabled) async => calls.add(enabled));
    addTearDown(controller.dispose);
    final start = controller.synchronize();
    active = false;
    final pause = controller.synchronize();
    active = true;
    final resume = controller.synchronize(force: true);
    await Future.wait([start, pause, resume]);
    expect(calls, [true]);
  });

  test('native failure leaves navigation active and a later request recovers',
      () async {
    var fail = true;
    final calls = <bool>[];
    final model = _Model((enabled) async {
      calls.add(enabled);
      if (fail) throw StateError('temporary platform failure');
    })
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    addTearDown(model.dispose);
    expect(await model.startNavigation(), isTrue);
    await _settle();
    expect(model.navigationActive, isTrue);
    fail = false;
    expect(await model.startNavigation(), isTrue);
    await _settle();
    expect(calls.last, isTrue);
    model.pauseNavigation();
    await _settle();
    expect(calls.last, isFalse);
  });

  test('planning, pause, map inspection, refresh and end derive screen state',
      () async {
    final calls = <bool>[];
    final provider = _Provider();
    final model =
        _Model((enabled) async => calls.add(enabled), provider: provider);
    addTearDown(model.dispose);
    model.setRoutePlan(
        start: Place('Start', model.position),
        stops: const [],
        destination: Place('Ziel', const LatLng(48.15, 11.58)));
    await _settle();
    expect(calls, isEmpty); // Planning alone must not hold the display awake.
    expect(await model.startNavigation(), isTrue);
    await _settle();
    expect(calls.last, isTrue);
    model.onUserStoppedFollowingLocation();
    await _settle();
    expect(model.navigationActive, isTrue);
    expect(calls.last, isTrue);
    model.pauseNavigation();
    await _settle();
    expect(calls.last, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle();
    expect(calls.last, isFalse); // App resume cannot undo an explicit pause.
    provider.fail = true;
    expect(await model.refreshRoute(), isFalse);
    await _settle();
    expect(calls.last, isFalse);
    provider.fail = false;
    expect(await model.refreshRoute(), isTrue);
    // The screen's Refresh action resumes only after successful recalculation.
    expect(await model.startNavigation(), isTrue);
    await _settle();
    expect(calls.last, isTrue);
    final previousEnables = calls.where((enabled) => enabled).length;
    expect(await model.refreshRoute(), isTrue);
    expect(await model.startNavigation(), isTrue);
    await _settle();
    expect(calls.where((enabled) => enabled).length, previousEnables + 1);
    model.clearDestination();
    await _settle();
    expect(calls.last, isFalse);
  });

  test('saved original route enables the screen only after navigation starts',
      () async {
    final transfer = RouteTransfer.fromJson(jsonDecode(
        await File('test_resources/routing/route-transfer.json')
            .readAsString()));
    final calls = <bool>[];
    final model = _Model((enabled) async => calls.add(enabled))
      ..position = transfer.plan.first.latLng;
    addTearDown(model.dispose);
    model.setSavedRoutePlan(SavedRoute(
        name: transfer.name,
        start: transfer.plan.first,
        stops: transfer.plan.sublist(1, transfer.plan.length - 1),
        destination: transfer.plan.last,
        snapshot: transfer));
    await _settle();
    expect(calls, isEmpty);
    expect(await model.startNavigation(), isTrue);
    await _settle();
    expect(calls.last, isTrue);
    model.pauseNavigation();
    await _settle();
    expect(calls.last, isFalse);
  });

  test('failed navigation start never holds the screen awake', () async {
    final calls = <bool>[];
    final model = _Model((enabled) async => calls.add(enabled))
      ..locationAvailable = false;
    addTearDown(model.dispose);
    expect(await model.startNavigation(), isFalse);
    await _settle();
    expect(calls, isEmpty);
  });

  test('location recovery cannot override a deliberate pause', () async {
    final calls = <bool>[];
    final model = _Model((enabled) async => calls.add(enabled));
    addTearDown(model.dispose);
    await model.startNavigation();
    await _settle();
    expect(calls.last, isTrue);
    model.locationAvailable = false;
    await model.onPressLocationBtn();
    await _settle();
    expect(calls.last, isFalse);
    model.locationAvailable = true;
    await model.onPressLocationBtn();
    await _settle();
    expect(calls.last, isTrue);
    model.pauseNavigation();
    await _settle();
    await model.onPressLocationBtn();
    await _settle();
    expect(model.navigationPaused, isTrue);
    expect(calls.last, isFalse);
  });
}

class _Settings extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

class _Coverage implements RoutingCoverage {
  @override
  Future<bool> contains(LatLng point) async => true;
}

class _Provider implements RoutingProvider {
  bool fail = false;
  @override
  Future<CycleRoute> route(List<LatLng> coordinates,
      {BRouterProfile profile = BRouterProfile.trekking}) async {
    if (fail) throw StateError('offline');
    return CycleRoute(coordinates, 1000, 300);
  }
}

class _Model extends MapScreenViewModel {
  _Model(Future<void> Function(bool) setter, {_Provider? provider})
      : super(
            store: _Settings(),
            setScreenAwake: setter,
            routingService: RoutingService(
                radlNavi: provider ?? _Provider(),
                bRouter: provider ?? _Provider(),
                radlNaviCoverage: _Coverage()));
  LatLng position = const LatLng(48.14, 11.57);
  bool locationAvailable = true;
  @override
  Future<void> onPressLocationBtn(
      {bool permissionCheck = true, bool followLocation = true}) async {
    locationState =
        locationAvailable ? LocationState.FOLLOW : LocationState.NOT_AVAILABLE;
    notifyListeners();
  }

  @override
  Future<Position?> resolveRouteStartPosition() async => Position(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}
