import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/routing/routing_preferences.dart';

void main() {
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
