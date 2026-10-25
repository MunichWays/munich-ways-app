import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/vector_basemap_constants.dart';
import 'package:provider/provider.dart';

import '../../support/wakelock_stub.dart';

class _SettingsStore extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;

  @override
  Future<void> saveVoiceGuidanceEnabled(bool enabled) async {}
}

class _LayoutMapPlatform extends MapLibrePlatform {
  // Retain the real MapLibre widget and its layout, without a native GL engine.
  @override
  Widget buildView(
          Map<String, dynamic> creationParams,
          OnPlatformViewCreatedCallback onPlatformViewCreated,
          Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers) =>
      const SizedBox.expand(child: ColoredBox(color: Colors.transparent));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  for (final scenario in [
    'spoken',
    'muted',
    'map-only',
    'speech failure',
    'permission enables speech',
  ]) {
    testWidgets('navigation start preview: $scenario', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      stubWakelock();
      final originalSettings = settingsStore;
      settingsStore = _SettingsStore();
      addTearDown(() => settingsStore = originalSettings);
      final originalMapFactory = MapLibrePlatform.createInstance;
      MapLibrePlatform.createInstance = () => _LayoutMapPlatform();
      addTearDown(() => MapLibrePlatform.createInstance = originalMapFactory);
      const ttsChannel = MethodChannel('flutter_tts');
      const notificationChannel =
          MethodChannel('com.munichways.app/notification_permission');
      final messenger = tester.binding.defaultBinaryMessenger;
      final spoken = <String>[];
      var failSpeech = scenario == 'speech failure';
      messenger.setMockMethodCallHandler(ttsChannel, (call) async {
        if (call.method == 'speak') {
          spoken.add(call.arguments is String
              ? call.arguments as String
              : (call.arguments as Map)['text'] as String);
          if (failSpeech) {
            throw PlatformException(code: 'temporarily_unavailable');
          }
        }
        return 1;
      });
      messenger.setMockMethodCallHandler(notificationChannel, (call) async {
        if (call.method == 'isGranted') {
          return scenario != 'permission enables speech';
        }
        return true;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(ttsChannel, null);
        messenger.setMockMethodCallHandler(notificationChannel, null);
      });
      await tester
          .runAsync(() => rootBundle.loadString(kOpenFreeMapLibertyStyleAsset));
      await tester.pumpWidget(const MaterialApp(
        home: MapScreen(startupInteractionsEnabled: false),
      ));
      await tester.runAsync(() async {
        await rootBundle.loadString(kOpenFreeMapLibertyStyleAsset);
        await settingsStore.load();
      });
      await tester.pump();
      final model =
          tester.element(find.byType(MapLibreMap)).read<MapScreenViewModel>();
      model
        ..destination = Place('Ziel', const latlong.LatLng(48.15, 11.57))
        ..route = MapRoute(
          CycleRoute(
            const [latlong.LatLng(48.14, 11.57), latlong.LatLng(48.15, 11.57)],
            1000,
            300,
            supportsVoiceGuidance: scenario != 'map-only',
            maneuvers: const [
              RouteManeuver(
                  location: latlong.LatLng(48.141, 11.57),
                  type: 'turn',
                  modifier: 'right',
                  roadName: 'Laimer Straße',
                  wayType: RouteWayType.road),
              RouteManeuver(
                  location: latlong.LatLng(48.143, 11.57),
                  type: 'turn',
                  modifier: 'left'),
            ],
          ),
          MapRouteState.SHOWN,
        )
        ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP
        ..toggleGesamtnetzVisible();
      // The regular start must speak with fresh-install settings, without a
      // speaker tap or an Android notification permission grant.
      expect(model.voiceGuidanceEnabled, isTrue);
      if (scenario == 'muted' || scenario == 'permission enables speech') {
        model.setVoiceGuidanceEnabled(false);
      }
      await tester.pump();
      expect(spoken, isEmpty);
      await tester.tap(find.bySemanticsLabel('Starten'));
      await tester.pump();
      await tester.pump();
      if (scenario == 'permission enables speech') {
        expect(spoken, isEmpty);
        expect(find.text('Navigations-Mitteilungen erlauben?'), findsOneWidget);
        await tester.tap(find.text('Weiter'));
        await tester.pump();
        await tester.pump();
      }
      expect(model.navigationActive, isTrue);
      if (scenario == 'muted' || scenario == 'map-only') {
        expect(spoken, isEmpty);
      } else {
        expect(spoken, [
          'In 110 Metern rechts abbiegen in Laimer Straße, danach links abbiegen.'
        ]);
      }
      await tester.pump();
      expect(
          spoken.length, scenario == 'muted' || scenario == 'map-only' ? 0 : 1);
      if (scenario == 'speech failure') {
        failSpeech = false;
        await tester.tap(find.bySemanticsLabel('Sprachansagen ausschalten'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Sprachansagen einschalten'));
        await tester.pump();
        expect(spoken.last, 'Sprachansagen aktiviert.');
        expect(model.navigationActive, isTrue);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  }

  testWidgets('touching the real map keeps guidance active; only close pauses',
      (tester) async {
    stubWakelock();
    final originalSettings = settingsStore;
    settingsStore = _SettingsStore();
    addTearDown(() => settingsStore = originalSettings);
    final originalMapFactory = MapLibrePlatform.createInstance;
    MapLibrePlatform.createInstance = () => _LayoutMapPlatform();
    addTearDown(() => MapLibrePlatform.createInstance = originalMapFactory);
    const ttsChannel = MethodChannel('flutter_tts');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (_) async => 1);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null));
    await tester
        .runAsync(() => rootBundle.loadString(kOpenFreeMapLibertyStyleAsset));
    await tester.pumpWidget(const MaterialApp(
      home: MapScreen(startupInteractionsEnabled: false),
    ));
    await tester.runAsync(() async {
      await rootBundle.loadString(kOpenFreeMapLibertyStyleAsset);
      await settingsStore.load();
    });
    await tester.pump();
    final model =
        tester.element(find.byType(MapLibreMap)).read<MapScreenViewModel>();
    model
      ..destination = Place('Ziel', const latlong.LatLng(48.15, 11.57))
      ..route = MapRoute(
        CycleRoute(
            const [latlong.LatLng(48.14, 11.57), latlong.LatLng(48.15, 11.57)],
            1000,
            300),
        MapRouteState.SHOWN,
      )
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    await tester.pump();
    final map = find.byType(MapLibreMap);
    final gesture = await tester
        .startGesture(tester.getTopLeft(map) + const Offset(25, 180));
    await gesture.moveBy(const Offset(60, 30));
    await tester.pump();
    expect(model.locationState, LocationState.DISPLAY);
    expect(model.navigationActive, isTrue);
    expect(find.text('Pause'), findsNothing);
    expect(find.bySemanticsLabel('Fortsetzen'), findsNothing);
    expect(find.bySemanticsLabel('Route neu berechnen'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(model.navigationActive, isTrue);
    await tester.tap(find.bySemanticsLabel('Navigation pausieren'));
    await tester.pump();
    expect(model.navigationPaused, isTrue);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.bySemanticsLabel('Fortsetzen'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('keyboard animation preserves map size and moves only controls',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final originalSettings = settingsStore;
    settingsStore = _SettingsStore();
    addTearDown(() => settingsStore = originalSettings);
    final originalMapFactory = MapLibrePlatform.createInstance;
    var mapsCreated = 0;
    MapLibrePlatform.createInstance = () {
      mapsCreated++;
      return _LayoutMapPlatform();
    };
    addTearDown(() => MapLibrePlatform.createInstance = originalMapFactory);
    const ttsChannel = MethodChannel('flutter_tts');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (_) async => 1);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null));
    // Cache the asynchronous asset before advancing layout frames.
    await tester
        .runAsync(() => rootBundle.loadString(kOpenFreeMapLibertyStyleAsset));

    await tester.pumpWidget(const MaterialApp(
      home: MapScreen(startupInteractionsEnabled: false),
    ));
    await tester.runAsync(() async {
      await rootBundle.loadString(kOpenFreeMapLibertyStyleAsset);
      await settingsStore.load();
    });
    await tester.pump();
    expect(find.byType(MapLibreMap), findsOneWidget);

    for (final keyboardHeight in [0.0, 40.0, 300.0, 190.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
      await tester.pump();
      expect(tester.getSize(find.byType(MapLibreMap)), const Size(400, 800));
      expect(mapsCreated, 1);
      final controls = find.byWidgetPredicate(
          (widget) => widget is Positioned && widget.child is SafeArea);
      expect(controls, findsOneWidget);
      final safeArea = tester.widget<Positioned>(controls).child;
      expect(tester.getSize(find.byWidget(safeArea)),
          Size(400, 800 - keyboardHeight));
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    // Let the deferred initial-load task observe the disposed model.
    await tester.pump(const Duration(milliseconds: 1));
  });
}
