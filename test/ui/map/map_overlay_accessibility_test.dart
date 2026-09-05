import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/map_overlay/map_bottom_action_buttons.dart';
import 'package:munich_ways/ui/map/map_overlay/map_navigation_header_bar.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_route_comfort_summary.dart';
import 'package:munich_ways/ui/map/map_overlay/map_side_action_buttons.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';
import 'package:munich_ways/ui/theme.dart';

void main() {
  testWidgets('limits and right-aligns navigation panel in phone landscape',
      (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MapScreenViewModel(store: _MemorySettingsStore());
    const panelKey = ValueKey('landscape-navigation-panel');

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
                showSearch: false,
                navigationBar: const ColoredBox(
                  key: panelKey,
                  color: Colors.blue,
                  child: SizedBox(height: 100),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(panelKey));
    expect(rect.width, 360);
    expect(rect.right, 800);
    expect(tester.takeException(), isNull);
  });

  test('shortens repeated off-route voice announcements', () {
    expect(
      offRouteSpokenMessage(
        english: false,
        automaticRerouting: true,
        firstAnnouncement: true,
      ),
      'Route verlassen. Neuberechnung folgt.',
    );
    expect(
      offRouteSpokenMessage(
        english: false,
        automaticRerouting: true,
        firstAnnouncement: false,
      ),
      'Route verlassen.',
    );
    expect(
      offRouteSpokenMessage(
        english: false,
        automaticRerouting: false,
        firstAnnouncement: true,
      ),
      'Route verlassen.',
    );
    expect(
      offRouteSpokenMessage(
        english: false,
        automaticRerouting: true,
        firstAnnouncement: false,
        lastAutomaticAnnouncement: true,
      ),
      'Letzte automatische Neuberechnung in Kürze. Keine weiteren Ansagen '
      'außerhalb der Route.',
    );
  });

  testWidgets('left-side controls include the position button', (tester) async {
    final model = _LeftMapScreenViewModel();
    final bearing = ValueNotifier<double>(0);
    final idle = ValueNotifier<int>(0);
    addTearDown(bearing.dispose);
    addTearDown(idle.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MapSideActionButtons(
                model: model,
                mapController: null,
                mapBearingDegrees: bearing,
                compassIdleTick: idle,
                onNorthUp: () async {},
                queryMapBearingDegrees: () async => 0,
                onPressLocation: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final position = find.byIcon(Icons.location_searching);
    expect(position, findsOneWidget);
    expect(tester.getCenter(position).dx, lessThan(100));
  });

  testWidgets('zoom button has an explicit label and a large tap target',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapOverlayButton(
              tooltip: 'Vergrößern',
              size: 40,
              tapTargetSize: 56,
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );

    final button = find.bySemanticsLabel('Vergrößern');
    expect(button, findsOneWidget);
    expect(tester.getSize(button), const Size.square(56));
  });

  testWidgets('small attribution circle keeps a 48 pixel tap target',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapOverlayButton(
              tooltip: 'Kartenquellen',
              size: 28,
              tapTargetSize: 48,
              onPressed: () {},
              child: const Text('©'),
            ),
          ),
        ),
      ),
    );

    final button = find.bySemanticsLabel('Kartenquellen');
    expect(tester.getSize(button), const Size.square(48));
    expect(tester.getSize(find.byType(InkWell)), const Size.square(28));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('route close button has an explicit label and large tap target',
      (tester) async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(null, MapRouteState.LOADING);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapNavigationHeaderBar(
            model: model,
            onRefreshRoute: () async {},
            onEditRoute: () {},
            onStartNavigation: () async {},
            onToggleVoiceGuidance: () {},
            onEndRoute: () {},
          ),
        ),
      ),
    );

    final button = find.bySemanticsLabel('Route beenden');
    expect(button, findsOneWidget);
    expect(tester.getSize(button), const Size.square(56));
  });

  testWidgets('destination arrival offers a hero finish action',
      (tester) async {
    var ended = false;
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(const [], 4200, 1200),
        MapRouteState.SHOWN,
      )
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapNavigationHeaderBar(
            model: model,
            nextManeuver: const VoiceGuidanceDisplay(
              text: 'Ziel erreicht',
              type: 'arrive',
              isFinalDestination: true,
            ),
            onRefreshRoute: () async {},
            onEditRoute: () {},
            onStartNavigation: () async {},
            onToggleVoiceGuidance: () {},
            onEndRoute: () => ended = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.sports_score), findsOneWidget);
    expect(
      tester.getSize(find.bySemanticsLabel('Beenden')).width,
      greaterThan(180),
    );
    final finishButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Beenden'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(
      finishButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.munichWaysOrange,
    );
    expect(
      finishButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.heroForeground,
    );

    await tester.tap(find.bySemanticsLabel('Beenden'));
    expect(ended, isTrue);
  });

  testWidgets('route edit and refresh buttons have explicit labels',
      (tester) async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(const [], 4200, 1200),
        MapRouteState.SHOWN,
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapNavigationHeaderBar(
            model: model,
            onRefreshRoute: () async {},
            onEditRoute: () {},
            onStartNavigation: () async {},
            onToggleVoiceGuidance: () {},
            onEndRoute: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Route bearbeiten'), findsOneWidget);
    expect(find.bySemanticsLabel('Route neu berechnen'), findsOneWidget);
  });

  testWidgets('start window offers an accessible one-trip direct choice',
      (tester) async {
    var toggles = 0;
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(const [], 4200, 1200),
        MapRouteState.SHOWN,
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: MapNavigationHeaderBar(
              model: model,
              onRefreshRoute: () async {},
              onEditRoute: () {},
              onStartNavigation: () async {},
              onToggleTemporaryShortestRoute: () async => toggles++,
              onToggleVoiceGuidance: () {},
              onEndRoute: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Starten'), findsOneWidget);
    expect(find.text('Direkte Route'), findsNothing);
    expect(find.text('Kürzer, aber möglicherweise stressiger'), findsNothing);
    final direct = find.bySemanticsLabel('Direkte Route auswählen');
    expect(direct, findsOneWidget);
    expect(tester.getSize(direct).height, greaterThanOrEqualTo(48));
    expect(find.byIcon(Icons.straighten), findsOneWidget);
    final directIconButton = tester.widget<IconButton>(
      find.descendant(of: direct, matching: find.byType(IconButton)),
    );
    expect(directIconButton.style?.side, isNull);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(
      tester.getCenter(find.bySemanticsLabel('Route beenden')).dx,
      lessThan(tester.getCenter(direct).dx),
    );
    expect(
      tester.getCenter(direct).dx,
      lessThan(tester.getCenter(find.bySemanticsLabel('Route bearbeiten')).dx),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(direct);
    await tester.pumpAndSettle();
    expect(find.text('Direkte Route'), findsOneWidget);
    expect(
      find.textContaining('keine Abbiegeansagen'),
      findsOneWidget,
    );
    expect(find.textContaining('auf die Karte achten'), findsOneWidget);
    expect(find.text('Bei Standard bleiben'), findsOneWidget);
    expect(find.text('Direkte Route berechnen'), findsOneWidget);
    await tester.tap(find.text('Direkte Route berechnen'));
    await tester.pumpAndSettle();
    expect(toggles, 1);

    final activeModel = MapScreenViewModel(store: _MemorySettingsStore());
    await activeModel.setTemporaryShortestRouteEnabled(true);
    activeModel
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(const [], 4200, 1200),
        MapRouteState.SHOWN,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapNavigationHeaderBar(
            model: activeModel,
            onRefreshRoute: () async {},
            onEditRoute: () {},
            onStartNavigation: () async {},
            onToggleTemporaryShortestRoute: () async {},
            onToggleVoiceGuidance: () {},
            onEndRoute: () {},
          ),
        ),
      ),
    );

    final activeDirect = find.bySemanticsLabel('Standardroute auswählen');
    expect(activeDirect, findsOneWidget);
    expect(
      find.descendant(of: activeDirect, matching: find.byIcon(Icons.route)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.straighten), findsNothing);
    await tester.tap(activeDirect);
    await tester.pumpAndSettle();
    expect(find.text('Direkte Route beibehalten'), findsOneWidget);
    expect(find.text('Standard berechnen'), findsOneWidget);
  });

  testWidgets('passive follow-map hint has no button-like map icon',
      (tester) async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(const [], 4200, 1200),
        MapRouteState.SHOWN,
      )
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapNavigationHeaderBar(
            model: model,
            nextManeuver: const VoiceGuidanceDisplay(
              text: 'Karte beachten',
              type: 'map',
            ),
            onRefreshRoute: () async {},
            onEditRoute: () {},
            onStartNavigation: () async {},
            onToggleVoiceGuidance: () {},
            onEndRoute: () {},
          ),
        ),
      ),
    );

    expect(find.text('Karte beachten'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsNothing);
  });

  testWidgets('navigation actions use large evenly spaced tap targets',
      (tester) async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(const [], 4200, 1200),
        MapRouteState.SHOWN,
      )
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
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
    );

    final edit = find.bySemanticsLabel('Route bearbeiten');
    final voice = find.bySemanticsLabel('Sprachansagen einschalten');
    final refresh = find.bySemanticsLabel('Route neu berechnen');
    expect(tester.getSize(edit), const Size.square(52));
    expect(tester.getSize(voice), const Size.square(52));
    expect(tester.getSize(refresh), const Size(68, 52));
    expect(
      tester.getCenter(voice).dx - tester.getCenter(edit).dx,
      closeTo(62, 0.1),
    );
    expect(
      tester.getCenter(refresh).dx - tester.getCenter(voice).dx,
      closeTo(76, 0.1),
    );
  });

  testWidgets('interrupted navigation offers a prominent resume action',
      (tester) async {
    var resumed = false;
    var infoShown = false;
    var settingsShown = false;
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(const [], 4200, 1200),
        MapRouteState.SHOWN,
      )
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    model.onUserStoppedFollowingLocation();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: MapNavigationHeaderBar(
              model: model,
              nextManeuver: const VoiceGuidanceDisplay(
                text: 'In 100 m rechts abbiegen',
                type: 'turn',
                modifier: 'right',
              ),
              onRefreshRoute: () async => resumed = true,
              onEditRoute: () {},
              onStartNavigation: () async {},
              onToggleVoiceGuidance: () {},
              onEndRoute: () {},
              onShowInfo: () => infoShown = true,
              onShowSettings: () => settingsShown = true,
            ),
          ),
        ),
      ),
    );

    final resume = find.bySemanticsLabel('Fortsetzen');
    expect(resume, findsOneWidget);
    expect(find.text('Fortsetzen'), findsOneWidget);
    expect(find.text('In 100 m rechts abbiegen'), findsNothing);
    final info = find.byTooltip('Info');
    final settings = find.byTooltip('Einstellungen');
    expect(info, findsOneWidget);
    expect(settings, findsOneWidget);
    for (final action in [info, settings]) {
      final iconButton = tester.widget<IconButton>(
        find.ancestor(of: action, matching: find.byType(IconButton)),
      );
      expect(iconButton.style?.side, isNull);
      expect(
        iconButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        Colors.white70,
      );
    }
    expect(tester.getSize(resume), const Size(68, 52));
    final button = tester.widget<IconButton>(
      find.descendant(
        of: resume,
        matching: find.byType(IconButton),
      ),
    );
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.munichWaysOrange,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(resume);
    expect(resumed, isTrue);
    await tester.tap(info);
    await tester.tap(settings);
    expect(infoShown, isTrue);
    expect(settingsShown, isTrue);
  });

  testWidgets('start controls remain visible with large system text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(const [], 4200, 1200),
        MapRouteState.SHOWN,
      );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: MapNavigationHeaderBar(
            model: model,
            onRefreshRoute: () async {},
            onEditRoute: () {},
            onStartNavigation: () async {},
            onToggleTemporaryShortestRoute: () async {},
            onToggleVoiceGuidance: () {},
            onEndRoute: () {},
          ),
        ),
      ),
    );

    expect(find.text('Starten'), findsOneWidget);
    final directRoute = find.bySemanticsLabel('Direkte Route auswählen');
    expect(directRoute, findsOneWidget);
    expect(
      tester.getCenter(directRoute).dy,
      greaterThan(tester.getCenter(find.text('Starten')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('route stats share a full row above the action buttons',
      (tester) async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(const [], 4200, 1200),
        MapRouteState.SHOWN,
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
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
    );

    final distance = find.text('4,2 km');
    final duration = find.text('20 Min');
    final close = find.byIcon(Icons.close);
    expect(tester.getCenter(distance).dy, tester.getCenter(duration).dy);
    expect(
      tester.getBottomLeft(distance).dy,
      lessThanOrEqualTo(tester.getTopLeft(close).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows backend comfort distribution before navigation starts',
      (tester) async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(
          const [],
          4200,
          1200,
          comfort: const RouteComfort(
            index: 78,
            coverage: 82,
            sufficientCoverage: true,
            distribution: RouteComfortDistribution(
              black: 2,
              red: 7,
              yellow: 18,
              green: 68,
              unrated: 5,
            ),
          ),
        ),
        MapRouteState.SHOWN,
      );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: MapRouteComfortSummary(model: model),
          ),
        ),
      ),
    );

    expect(find.text('Radl-Komfort'), findsOneWidget);
    expect(find.text('78/100'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Routenbewertung: 2 Prozent sehr stressig, 7 Prozent stressig, '
        '18 Prozent durchschnittlich, 68 Prozent komfortabel, '
        '5 Prozent nicht bewertet',
      ),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Erläuterung zum Radl-Komfort-Index'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('comfort-segment-green'))).width,
      greaterThan(
        tester
            .getSize(find.byKey(const ValueKey('comfort-segment-yellow')))
            .width,
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Erläuterung zum Radl-Komfort-Index'));
    await tester.pumpAndSettle();
    expect(find.text('Radl-Komfort-Index'), findsOneWidget);
    expect(find.text('Farben dieser Route'), findsOneWidget);
    expect(find.text('Sehr stressig'), findsOneWidget);
    expect(find.text('Stressig'), findsOneWidget);
    expect(find.text('Durchschnittlich'), findsOneWidget);
    expect(find.text('Komfortabel'), findsOneWidget);
    expect(find.text('Nicht bewertet'), findsOneWidget);
    expect(find.text('5 %'), findsOneWidget);
    expect(find.textContaining('Braune, nicht bewertete'), findsOneWidget);
    expect(find.text('Weitere Erläuterungen'), findsOneWidget);
  });

  testWidgets('shows no index when coverage is insufficient and hides on start',
      (tester) async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(
          const [],
          4200,
          1200,
          comfort: const RouteComfort(
            index: null,
            coverage: 69,
            sufficientCoverage: false,
            distribution: RouteComfortDistribution(
              black: 2,
              red: 7,
              yellow: 18,
              green: 42,
              unrated: 31,
            ),
          ),
        ),
        MapRouteState.SHOWN,
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapRouteComfortSummary(model: model),
        ),
      ),
    );

    expect(find.text('69 % bewertet'), findsOneWidget);
    expect(find.textContaining('/100'), findsNothing);
    expect(tester.takeException(), isNull);

    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapRouteComfortSummary(model: model),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('route-comfort-summary')), findsNothing);
  });

  testWidgets('comfort summary stays clear of the location control',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bearing = ValueNotifier<double>(0);
    final idle = ValueNotifier<int>(0);
    addTearDown(bearing.dispose);
    addTearDown(idle.dispose);
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(
          const [],
          4200,
          1200,
          comfort: const RouteComfort(
            index: 78,
            coverage: 82,
            sufficientCoverage: true,
            distribution: RouteComfortDistribution(
              black: 2,
              red: 7,
              yellow: 18,
              green: 68,
              unrated: 5,
            ),
          ),
        ),
        MapRouteState.SHOWN,
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MapSideActionButtons(
                model: model,
                mapController: null,
                mapBearingDegrees: bearing,
                compassIdleTick: idle,
                additionalBottomOffset:
                    128 + routeComfortSummaryAdditionalBottomOffset,
                onNorthUp: () async {},
                queryMapBearingDegrees: () async => 0,
                onPressLocation: () {},
              ),
              MapBottomActionButtons(
                model: model,
                showSearch: false,
                searchCenterProvider: () => null,
                onPlanRoute: () async {},
                onSelectOnMap: () {},
                onPressLocation: () {},
                navigationBar: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MapRouteComfortSummary(model: model),
                    MapNavigationHeaderBar(
                      model: model,
                      onRefreshRoute: () async {},
                      onEditRoute: () {},
                      onStartNavigation: () async {},
                      onToggleVoiceGuidance: () {},
                      onEndRoute: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final location = find.bySemanticsLabel('Standort');
    final summary = find.byKey(const ValueKey('route-comfort-summary'));
    expect(
        tester.getRect(location).bottom, lessThan(tester.getRect(summary).top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a positive map hint when no directions are available',
      (tester) async {
    final model = MapScreenViewModel(store: _MemorySettingsStore())
      ..destination = Place('Ziel', const LatLng(48.15, 11.6))
      ..route = MapRoute(
        CycleRoute(
          const [],
          4200,
          1200,
          supportsVoiceGuidance: false,
        ),
        MapRouteState.SHOWN,
      )
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapNavigationHeaderBar(
            model: model,
            onRefreshRoute: () async {},
            onEditRoute: () {},
            onStartNavigation: () async {},
            onToggleVoiceGuidance: () {},
            onEndRoute: () {},
          ),
        ),
      ),
    );

    // This is a passive status hint, not an action. Keep it text-only so it
    // cannot be mistaken for one of the tappable map controls.
    expect(find.byIcon(Icons.map_outlined), findsNothing);
    expect(find.text('Route auf Karte folgen'), findsOneWidget);
  });
}

class _MemorySettingsStore extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

class _LeftMapScreenViewModel extends MapScreenViewModel {
  _LeftMapScreenViewModel() : super(store: _MemorySettingsStore());

  @override
  MapSidePanelEdge get sidePanelEdge => MapSidePanelEdge.left;
}
