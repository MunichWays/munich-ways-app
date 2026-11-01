import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/map_background.dart';
import 'package:munich_ways/ui/map/aerial_map_style.dart';
import 'package:munich_ways/ui/map/dark_map_style.dart';
import 'package:munich_ways/ui/map/map_attribution.dart';
import 'package:munich_ways/ui/map/map_overlay/bikenet_selection_sheet.dart';
import 'package:munich_ways/ui/map/map_overlay/map_side_action_buttons.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/vector_basemap_constants.dart';

void main() {
  for (final side in MapSidePanelEdge.values) {
    testWidgets('map and zoom buttons stay on screen in landscape on $side',
        (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = MapScreenViewModel(
          store: MemoryMapSettings(), setScreenAwake: (_) async {});
      final bearing = ValueNotifier<double>(0);
      final idle = ValueNotifier<int>(0);
      addTearDown(() {
        model.dispose();
        bearing.dispose();
        idle.dispose();
      });
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Stack(children: [
        MapSideActionButtons(
            model: model,
            mapController: null,
            mapBearingDegrees: bearing,
            compassIdleTick: idle,
            additionalBottomOffset: 80,
            onNorthUp: () async {},
            queryMapBearingDegrees: () async => 0,
            onPressLocation: () {}),
      ]))));
      model.setSidePanelEdge(side);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Stack(children: [
        MapSideActionButtons(
            model: model,
            mapController: null,
            mapBearingDegrees: bearing,
            compassIdleTick: idle,
            additionalBottomOffset: 80,
            onNorthUp: () async {},
            queryMapBearingDegrees: () async => 0,
            onPressLocation: () {}),
      ]))));
      for (final label in [
        'Karte auswählen',
        'Vergrößern',
        'Verkleinern',
        'Standort'
      ]) {
        final rect = tester.getRect(find.byTooltip(label));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(360));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(640));
      }
      expect(tester.takeException(), isNull);
    });
  }

  final bundledStyle = File(kOpenFreeMapLibertyStyleAsset).readAsStringSync();
  for (final dark in [false, true]) {
    test(
        'aerial style retains standard fallback and label/overlay anchor, dark=$dark',
        () {
      final base = dark
          ? createDarkMapStyle(bundledStyle)
          : createCyclingMapStyle(bundledStyle);
      final style =
          jsonDecode(createAerialMapStyle(base)) as Map<String, dynamic>;
      final sources = style['sources'] as Map<String, dynamic>;
      expect(sources['openmaptiles'],
          (jsonDecode(base) as Map)['sources']['openmaptiles']);
      expect(sources['bavaria-aerial']['maxzoom'], 19);
      expect(sources['bavaria-aerial']['tileSize'], 256);
      expect(sources['bavaria-aerial']['bounds'], hasLength(4));
      final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
      final rasterIndex =
          layers.indexWhere((layer) => layer['id'] == 'bavaria-aerial');
      final labelIndex = layers.indexWhere(
          (layer) => layer['id'] == kOpenFreeMapBasemapOverlayBelowLayerId);
      expect(rasterIndex, labelIndex - 1);
      expect(layers[rasterIndex]['type'], 'raster');
      expect(
          layers.singleWhere((layer) => layer['id'] == 'road_label')['paint']
              ['text-halo-width'],
          1.5);
      expect(
          layers.map((layer) => layer['id']).toSet(), hasLength(layers.length));
    });
  }

  test('navigation locks background through pause and unlocks after ending',
      () async {
    final store = MemoryMapSettings();
    final model =
        MapScreenViewModel(store: store, setScreenAwake: (_) async {});
    addTearDown(model.dispose);
    await Future<void>.delayed(Duration.zero);
    model.setMapBackground(MapBackground.aerial);
    model.toggleGesamtnetzVisible();
    model.setShowMapButton(false);
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    expect(await model.startNavigation(), isTrue);
    expect(model.canChangeMapBackground, isFalse);
    model.setMapBackground(MapBackground.standard);
    expect(model.mapBackground, MapBackground.aerial);
    model.pauseNavigation();
    model.setMapBackground(MapBackground.standard);
    expect(model.mapBackground, MapBackground.aerial);
    expect(store.data.mapBackground, MapBackground.aerial);
    model.clearDestination();
    expect(model.canChangeMapBackground, isTrue);
    model.setMapBackground(MapBackground.standard);
    await Future<void>.delayed(Duration.zero);
    expect(store.data.mapBackground, MapBackground.standard);
    expect(store.data.showMapButton, isFalse);
    expect(store.data.gesamtnetzVisible, isFalse);
  });

  test('failed navigation start unlocks selection for retry', () async {
    final model = _PendingStartModel();
    addTearDown(model.dispose);
    await Future<void>.delayed(Duration.zero);
    final start = model.startNavigation();
    expect(model.navigationStartPending, isTrue);
    model.setMapBackground(MapBackground.aerial);
    expect(model.mapBackground, MapBackground.standard);
    model.permission.complete();
    expect(await start, isFalse);
    expect(model.canChangeMapBackground, isTrue);
    model.setMapBackground(MapBackground.aerial);
    expect(model.mapBackground, MapBackground.aerial);
  });

  test('late saved background cannot change an already running navigation',
      () async {
    final store = _DelayedSettings();
    final model = MapScreenViewModel(store: store, setScreenAwake: (_) async {})
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    addTearDown(model.dispose);
    await model.startNavigation();
    store.loaded.complete(
        SettingsData.defaults.copyWith(mapBackground: MapBackground.aerial));
    await Future<void>.delayed(Duration.zero);
    expect(model.mapBackground, MapBackground.standard);
    expect(model.navigationStarted, isTrue);
  });

  test('local selection wins over a late settings read', () async {
    final store = _DelayedSettings();
    final model =
        MapScreenViewModel(store: store, setScreenAwake: (_) async {});
    addTearDown(model.dispose);
    model.setMapBackground(MapBackground.aerial);
    model.setShowZoomButtons(false);
    model.setSidePanelEdge(MapSidePanelEdge.left);
    store.loaded.complete(SettingsData.defaults.copyWith(
      radlvorrangnetzVisible: false,
      gesamtnetzVisible: false,
      showMapButton: false,
    ));
    await Future<void>.delayed(Duration.zero);
    expect(model.mapBackground, MapBackground.aerial);
    expect(model.isRadlvorrangnetzVisible, isFalse);
    expect(model.isGesamtnetzVisible, isFalse);
    expect(model.showMapButton, isFalse);
    expect(store.data.mapBackground, MapBackground.aerial);
    expect(store.data.radlvorrangnetzVisible, isFalse);
    expect(store.data.gesamtnetzVisible, isFalse);
    expect(model.showZoomButtons, isFalse);
    expect(store.data.showZoomButtons, isFalse);
    expect(model.sidePanelEdge, MapSidePanelEdge.left);
    expect(store.data.sidePanelEdgeName, 'left');
  });

  testWidgets(
      'map button works without zoom buttons; sheet closes and choice stays at navigation start',
      (tester) async {
    final store = MemoryMapSettings();
    final model =
        MapScreenViewModel(store: store, setScreenAwake: (_) async {});
    final bearing = ValueNotifier<double>(0);
    final idle = ValueNotifier<int>(0);
    addTearDown(() {
      model.dispose();
      bearing.dispose();
      idle.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnimatedBuilder(
      animation: model,
      builder: (context, _) => Stack(children: [
        MapSideActionButtons(
          model: model,
          mapController: null,
          mapBearingDegrees: bearing,
          compassIdleTick: idle,
          onNorthUp: () async {},
          queryMapBearingDegrees: () async => 0,
          onPressLocation: () {},
        )
      ]),
    ))));
    await tester.pump();
    model.setShowZoomButtons(false);
    await tester.pump();
    expect(find.byTooltip('Vergrößern'), findsNothing);
    await tester.tap(find.byTooltip('Karte auswählen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luftbild Bayern'));
    await tester.pumpAndSettle();
    expect(model.mapBackground, MapBackground.aerial);
    expect(
        tester
            .getSemantics(find.bySemanticsLabel('Luftbild Bayern'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue);
    await tester.tap(find.text('Weitere Strecken'));
    await tester.pumpAndSettle();
    expect(model.isGesamtnetzVisible, isFalse);
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    await tester.pumpAndSettle();
    expect(find.byType(BikenetSelectionSheet), findsNothing);
    expect(find.byTooltip('Karte auswählen'), findsNothing);
    expect(model.mapBackground, MapBackground.aerial);
    // The menu and any other caller use the same guarded entry point.
    await showMapLayersSheet(tester.element(find.byType(Scaffold)), model);
    await tester.pumpAndSettle();
    expect(find.byType(BikenetSelectionSheet), findsNothing);
    model.pauseNavigation();
    await tester.pump();
    expect(find.byTooltip('Karte auswählen'), findsNothing);
    model.clearDestination();
    await tester.pump();
    expect(find.byTooltip('Karte auswählen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map choices and network switches fit large text and landscape',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MapScreenViewModel(
        store: MemoryMapSettings(), setScreenAwake: (_) async {});
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
              size: Size(640, 360), textScaler: TextScaler.linear(2)),
          child: Scaffold(body: BikenetSelectionSheet(model: model)),
        )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Weitere Strecken'));
    await tester.tap(find.text('Weitere Strecken'));
    await tester.pumpAndSettle();
    expect(model.isGesamtnetzVisible, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'aerial sources remain visible when attribution details are closed',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Align(
      alignment: Alignment.topLeft,
      child: MapAttribution(
          expanded: false, inline: true, background: MapBackground.aerial),
    ))));
    expect(find.textContaining('Copernicus Sentinel-2'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class MemoryMapSettings extends SettingsStore {
  MemoryMapSettings([this.data = SettingsData.defaults]);
  SettingsData data;

  @override
  Future<SettingsData> load() async => data;

  @override
  Future<void> saveMapSettings(
      {required bool showZoomButtons,
      required String sidePanelEdgeName,
      MapBackground? mapBackground,
      bool? showMapButton,
      bool? radlvorrangnetzVisible,
      bool? gesamtnetzVisible}) async {
    data = data.copyWith(
        showZoomButtons: showZoomButtons,
        sidePanelEdgeName: sidePanelEdgeName,
        mapBackground: mapBackground,
        showMapButton: showMapButton,
        radlvorrangnetzVisible: radlvorrangnetzVisible,
        gesamtnetzVisible: gesamtnetzVisible);
  }
}

class _PendingStartModel extends MapScreenViewModel {
  _PendingStartModel()
      : super(store: MemoryMapSettings(), setScreenAwake: (_) async {});
  final permission = Completer<void>();
  @override
  Future<void> onPressLocationBtn(
          {bool permissionCheck = true, bool followLocation = true}) =>
      permission.future;
}

class _DelayedSettings extends MemoryMapSettings {
  final loaded = Completer<SettingsData>();
  @override
  Future<SettingsData> load() => loaded.future;
}
