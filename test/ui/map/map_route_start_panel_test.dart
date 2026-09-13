import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/map_overlay/map_navigation_header_bar.dart';
import 'package:munich_ways/ui/map/map_overlay/map_route_start_panel.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

const _comfort = RouteComfort(
    index: 77,
    coverage: 80,
    sufficientCoverage: true,
    distribution: RouteComfortDistribution(
        black: 0, red: 10, yellow: 20, green: 50, unrated: 20));

void main() {
  for (final textScale in [1.0, 2.0])
    testWidgets(
        'fold by grip or drag, retain folding across metadata, and start navigation ($textScale)',
        (tester) async {
      final model = MapScreenViewModel(store: _Settings())
        ..destination = Place('Ziel', const LatLng(48.2, 11.6))
        ..route = MapRoute(CycleRoute(const [], 4200, 1200, comfort: _comfort),
            MapRouteState.SHOWN);
      addTearDown(model.dispose);
      var starts = 0;
      Widget app() => MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: Scaffold(
              body: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                      width: 320,
                      child: ListenableBuilder(
                          listenable: model,
                          builder: (context, child) => MapRouteStartPanel(
                              model: model,
                              builder: (collapsed, toggle) =>
                                  MapNavigationHeaderBar(
                                      model: model,
                                      collapsed: collapsed,
                                      onToggleCollapsed: toggle,
                                      onRefreshRoute: () async {},
                                      onEditRoute: () {},
                                      onToggleVoiceGuidance: () {},
                                      onEndRoute: () {},
                                      onStartNavigation: () async {
                                        starts++;
                                        model.locationState =
                                            LocationState.FOLLOW_AND_ROTATE_MAP;
                                        await model.startNavigation();
                                      })))))));
      await tester.pumpWidget(app());
      final handle = find.byKey(const ValueKey('route-panel-handle'));
      expect(
        find.descendant(
          of: handle,
          matching: find.byType(BottomSheetDragHandle),
        ),
        findsOneWidget,
      );
      expect(
          find.byKey(const ValueKey('route-comfort-summary')), findsOneWidget);
      final expanded = tester.getSize(find.byType(MapRouteStartPanel)).height;
      await tester.drag(handle, const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-comfort-summary')), findsNothing);
      expect(find.bySemanticsLabel('Route bearbeiten'), findsNothing);
      expect(find.text('Starten'), findsOneWidget);
      expect(tester.getSize(find.byType(MapRouteStartPanel)).height,
          lessThan(expanded));
      expect(starts, 0);
      // A parent rebuild such as a comfort update must not expand the panel.
      await tester.pumpWidget(app());
      expect(find.bySemanticsLabel('Route bearbeiten'), findsNothing);
      await tester.drag(handle, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Route bearbeiten'), findsOneWidget);
      await tester.drag(handle, const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Route bearbeiten'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Starten'));
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(model.navigationStarted, isTrue);
      expect(handle, findsOneWidget);
      expect(find.text('Starten'), findsNothing);
      expect(find.bySemanticsLabel('Route bearbeiten'), findsOneWidget);
      expect(find.bySemanticsLabel('Route beenden'), findsOneWidget);
      expect(find.bySemanticsLabel('Route neu berechnen'), findsOneWidget);
      expect(find.text('4,2 km'), findsNothing);
      final collapsedNavigationHeight =
          tester.getSize(find.byType(MapRouteStartPanel)).height;
      model.route = MapRoute(null, MapRouteState.LOADING);
      await tester.pumpWidget(app());
      expect(handle, findsOneWidget);
      expect(find.text('Route wird berechnet...'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      model.route = MapRoute(
        CycleRoute(const [], 4200, 1200, comfort: _comfort),
        MapRouteState.SHOWN,
      );
      await tester.pumpWidget(app());
      expect(find.text('4,2 km'), findsNothing);
      await tester.drag(handle, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(find.text('4,2 km'), findsOneWidget);
      expect(tester.getSize(find.byType(MapRouteStartPanel)).height,
          greaterThan(collapsedNavigationHeight));
      expect(tester.takeException(), isNull);
    });

  testWidgets('a new destination resets folding and loading cannot be hidden',
      (tester) async {
    final model = MapScreenViewModel(store: _Settings())
      ..destination = Place('Ziel', const LatLng(48.2, 11.6))
      ..route = MapRoute(CycleRoute(const [], 4200, 1200), MapRouteState.SHOWN);
    addTearDown(model.dispose);
    Widget app() => MaterialApp(
        home: Scaffold(
            body: MapRouteStartPanel(
                model: model,
                builder: (collapsed, toggle) =>
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(collapsed ? 'Collapsed' : 'Expanded'),
                      TextButton(onPressed: toggle, child: const Text('Toggle'))
                    ]))));
    await tester.pumpWidget(app());
    await tester.tap(find.text('Toggle'));
    await tester.pump();
    expect(find.text('Collapsed'), findsOneWidget);
    model.destination = Place('Neu', const LatLng(48.3, 11.7));
    await tester.pumpWidget(app());
    expect(find.text('Expanded'), findsOneWidget);
    await tester.tap(find.text('Toggle'));
    await tester.pump();
    model.route = MapRoute(null, MapRouteState.LOADING);
    await tester.pumpWidget(app());
    expect(find.text('Expanded'), findsOneWidget);
    expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
  });
}

class _Settings extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}
