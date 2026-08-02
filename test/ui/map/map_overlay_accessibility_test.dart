import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/map_overlay/map_navigation_header_bar.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_button.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

void main() {
  testWidgets('zoom button has an explicit label and a large tap target',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapOverlayButton(
              tooltip: 'Vergrößern',
              size: 56,
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
}

class _MemorySettingsStore extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}
