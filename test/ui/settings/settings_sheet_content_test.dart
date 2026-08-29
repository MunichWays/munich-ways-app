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
import 'package:munich_ways/ui/app_theme_controller.dart';
import 'package:munich_ways/ui/energy_saving_controller.dart';
import 'package:munich_ways/ui/theme.dart';
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
    final startButton = tester.widget<FilledButton>(
      find.ancestor(
        of: start,
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(
      startButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.munichWaysOrange,
    );
    expect(
      startButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.heroForeground,
    );
    expect(
        tester.getSize(find.ancestor(
          of: start,
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        )),
        const Size(180, 48));
    final startTargetSize = tester.getSize(find.bySemanticsLabel('Starten'));
    expect(startTargetSize.width, greaterThan(180));
    expect(startTargetSize.height, 56);
    expect(
        tester.getTopLeft(start).dy, greaterThan(tester.getTopLeft(stats).dy));
    expect(
      tester.getCenter(refresh).dx,
      greaterThan(tester.getCenter(stats).dx),
    );
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
    final themeController = AppThemeController(store: store);
    final energySavingController = EnergySavingController(store: store);
    addTearDown(themeController.dispose);
    addTearDown(energySavingController.dispose);
    await localeController.load();
    await themeController.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: localeController),
          ChangeNotifierProvider.value(value: themeController),
          ChangeNotifierProvider.value(value: energySavingController),
        ],
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

    final routeWish = find.text('Routenwunsch');
    final zoom = find.text('Zoom-Buttons');
    final appearance = find.text('Darstellung');
    final mapControls = find.text('Karten-Buttons');
    final more = find.text('Weitere Einstellungen');
    expect(routeWish, findsOneWidget);
    final primaryRouteSetting = tester.widget<Material>(
      find.byKey(const ValueKey('primary-route-recommendation-setting')),
    );
    expect(
      primaryRouteSetting.color,
      Theme.of(tester.element(routeWish))
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.55),
    );
    final secondarySwitches = tester.widgetList<Switch>(find.byType(Switch));
    expect(
      secondarySwitches
          .where(
              (control) => control.activeTrackColor == AppColors.munichWaysBlue)
          .length,
      2,
    );
    expect(find.text('Kürzeste Strecke'), findsNothing);
    expect(zoom, findsOneWidget);
    expect(appearance, findsOneWidget);
    expect(mapControls, findsNothing);
    expect(more, findsOneWidget);
    expect(
      tester.getTopLeft(routeWish).dy,
      lessThan(tester.getTopLeft(zoom).dy),
    );
    expect(
      tester.getTopLeft(zoom).dy,
      lessThan(tester.getTopLeft(appearance).dy),
    );
    expect(
      tester.getTopLeft(appearance).dy,
      lessThan(tester.getTopLeft(more).dy),
    );

    expect(find.text('Routenberechnung'), findsNothing);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Energie sparen'), findsOneWidget);
    expect(mapControls, findsOneWidget);
    expect(find.text('Routenwunsch'), findsOneWidget);
    expect(find.text('Routenberechnung'), findsNothing);
    final language = find.text('Sprache');
    final bikeNetwork = find.text('Fahrradnetz auswählen');
    final reloadNetwork = find.text('Radnetz neu laden');
    expect(language, findsOneWidget);
    expect(bikeNetwork, findsOneWidget);
    expect(reloadNetwork, findsOneWidget);
    expect(
      tester.getTopLeft(mapControls).dy,
      lessThan(tester.getTopLeft(language).dy),
    );
    expect(
      tester.getTopLeft(language).dy,
      lessThan(tester.getTopLeft(bikeNetwork).dy),
    );
    expect(
      tester.getTopLeft(bikeNetwork).dy,
      lessThan(tester.getTopLeft(reloadNetwork).dy),
    );
    expect(
      find.text('RadlNavi (Oberbayern) / BRouter (weltweit)'),
      findsNothing,
    );

    await tester.tap(routeWish);
    await tester.pumpAndSettle();
    Finder recommendation(String label) => find.descendant(
          of: find.byType(RadioListTile<RouteRecommendation>),
          matching: find.text(label),
        );
    final standardRecommendation = recommendation('Standard (empfohlen)');
    expect(standardRecommendation, findsOneWidget);
    expect(recommendation('Trekking'), findsOneWidget);
    expect(recommendation('Rennrad (schnell)'), findsOneWidget);
    expect(recommendation('Allein im Dunkeln (Beta)'), findsOneWidget);
    expect(recommendation('Bei Hitze (Beta)'), findsOneWidget);
    expect(recommendation('Bei Schnee und Matsch (Beta)'), findsOneWidget);

    final aloneAfterDark = recommendation('Allein im Dunkeln (Beta)');
    await tester.ensureVisible(aloneAfterDark);
    await tester.tap(aloneAfterDark);
    await tester.pump();
    expect(model.routeRecommendation, RouteRecommendation.aloneAfterDark);
    expect(model.routingMode, RoutingMode.bRouterEverywhere);
    expect(model.bRouterProfile, BRouterProfile.fastBike);

    await tester.tap(find.byTooltip('Info: Allein im Dunkeln (Beta)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('besonders Frauen'), findsOneWidget);
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    final hotWeather = recommendation('Bei Hitze (Beta)');
    await tester.ensureVisible(hotWeather);
    await tester.tap(hotWeather);
    await tester.pump();
    expect(model.routeRecommendation, RouteRecommendation.hotWeather);
    expect(model.routingMode, RoutingMode.automatic);
    expect(model.bRouterProfile, BRouterProfile.trekking);

    final snowAndMud = recommendation('Bei Schnee und Matsch (Beta)');
    await tester.ensureVisible(snowAndMud);
    await tester.tap(snowAndMud);
    await tester.pump();
    expect(model.routeRecommendation, RouteRecommendation.snowAndMud);
    expect(model.routingMode, RoutingMode.bRouterEverywhere);
    expect(model.bRouterProfile, BRouterProfile.fastBike);

    final shortestRecommendation = recommendation('Kürzeste Strecke');
    await tester.ensureVisible(shortestRecommendation);
    await tester.tap(shortestRecommendation);
    await tester.pump();
    expect(model.routeRecommendation, RouteRecommendation.shortest);
    expect(model.shortestRouteEnabled, isTrue);

    await tester.ensureVisible(standardRecommendation);
    await tester.tap(standardRecommendation);
    await tester.pump();
    expect(model.routeRecommendation, RouteRecommendation.standard);
    expect(model.routingMode, RoutingMode.automatic);
    expect(model.bRouterProfile, BRouterProfile.trekking);
    expect(model.shortestRouteEnabled, isFalse);

    final trekking = recommendation('Trekking');
    await tester.ensureVisible(trekking);
    await tester.tap(trekking);
    await tester.pump();
    expect(model.routeRecommendation, RouteRecommendation.trekking);
    expect(model.routingMode, RoutingMode.bRouterEverywhere);
    expect(model.bRouterProfile, BRouterProfile.trekking);

    final roadBike = recommendation('Rennrad (schnell)');
    await tester.ensureVisible(roadBike);
    await tester.tap(roadBike);
    await tester.pump();
    expect(model.routeRecommendation, RouteRecommendation.roadBike);
    expect(model.routingMode, RoutingMode.bRouterEverywhere);
    expect(model.bRouterProfile, BRouterProfile.fastBike);

    final routeRecommendationInfo = find.byTooltip('Info: Routenwunsch');
    await Scrollable.ensureVisible(
      routeRecommendationInfo.evaluate().single,
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(routeRecommendationInfo);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Standard sucht möglichst stressarme Fahrradrouten'),
      findsOneWidget,
    );
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();
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

  @override
  Future<void> saveRouteRecommendation(
    RouteRecommendation? recommendation,
  ) async {
    data = data.copyWith(
      routeRecommendation: recommendation,
      clearRouteRecommendation: recommendation == null,
    );
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
