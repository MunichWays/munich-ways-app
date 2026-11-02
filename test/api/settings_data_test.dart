import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/map_background.dart';
import 'package:munich_ways/routing/routing_preferences.dart';

void main() {
  test('queued map, camera and appearance writes preserve each other',
      () async {
    final store = _QueuedSettingsStore();
    await Future.wait([
      store.saveMapSettings(
          showZoomButtons: false,
          sidePanelEdgeName: 'left',
          mapBackground: MapBackground.aerial,
          showMapButton: false,
          radlvorrangnetzVisible: false,
          gesamtnetzVisible: true),
      store.saveMap3dEnabled(false),
      store.saveThemeMode('dark'),
      store.saveLanguage('en'),
      store.saveMapCamera(
          latitude: 48.15, longitude: 11.59, zoom: 18, bearing: 72),
    ]);
    final restored = SettingsData.fromJson((await store.load()).toJson());
    expect(restored.map3dEnabled, isFalse);
    expect(restored.mapBackground, MapBackground.aerial);
    expect(restored.showMapButton, isFalse);
    expect(restored.radlvorrangnetzVisible, isFalse);
    expect(restored.gesamtnetzVisible, isTrue);
    expect(restored.themeModeName, 'dark');
    expect(restored.languageCode, 'en');
    expect(restored.mapZoom, 18);
    expect(restored.mapBearing, 72);
  });

  test('a transient map settings write failure does not block the next save',
      () async {
    final store = _QueuedSettingsStore()..failNextWrite = true;
    await expectLater(
        store.saveMapSettings(
            showZoomButtons: true,
            sidePanelEdgeName: 'right',
            mapBackground: MapBackground.aerial),
        throwsStateError);
    await store.saveMapSettings(
        showZoomButtons: true,
        sidePanelEdgeName: 'right',
        mapBackground: MapBackground.aerial,
        gesamtnetzVisible: false);
    expect((await store.load()).mapBackground, MapBackground.aerial);
    expect((await store.load()).gesamtnetzVisible, isFalse);
  });

  test('older and unknown map preferences retain safe visible defaults', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'mapBackground': 'unknown'}
    ]) {
      final data = SettingsData.fromJson(json);
      expect(data.mapBackground, MapBackground.standard);
      expect(data.showMapButton, isTrue);
      expect(data.map3dEnabled, isTrue);
      expect(data.radlvorrangnetzVisible, isTrue);
      expect(data.gesamtnetzVisible, isTrue);
    }
  });

  test('restores map choice and independently disabled networks and button',
      () {
    final restored = SettingsData.fromJson(SettingsData.defaults
        .copyWith(
          mapBackground: MapBackground.aerial,
          showMapButton: false,
          radlvorrangnetzVisible: false,
          gesamtnetzVisible: false,
        )
        .toJson());
    expect(restored.mapBackground, MapBackground.aerial);
    expect(restored.showMapButton, isFalse);
    expect(restored.radlvorrangnetzVisible, isFalse);
    expect(restored.gesamtnetzVisible, isFalse);
    final updated = restored.copyWith(showZoomButtons: false, mapZoom: 18);
    expect(updated.mapBackground, MapBackground.aerial);
    expect(updated.radlvorrangnetzVisible, isFalse);
    expect(updated.gesamtnetzVisible, isFalse);
    expect(updated.showMapButton, isFalse);
  });

  test('enables voice guidance for fresh installs and missing preferences', () {
    expect(SettingsData.defaults.voiceGuidanceEnabled, isTrue);
    expect(SettingsData.fromJson(const {}).voiceGuidanceEnabled, isTrue);
  });

  for (final enabled in [false, true]) {
    test('preserves saved voice guidance preference $enabled', () {
      final restored = SettingsData.fromJson(
        SettingsData.defaults.copyWith(voiceGuidanceEnabled: enabled).toJson(),
      );
      expect(restored.voiceGuidanceEnabled, enabled);
    });
  }

  test('persists the last map camera', () {
    final restored = SettingsData.fromJson(
      SettingsData.defaults
          .copyWith(
            mapLatitude: 48.14,
            mapLongitude: 11.57,
            mapZoom: 16.5,
            mapBearing: 25,
          )
          .toJson(),
    );

    expect(restored.mapLatitude, 48.14);
    expect(restored.mapLongitude, 11.57);
    expect(restored.mapZoom, 16.5);
    expect(restored.mapBearing, 25);
  });

  test('persists manual energy saving and defaults it to off', () {
    expect(SettingsData.fromJson(const {}).energySavingEnabled, isFalse);
    expect(
      SettingsData.fromJson(
        SettingsData.defaults.copyWith(energySavingEnabled: true).toJson(),
      ).energySavingEnabled,
      isTrue,
    );
  });

  test('shows zoom buttons by default, including older settings files', () {
    expect(SettingsData.defaults.showZoomButtons, isTrue);
    expect(SettingsData.fromJson(const {}).showZoomButtons, isTrue);
  });

  test('enables automatic rerouting by default, including older settings', () {
    expect(SettingsData.defaults.automaticReroutingEnabled, isTrue);
    expect(SettingsData.fromJson(const {}).automaticReroutingEnabled, isTrue);
    expect(
      SettingsData.fromJson(
        const {'automaticReroutingEnabled': false},
      ).automaticReroutingEnabled,
      isFalse,
    );
  });

  test('uses automatic RadlNavi and BRouter trekking by default', () {
    expect(SettingsData.defaults.routingMode, RoutingMode.automatic);
    expect(SettingsData.defaults.bRouterProfile, BRouterProfile.trekking);
    expect(
      SettingsData.defaults.routeRecommendation,
      RouteRecommendation.standard,
    );

    final freshInstall = SettingsData.fromJson(const {});
    expect(freshInstall.routingMode, RoutingMode.automatic);
    expect(freshInstall.bRouterProfile, BRouterProfile.trekking);
  });

  test(
      'discovery recommendation persists by name without shifting older choices',
      () {
    final data = SettingsData.fromJson({'routeRecommendation': 'discovery'});
    expect(data.routeRecommendation, RouteRecommendation.discovery);
    expect(data.toJson()['routeRecommendation'], 'discovery');
    expect(
        SettingsData.fromJson({'routeRecommendation': 'aloneAfterDark'})
            .routeRecommendation,
        RouteRecommendation.aloneAfterDark);
  });

  test('loads and stores a route recommendation', () {
    final data = SettingsData.fromJson({
      'routeRecommendation': 'aloneAfterDark',
    });

    expect(data.routeRecommendation, RouteRecommendation.aloneAfterDark);
    expect(data.toJson()['routeRecommendation'], 'aloneAfterDark');
    expect(
      SettingsData.fromJson(
        const {'routeRecommendation': 'unknown'},
      ).routeRecommendation,
      RouteRecommendation.standard,
    );
  });

  test('loads routing mode and BRouter profile', () {
    final data = SettingsData.fromJson({
      'routingMode': 'bRouterEverywhere',
      'bRouterProfile': 'fastBike',
    });

    expect(data.routingMode, RoutingMode.bRouterEverywhere);
    expect(data.bRouterProfile, BRouterProfile.fastBike);
  });

  test('migrates the previous BRouter mode and defaults invalid profiles', () {
    final data = SettingsData.fromJson({
      'routingMode': 'bRouter',
      'bRouterProfile': 'unknown',
    });

    expect(data.routingMode, RoutingMode.bRouterEverywhere);
    expect(data.bRouterProfile, BRouterProfile.trekking);
  });
}

class _QueuedSettingsStore extends SettingsStore {
  SettingsData data = SettingsData.defaults;
  bool failNextWrite = false;

  @override
  Future<SettingsData> load() async => data;

  @override
  Future<void> save(SettingsData value) async {
    await Future<void>.delayed(Duration.zero);
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Temporary storage failure');
    }
    data = value;
  }
}
