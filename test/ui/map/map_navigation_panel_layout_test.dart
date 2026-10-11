import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/map_overlay/map_bottom_action_buttons.dart';
import 'package:munich_ways/ui/map/map_overlay/map_compass_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:munich_ways/ui/map/map_overlay/map_side_action_buttons.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

class _Settings extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;

  @override
  Future<void> saveMapSettings(
      {required bool showZoomButtons,
      required String sidePanelEdgeName}) async {}
}

void main() {
  testWidgets('compass stays above a growing and folding navigation panel',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MapScreenViewModel(store: _Settings())
      ..destination = Place('Ziel', const LatLng(48.15, 11.57))
      ..route = MapRoute(
          CycleRoute(
              const [LatLng(48.14, 11.57), LatLng(48.15, 11.57)], 1000, 600),
          MapRouteState.SHOWN)
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    addTearDown(model.dispose);
    final bearing = ValueNotifier<double>(30);
    final idle = ValueNotifier<int>(0);
    addTearDown(bearing.dispose);
    addTearDown(idle.dispose);
    var panelHeight = 180.0;
    var measuredHeight = 0.0;
    var measurements = 0;
    late StateSetter rebuild;
    const panelKey = ValueKey('navigation-panel');
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return Stack(children: [
          MapSideActionButtons(
            model: model,
            mapController: null,
            mapBearingDegrees: bearing,
            compassIdleTick: idle,
            additionalBottomOffset:
                MediaQuery.orientationOf(context) == Orientation.landscape
                    ? 80
                    : navigationPanelSideControlsOffset(measuredHeight),
            onNorthUp: () async {},
            queryMapBearingDegrees: () async => 30,
            onPressLocation: () {},
          ),
          MapBottomActionButtons(
            model: model,
            showSearch: false,
            searchCenterProvider: () => null,
            onPlanRoute: () async {},
            onSelectOnMap: () {},
            onPressLocation: () async {},
            navigationBar: SizedBox(key: panelKey, height: panelHeight),
            onNavigationBarHeightChanged: (height) {
              measurements++;
              setState(() => measuredHeight = height);
            },
          ),
        ]);
      })),
    ));
    await tester.pumpAndSettle();
    for (final height in [180.0, 260.0, 120.0, 300.0]) {
      rebuild(() => panelHeight = height);
      await tester.pumpAndSettle();
      expect(measuredHeight, height);
      final compass = tester.getRect(find.byType(MapCompassOverlayButton));
      final panel = tester.getRect(find.byKey(panelKey));
      expect(compass.bottom, lessThan(panel.top));
      expect(compass.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
    }
    final count = measurements;
    rebuild(() {});
    await tester.pumpAndSettle();
    expect(measurements, count);

    tester.view.physicalSize = const Size(640, 360);
    model.setShowZoomButtons(false);
    for (final side in MapSidePanelEdge.values) {
      model.setSidePanelEdge(side);
      rebuild(() => panelHeight = 160);
      await tester.pumpAndSettle();
      final compass = tester.getRect(find.byType(MapCompassOverlayButton));
      final panel = tester.getRect(find.byKey(panelKey));
      expect(compass.overlaps(panel), isFalse);
      expect(compass.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
    }
  });
}
