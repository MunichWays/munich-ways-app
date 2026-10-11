import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/map_overlay/map_navigation_header_bar.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/navigation_remaining.dart';

class _Settings extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

Future<void> _pumpHeader(WidgetTester tester, MapScreenViewModel model,
    NavigationRemaining? remaining,
    {bool english = false,
    double textScale = 1,
    bool collapsed = false}) async {
  await tester.pumpWidget(MaterialApp(
    locale: Locale(english ? 'en' : 'de'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
          size: const Size(320, 800), textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SizedBox(
          width: 320,
          child: MapNavigationHeaderBar(
            model: model,
            remaining: remaining,
            collapsed: collapsed,
            onToggleCollapsed: () {},
            onRefreshRoute: () async {},
            onEditRoute: () {},
            onStartNavigation: () async {},
            onToggleVoiceGuidance: () {},
            onPauseNavigation: () {},
            onEndRoute: () {},
            onFinishRoute: () {},
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  late MapScreenViewModel model;
  late CycleRoute route;
  setUp(() {
    route = CycleRoute(
        const [LatLng(48.14, 11.57), LatLng(48.15, 11.57)], 4200, 1200);
    model = MapScreenViewModel(store: _Settings())
      ..destination = Place('Ziel', route.points.last)
      ..route = MapRoute(route, MapRouteState.SHOWN)
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
  });
  tearDown(() => model.dispose());

  testWidgets('planning keeps total values even if a sample is supplied',
      (tester) async {
    await _pumpHeader(tester, model, NavigationRemaining.estimate(route, 0.5));
    expect(find.text('4,2 km'), findsOneWidget);
    expect(find.text('20 Min'), findsOneWidget);
    expect(find.text('2,1 km'), findsNothing);
  });

  testWidgets(
      'navigation shows remaining values and explicit estimate semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await model.startNavigation();
      await _pumpHeader(
          tester, model, NavigationRemaining.estimate(route, 0.5));
      expect(find.text('2,1 km'), findsOneWidget);
      expect(find.byIcon(Icons.sports_score), findsWidgets);
      expect(find.byIcon(Icons.route), findsNothing);
      expect(find.text('≈ 10 Min'), findsOneWidget);
      expect(find.bySemanticsLabel('Reststrecke: 2,1 km'), findsOneWidget);
      expect(find.bySemanticsLabel('Geschätzte Restfahrzeit: 10 Minuten'),
          findsOneWidget);
      expect(find.text('4,2 km'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'pause retains the sample; unavailable and replacement discard it',
      (tester) async {
    await model.startNavigation();
    final sample = NavigationRemaining.estimate(route, 0.5);
    await _pumpHeader(tester, model, sample);
    model.onUserStoppedFollowingLocation();
    await _pumpHeader(tester, model, sample);
    expect(find.text('2,1 km'), findsOneWidget);
    expect(find.text('≈ 10 Min'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await _pumpHeader(tester, model, null);
    expect(find.text('— km'), findsOneWidget);
    model.route =
        MapRoute(CycleRoute(route.points, 4200, 1200), MapRouteState.SHOWN);
    await _pumpHeader(tester, model, sample);
    expect(find.text('— km'), findsOneWidget);
    await _pumpHeader(
        tester, model, NavigationRemaining.estimate(model.route.route!, 0.25));
    expect(find.text('1,1 km'), findsOneWidget);
    expect(find.text('≈ 5 Min'), findsOneWidget);
  });

  testWidgets('large text and collapsed English navigation keep stats usable',
      (tester) async {
    await model.startNavigation();
    await _pumpHeader(tester, model, NavigationRemaining.estimate(route, 0.5),
        english: true, textScale: 2);
    expect(find.text('2.1 km'), findsOneWidget);
    expect(find.text('≈ 10 min'), findsOneWidget);
    await _pumpHeader(tester, model, NavigationRemaining.estimate(route, 0.5),
        english: true, textScale: 2, collapsed: true);
    expect(find.text('2.1 km'), findsNothing);
    expect(find.text('≈ 10 min'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('access is separate from remaining distance to route end',
      (tester) async {
    route.destinationConnector = const [
      LatLng(48.15, 11.57),
      LatLng(48.151, 11.57)
    ];
    await model.startNavigation();
    final semantics = tester.ensureSemantics();
    try {
      await _pumpHeader(
          tester, model, NavigationRemaining.estimate(route, 0.5));
      expect(find.text('2,1 km'), findsOneWidget);
      expect(find.text('Zielzugang: 111 m'), findsOneWidget);
      expect(find.bySemanticsLabel('Reststrecke bis Routenende: 2,1 km'),
          findsOneWidget);
      await _pumpHeader(tester, model, NavigationRemaining.estimate(route, 0.5),
          english: true, textScale: 2);
      expect(find.text('Access to destination: 111 m'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('loading shows the existing status instead of stale estimates',
      (tester) async {
    await model.startNavigation();
    final sample = NavigationRemaining.estimate(route, 0.5);
    model.route.state = MapRouteState.LOADING;
    await _pumpHeader(tester, model, sample);
    expect(find.text('Route wird berechnet...'), findsOneWidget);
    expect(find.text('2,1 km'), findsNothing);
  });
}
