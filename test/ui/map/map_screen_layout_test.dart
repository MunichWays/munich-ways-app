import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/map/vector_basemap_constants.dart';

class _SettingsStore extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

class _LayoutMapPlatform extends MapLibrePlatform {
  // Retain the real MapLibre widget and its layout, without a native GL engine.
  @override
  Widget buildView(
          Map<String, dynamic> creationParams,
          OnPlatformViewCreatedCallback onPlatformViewCreated,
          Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers) =>
      const SizedBox.expand();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
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
