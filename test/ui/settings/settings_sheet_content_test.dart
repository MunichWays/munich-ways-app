import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/localization/app_locale_controller.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';
import 'package:munich_ways/routing/routing_service.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/map_overlay/map_bottom_action_buttons.dart';
import 'package:munich_ways/ui/map/map_overlay/map_navigation_header_bar.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/settings/settings_sheet_content.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('places Start below route stats and keeps refresh on the right',
      (tester) async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(
          const [
            LatLng(48.14, 11.5),
            LatLng(48.15, 11.6),
          ],
          4200,
          1200,
        ),
        MapRouteState.SHOWN,
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: MapNavigationHeaderBar(
                model: model,
                onRefreshRoute: () async {},
                onEditRoute: () {},
                onStartNavigation: () async {},
                onToggleVoiceGuidance: () {},
                onEndRoute: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final stats = find.text('4,2 km');
    final start = find.text('Starten');
    final refresh = find.byIcon(Icons.refresh);
    expect(
        tester.getTopLeft(start).dy, greaterThan(tester.getTopLeft(stats).dy));
    expect(
      tester.getCenter(refresh).dx,
      greaterThan(tester.getCenter(stats).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups Settings directly left of Info', (tester) async {
    final model = MapScreenViewModel(store: _MemorySettingsStore());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ListenableBuilder(
                listenable: model,
                builder: (context, _) => MapBottomActionButtons(
                  model: model,
                  searchCenterProvider: () => null,
                  onPlanRoute: () async {},
                  onSelectOnMap: () {},
                  onPressLocation: () {},
                  showSearch: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    model.setSidePanelEdge(MapSidePanelEdge.left);
    await tester.pump();

    final trackingX =
        tester.getCenter(find.byIcon(Icons.location_searching)).dx;
    final settingsX = tester.getCenter(find.byIcon(Icons.settings)).dx;
    final infoX = tester.getCenter(find.byIcon(Icons.info_outline)).dx;
    expect(trackingX, lessThan(settingsX));
    expect(settingsX, lessThan(infoX));
    expect(infoX - settingsX, lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a persistent network reload action after initial failure',
      (tester) async {
    var reloadPressed = false;
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..initialRatingsLoadFailed = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MapBottomActionButtons(
                model: model,
                searchCenterProvider: () => null,
                onPlanRoute: () async {},
                onSelectOnMap: () {},
                onPressLocation: () {},
                onReloadNetwork: () async {
                  reloadPressed = true;
                },
                showSearch: false,
              ),
            ],
          ),
        ),
      ),
    );

    final reload = find.text('Radnetz neu laden');
    expect(reload, findsOneWidget);
    await tester.tap(reload);
    expect(reloadPressed, isTrue);
  });

  testWidgets('selects routing mode and BRouter profile and shows info',
      (tester) async {
    final store = _MemorySettingsStore();
    final model = MapScreenViewModel(
      store: store,
      routingService: RoutingService(
        radlNavi: _UnusedProvider(),
        bRouter: _UnusedProvider(),
        radlNaviCoverage: _AlwaysCovered(),
      ),
    );
    final localeController = AppLocaleController(store: store);
    await localeController.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: localeController,
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsSheetContent(
                model: model,
                onReloadRadnetz: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Routenplanung'), findsOneWidget);
    expect(find.text('Automatisch · Trekking (Standard)'), findsOneWidget);
    expect(
      find.text('RadlNavi (Oberbayern) / BRouter (weltweit)'),
      findsNothing,
    );

    await tester.tap(find.text('Routenplanung'));
    await tester.pumpAndSettle();
    expect(
      find.text('RadlNavi (Oberbayern) / BRouter (weltweit)'),
      findsOneWidget,
    );

    await tester.tap(find.text('BRouter überall'));
    await tester.pump();
    expect(model.routingMode, RoutingMode.bRouterEverywhere);
    expect(store.data.routingMode, RoutingMode.bRouterEverywhere);

    await tester.ensureVisible(find.text('Rennrad (schnell)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rennrad (schnell)'));
    await tester.pump();
    expect(model.bRouterProfile, BRouterProfile.fastBike);
    expect(store.data.bRouterProfile, BRouterProfile.fastBike);
    expect(find.text('BRouter überall · Rennrad (schnell)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Automatisch nutzt RadlNavi'),
      findsOneWidget,
    );
  });
}

class _MemorySettingsStore extends SettingsStore {
  SettingsData data = SettingsData.defaults;

  @override
  Future<SettingsData> load() async => data;

  @override
  Future<void> saveRoutingMode(RoutingMode routingMode) async {
    data = data.copyWith(routingMode: routingMode);
  }

  @override
  Future<void> saveBRouterProfile(BRouterProfile profile) async {
    data = data.copyWith(bRouterProfile: profile);
  }
}

class _AlwaysCovered implements RoutingCoverage {
  @override
  Future<bool> contains(LatLng point) async => true;
}

class _UnusedProvider implements RoutingProvider {
  @override
  Future<CycleRoute> route(
    List<LatLng> coordinates, {
    BRouterProfile profile = BRouterProfile.trekking,
  }) async =>
      throw StateError('Routing is not expected in this widget test.');
}
