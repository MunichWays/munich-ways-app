import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/map_overlay/map_navigation_header_bar.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_side_action_buttons.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';
import 'package:munich_ways/ui/theme.dart';

void main() {
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
    expect(tester.getSize(refresh), const Size.square(52));
    expect(
      tester.getCenter(voice).dx - tester.getCenter(edit).dx,
      closeTo(62, 0.1),
    );
    expect(
      tester.getCenter(refresh).dx - tester.getCenter(voice).dx,
      closeTo(62, 0.1),
    );
  });

  testWidgets('interrupted navigation offers a prominent resume action',
      (tester) async {
    var resumed = false;
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
              onRefreshRoute: () async => resumed = true,
              onEditRoute: () {},
              onStartNavigation: () async {},
              onToggleVoiceGuidance: () {},
              onEndRoute: () {},
            ),
          ),
        ),
      ),
    );

    final resume = find.bySemanticsLabel('Fortsetzen');
    expect(resume, findsOneWidget);
    expect(find.text('Fortsetzen'), findsNothing);
    expect(tester.getSize(resume), const Size.square(52));
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

    await tester.tap(resume);
    expect(resumed, isTrue);
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

    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.text('Auf Karte achten'), findsOneWidget);
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
