import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/ui/map/map_overlay/map_side_action_buttons.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/vector_basemap_constants.dart';
import 'package:provider/provider.dart';

import '../../support/wakelock_stub.dart';

class _Settings extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

const _initial =
    CameraPosition(target: LatLng(48.14, 11.57), zoom: 16, bearing: 90);

/// Retains the real controller/camera callbacks while replacing native GL.
class _CameraPlatform extends MapLibrePlatform {
  CameraPosition camera = _initial;
  final updates = <List<dynamic>>[];
  Completer<void>? holdNext;
  bool failNext = false;

  @override
  Widget buildView(
          Map<String, dynamic> creationParams,
          OnPlatformViewCreatedCallback onPlatformViewCreated,
          Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers) =>
      const SizedBox.expand();

  Future<bool?> _update(CameraUpdate update) async {
    final data = update.toJson() as List<dynamic>;
    updates.add(data);
    final hold = holdNext;
    holdNext = null;
    if (hold != null) await hold.future;
    if (failNext) {
      failNext = false;
      throw StateError('temporary camera failure');
    }
    if (data.first == 'newCameraPosition') {
      camera = CameraPosition.fromMap(data[1])!;
    } else if (data.first == 'tiltTo') {
      camera = CameraPosition(
          target: camera.target,
          zoom: camera.zoom,
          bearing: camera.bearing,
          tilt: (data[1] as num).toDouble());
    } else if (data.first == 'zoomTo') {
      camera = CameraPosition(
          target: camera.target,
          zoom: (data[1] as num).toDouble(),
          bearing: camera.bearing,
          tilt: camera.tilt);
    }
    onCameraMovePlatform(camera);
    onCameraIdlePlatform(camera);
    return true;
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) => _update(cameraUpdate);
  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate,
          {Duration? duration}) =>
      _update(cameraUpdate);
  @override
  Future<CameraPosition?> queryCameraPosition() async => camera;
  @override
  Future<Point> toScreenLocation(LatLng latLng) async => const Point(100, 100);
  @override
  Future<List<String>> getLayerIds() async => [];
  @override
  Future<List<String>> getSourceIds() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump();
}

Future<({MapScreenViewModel model, _CameraPlatform platform})> _open(
    WidgetTester tester) async {
  stubWakelock();
  final oldSettings = settingsStore;
  settingsStore = _Settings();
  addTearDown(() => settingsStore = oldSettings);
  final platform = _CameraPlatform();
  final oldFactory = MapLibrePlatform.createInstance;
  MapLibrePlatform.createInstance = () => platform;
  addTearDown(() => MapLibrePlatform.createInstance = oldFactory);
  const tts = MethodChannel('flutter_tts');
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(tts, (_) async => 1);
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(tts, null));
  await tester
      .runAsync(() => rootBundle.loadString(kOpenFreeMapLibertyStyleAsset));
  await tester.pumpWidget(
      const MaterialApp(home: MapScreen(startupInteractionsEnabled: false)));
  await tester.runAsync(() async {
    await rootBundle.loadString(kOpenFreeMapLibertyStyleAsset);
    await settingsStore.load();
  });
  await tester.pump();
  final map = tester.widget<MapLibreMap>(find.byType(MapLibreMap));
  final controller = MapLibreMapController(
      maplibrePlatform: platform,
      initialCameraPosition: _initial,
      annotationOrder: const [],
      annotationConsumeTapEvents: const [],
      onCameraMove: map.onCameraMove,
      onCameraIdle: map.onCameraIdle);
  map.onMapCreated!(controller);
  map.onStyleLoadedCallback!();
  await _frames(tester);
  final model =
      tester.element(find.byType(MapLibreMap)).read<MapScreenViewModel>();
  return (model: model, platform: platform);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GPS cameras keep perspective, zoom and bearing across navigation modes',
      () async {
    stubWakelock();
    final model = MapScreenViewModel(store: _Settings())
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    addTearDown(model.dispose);
    CameraPosition fix() => navigationCameraPosition(model,
        target: _initial.target, zoom: 17.5, bearing: 123);
    expect(fix().tilt, 0); // Planning cannot activate the riding perspective.
    await model.startNavigation();
    expect(fix().tilt, 30);
    expect(fix().zoom, 17.5);
    expect(fix().bearing, 123);
    expect(fix().target, _initial.target);
    model.onUserStoppedFollowingLocation();
    expect(navigationCameraTilt(model), isNull); // Keep a gesture undisturbed.
    expect(model.navigationActive, isTrue);
    expect(model.resumeNavigationCameraFollowing(), isTrue);
    expect(fix().tilt, 30);
    model.locationState = LocationState.NOT_AVAILABLE;
    expect(fix().tilt, 0);
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    expect(fix().tilt, 30);
    model.pauseNavigation();
    expect(fix().tilt, 0);
    expect(model.resumeNavigationCameraFollowing(), isFalse);
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    expect(fix().tilt, 30);
    model.clearDestination();
    expect(fix().tilt, 0);
  });

  testWidgets('native perspective follows start, pause, north-up and end',
      (tester) async {
    final h = await _open(tester);
    final model = h.model;
    final platform = h.platform;
    expect(platform.camera.tilt, 0);
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    await _frames(tester);
    expect(platform.camera.tilt, 30);
    expect(platform.camera.target, _initial.target);
    expect(platform.camera.zoom, _initial.zoom);
    expect(platform.camera.bearing, _initial.bearing);
    model.onUserStoppedFollowingLocation();
    await _frames(tester);
    expect(platform.camera.tilt, 30);
    await tester
        .widget<MapSideActionButtons>(find.byType(MapSideActionButtons))
        .onNorthUp();
    await _frames(tester);
    expect(platform.camera.bearing, 0);
    expect(platform.camera.tilt, 0);
    expect(model.navigationActive, isTrue);
    expect(model.resumeNavigationCameraFollowing(), isTrue);
    await _frames(tester);
    expect(platform.camera.tilt, 30);
    model.pauseNavigation();
    await _frames(tester);
    expect(platform.camera.tilt, 0);
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation(); // Same entry point as successful Refresh.
    await _frames(tester);
    expect(platform.camera.tilt, 30);
    model.clearDestination();
    await _frames(tester);
    expect(platform.camera.tilt, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controllerCleanup(platform);
    await tester.pump();
  });

  testWidgets('late camera work cannot undo pause and errors allow recovery',
      (tester) async {
    final h = await _open(tester);
    final model = h.model;
    final platform = h.platform;
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    await _frames(tester);
    final hold = Completer<void>();
    platform.holdNext = hold;
    final north = tester
        .widget<MapSideActionButtons>(find.byType(MapSideActionButtons))
        .onNorthUp();
    await tester.pump();
    model.pauseNavigation();
    await tester.pump();
    hold.complete();
    await north;
    await _frames(tester);
    expect(
        platform.updates.any((update) => update.first == 'newCameraPosition'),
        isTrue);
    expect(platform.camera.tilt, 0);
    expect(model.navigationPaused, isTrue);
    platform.failNext = true;
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    await _frames(tester);
    expect(model.navigationActive, isTrue);
    expect(platform.camera.tilt, 0);
    model.onUserStoppedFollowingLocation();
    model.resumeNavigationCameraFollowing();
    await _frames(tester);
    expect(platform.camera.tilt, 30);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controllerCleanup(platform);
    await tester.pump();
  });
}

// The manually supplied controller has no platform-view owner in these tests.
void controllerCleanup(_CameraPlatform platform) {
  platform.onCameraMovePlatform.clear();
  platform.onCameraIdlePlatform.clear();
}
