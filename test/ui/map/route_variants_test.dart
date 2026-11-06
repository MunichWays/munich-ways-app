import 'dart:async';

import 'package:munich_ways/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';
import 'package:munich_ways/routing/routing_service.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/map_overlay/route_variant_comparison.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';
import 'package:munich_ways/ui/map/route_planner_sheet.dart';

import '../../support/wakelock_stub.dart';

const points = [
  LatLng(48.156304, 11.540013),
  LatLng(48.102548, 11.568796),
  LatLng(48.120477, 11.655645),
  LatLng(47.991860, 11.828568)
];
const comfort = RouteComfort(
    index: 77,
    coverage: 83,
    sufficientCoverage: true,
    distribution: RouteComfortDistribution(
        black: 1, red: 8, yellow: 43, green: 31, unrated: 17));

CycleRoute result(bool direct, [List<LatLng> coordinates = points]) =>
    CycleRoute(coordinates, direct ? 37201 : 43193, 9000,
        maneuvers: [
          for (final point in coordinates.skip(1))
            RouteManeuver(location: point, type: 'arrive')
        ],
        analysisContext: RouteAnalysisContext([
          [1, 2]
        ], variant: direct ? 'direct' : 'standard'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(stubWakelock);

  test('Discovery survives shortest comparison and navigation recalculation',
      () async {
    final h = Harness();
    await flush(); // finish initial settings restoration before the user choice
    h.model.setRouteRecommendation(RouteRecommendation.discovery);
    await h.model.refreshRoute();
    expect(h.model.route.route!.analysisContext!.variant, 'discovery');
    final discoveryCalls = h.api.discoveryCalls;
    await h.api.waitForDirect(1);
    h.api.direct.last.complete(result(true));
    expect(await h.model.setTemporaryShortestRouteEnabled(true), isTrue);
    expect(h.model.route.route!.analysisContext!.variant, 'direct');
    expect(await h.model.setTemporaryShortestRouteEnabled(false), isTrue);
    expect(h.model.route.route!.analysisContext!.variant, 'discovery');
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    expect(await h.model.refreshRoute(), isTrue);
    expect(h.api.discoveryCalls, greaterThan(discoveryCalls));
    expect(h.model.route.route!.analysisContext!.variant, 'discovery');
  });

  test('saved Discovery is first; alternatives wait for its usable route',
      () async {
    final loaded = Completer<SettingsData>();
    final h = Harness(store: MemorySettings()..loadReply = loaded.future);
    h.api.discoveryReply = Completer<CycleRoute>();
    final calculation = h.model.refreshRoute();
    await flush();
    expect(h.api.standardCalls, 0);
    expect(h.api.discoveryCalls, 0);
    loaded.complete(SettingsData.defaults
        .copyWith(routeRecommendation: RouteRecommendation.discovery));
    await flush();
    expect(h.api.discoveryCalls, 1);
    expect(h.api.standardCalls, 0);
    expect(h.api.direct, isEmpty);
    h.api.discoveryReply!.complete(CycleRoute(points, 50000, 10000,
        analysisContext: RouteAnalysisContext(const [
          [1, 2]
        ], variant: 'discovery')));
    expect(await calculation, isTrue);
    expect(h.model.route.state, MapRouteState.SHOWN);
    expect(h.model.route.route!.analysisContext!.variant, 'discovery');
    await flush();
    expect(h.api.standardCalls, 1);
    expect(h.api.direct, hasLength(1));
    expect(h.api.analyses['discovery']!.single.isCompleted, isFalse);
    expect(h.model.selectedRouteVariant, RouteVariant.discovery);
  });

  test('an early edited routing wish survives stale saved settings', () async {
    final loaded = Completer<SettingsData>();
    final h = Harness(store: MemorySettings()..loadReply = loaded.future);
    h.model.destination = null;
    h.model.setRouteRecommendation(RouteRecommendation.discovery);
    loaded.complete(SettingsData.defaults);
    await flush();
    expect(h.model.routeRecommendation, RouteRecommendation.discovery);
    h.model.destination = Place('Ziel', points.last);
    expect(await h.model.refreshRoute(), isTrue);
    expect(h.model.route.route!.analysisContext!.variant, 'discovery');
  });

  testWidgets(
      'stalled settings terminate and cannot change the active trip later',
      (tester) async {
    final loaded = Completer<SettingsData>();
    final h = Harness(store: MemorySettings()..loadReply = loaded.future);
    final calculation = h.model.refreshRoute();
    await tester.pump(const Duration(seconds: 4));
    expect(await calculation, isTrue);
    expect(h.model.selectedRouteVariant, RouteVariant.standard);
    loaded.complete(SettingsData.defaults
        .copyWith(routeRecommendation: RouteRecommendation.discovery));
    await tester.pump();
    expect(h.model.selectedRouteVariant, RouteVariant.standard);
    expect(h.model.route.route!.analysisContext!.variant, 'standard');
    await h.finishPending(tester);
  });

  test(
      'replacement plan while settings load only requests the latest destination',
      () async {
    final loaded = Completer<SettingsData>();
    final h = Harness(store: MemorySettings()..loadReply = loaded.future);
    final first = h.model.refreshRoute();
    h.model.setDestination(Place('New target', points[1]));
    loaded.complete(SettingsData.defaults
        .copyWith(routeRecommendation: RouteRecommendation.discovery));
    expect(await first, isFalse);
    await flush();
    expect(h.api.discoveryCalls, 1);
    expect(h.api.discoveryRequests.single.last, points[1]);
    expect(h.model.selectedRouteVariant, RouteVariant.discovery);
  });

  test('three planner variants retain independent routes and comfort contexts',
      () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    await flush();
    final standard = h.model.route.route;
    final discovery = h.model.routeVariantFor(RouteVariant.discovery)!.route;
    h.api.direct.single.complete(result(true));
    await flush();
    expect(h.api.discoveryRequests.single, points);
    expect(await h.model.selectRouteVariant(RouteVariant.discovery), isTrue);
    expect(h.model.route.route, same(discovery));
    expect(h.model.route.route!.analysisContext!.variant, 'discovery');
    expect(await h.model.selectRouteVariant(RouteVariant.direct), isTrue);
    expect(h.model.route.route!.analysisContext!.variant, 'direct');
    expect(await h.model.selectRouteVariant(RouteVariant.standard), isTrue);
    expect(h.model.route.route, same(standard));
    expect(h.model.selectedRouteVariant, RouteVariant.standard);
    expect(h.api.standardCalls, 1);
    expect(h.api.discoveryCalls, 1);
    expect(h.api.direct, hasLength(1));
    expect(
        h.api.analyses.keys, containsAll(['standard', 'discovery', 'direct']));
  });

  test('failed discovery preserves the route and recovers on retry', () async {
    final h = Harness();
    h.api.discoveryReply = Completer<CycleRoute>();
    h.fallback.fail = true;
    await h.model.refreshRoute();
    await flush();
    final original = h.model.route.route;
    final pending = h.model.selectRouteVariant(RouteVariant.discovery);
    h.api.discoveryReply!.completeError(StateError('offline'));
    expect(await pending, isFalse);
    expect(h.model.route.route, same(original));
    expect(h.model.selectedRouteVariant, RouteVariant.standard);
    expect(h.model.pendingRouteType, isNull);
    h.api.discoveryReply = null;
    expect(await h.model.selectRouteVariant(RouteVariant.discovery), isTrue);
    expect(h.model.route.route!.analysisContext!.variant, 'discovery');
  });

  test('late discovery cannot replace a newer standard selection', () async {
    final h = Harness();
    h.api.discoveryReply = Completer<CycleRoute>();
    await h.model.refreshRoute();
    await flush();
    final standard = h.model.route.route;
    final pending = h.model.selectRouteVariant(RouteVariant.discovery);
    await h.model.selectRouteVariant(RouteVariant.standard);
    h.api.discoveryReply!.complete(result(false));
    expect(await pending, isFalse);
    expect(h.model.route.route, same(standard));
    expect(h.model.selectedRouteVariant, RouteVariant.standard);
    expect(h.model.pendingRouteType, isNull);
  });

  test('navigation discovery switch recovers after a GPS error', () async {
    final h = Harness();
    await h.model.refreshRoute();
    await flush();
    h.model.routeStart = null;
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    final active = h.model.route.route;
    h.model.gpsError = StateError('no location');
    expect(await h.model.selectRouteVariant(RouteVariant.discovery), isFalse);
    expect(h.model.route.route, same(active));
    expect(h.model.pendingRouteType, isNull);
    expect(h.model.navigationStarted, isTrue);
    h.model.gpsError = null;
    expect(await h.model.selectRouteVariant(RouteVariant.discovery), isTrue);
    expect(h.model.route.route!.analysisContext!.variant, 'discovery');
    await h.model.refreshRoute();
    expect(h.model.selectedRouteVariant, RouteVariant.discovery);
    expect(h.model.route.route!.analysisContext!.variant, 'discovery');
  });

  testWidgets('planner shows standard, discovery and direct in order',
      (tester) async {
    final h = Harness();
    await h.model.refreshRoute();
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ListenableBuilder(
                    listenable: h.model,
                    builder: (context, _) =>
                        RouteVariantComparison(model: h.model))))));
    final standard = find.text('Standard Route');
    final discovery = find.text('Entdeckertour');
    final direct = find.text('Direkte Route');
    expect(tester.getTopLeft(standard).dy,
        lessThan(tester.getTopLeft(discovery).dy));
    expect(tester.getTopLeft(discovery).dy,
        lessThan(tester.getTopLeft(direct).dy));
    await tester.tap(find.byKey(const ValueKey('route-variant-discovery')));
    await tester.pumpAndSettle();
    expect(h.model.selectedRouteVariant, RouteVariant.discovery);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await h.finishPending(tester);
  });

  test('GPS lookup failure finishes recalculation and later retry recovers',
      () async {
    final h = Harness();
    h.model.routeStart = null;
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    h.model.gpsError = StateError('GPS and cached position unavailable');
    expect(await h.model.refreshRoute(), isFalse);
    expect(h.model.route.state, MapRouteState.ERROR);
    expect(h.model.navigationStarted, isTrue);
    h.model.gpsError = null;
    expect(await h.model.refreshRoute(), isTrue);
    expect(h.model.route.state, MapRouteState.SHOWN);
    expect(h.model.navigationStarted, isTrue);
  });

  testWidgets(
      'unresponsive GPS fallback times out rather than locking recalculation',
      (tester) async {
    final h = Harness();
    h.model.routeStart = null;
    h.model.gpsReply = Completer<Position?>().future;
    final request = h.model.refreshRoute();
    await tester.pump(const Duration(seconds: 16));
    expect(await request, isFalse);
    expect(h.model.route.state, MapRouteState.ERROR);
  });

  test(
      'standard is usable before direct and comfort; warm switches share navigation',
      () async {
    final h = Harness();
    final events = <MapRoute>[];
    final subscription = h.model.routeStream.listen(events.add);
    addTearDown(subscription.cancel);
    expect(await h.model.refreshRoute(), isTrue);
    await h.api.waitForDirect(1);
    final standard = h.model.route.route;
    expect(h.model.route.state, MapRouteState.SHOWN);
    expect(h.api.direct, hasLength(1));
    expect(h.api.requests.single, points);
    expect(h.model.routeVariant(true)!.state, MapRouteState.LOADING);
    final switchRequest = h.model.setTemporaryShortestRouteEnabled(true);
    expect(h.model.route.route, same(standard));
    final direct = result(true);
    h.api.direct.single.complete(direct);
    expect(await switchRequest, isTrue);
    expect(h.model.route.route, same(direct));
    expect(h.model.voiceGuidanceAvailable, isTrue);
    final guidance = VoiceGuidance();
    expect(guidance.setRoute(direct), isTrue);
    expect(direct.maneuvers, hasLength(3));
    h.api.analyses['standard']!.single.complete(comfort);
    await flush();
    expect(standard!.comfort, same(comfort));
    expect(direct.comfort, isNull);
    expect(h.model.route.route, same(direct));
    h.api.analyses['direct']!.single.complete(comfort);
    await flush();
    expect(guidance.setRoute(direct), isFalse);
    expect(await h.model.setTemporaryShortestRouteEnabled(false), isTrue);
    expect(h.model.route.route, same(standard));
    expect(h.model.route.comfortState, RouteComfortState.ready);
    expect(h.api.standardCalls, 1);
    expect(h.api.direct, hasLength(1));
    expect(h.fallback.calls, 0);
    await flush();
    expect(events,
        hasLength(3)); // standard, direct, standard; no metadata events.
  });

  test('failed switch preserves standard and can recover on retry', () async {
    final h = Harness();
    h.fallback.fail = true;
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    final standard = h.model.route.route;
    final switching = h.model.setTemporaryShortestRouteEnabled(true);
    h.api.direct.single.completeError(StateError('offline'));
    expect(await switching, isFalse);
    expect(h.model.route.route, same(standard));
    expect(h.model.temporaryShortestRouteEnabled, isFalse);
    expect(h.model.routeVariant(true)!.state, MapRouteState.ERROR);
    final retry = h.model.setTemporaryShortestRouteEnabled(true);
    await flush();
    h.api.direct.last.complete(result(true));
    expect(await retry, isTrue);
    expect(h.model.voiceGuidanceAvailable, isTrue);
  });

  test('refresh invalidates both variants and late route/comfort completions',
      () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    final old = h.model.route.route!;
    final switching = h.model.setTemporaryShortestRouteEnabled(true);
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    final current = h.model.route.route;
    h.api.direct.first.complete(result(true));
    h.api.analyses['standard']!.first.complete(comfort);
    expect(await switching, isFalse);
    await flush();
    expect(old.comfort, isNull);
    expect(h.model.route.route, same(current));
    expect(h.model.routeVariant(true)!.state, MapRouteState.LOADING);
    h.api.direct.last.complete(result(true));
    await flush();
    expect(h.model.route.route, same(current));
  });

  test('ending the trip prevents a late switch and clears cached alternatives',
      () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    final switching = h.model.setTemporaryShortestRouteEnabled(true);
    h.model.clearDestination();
    h.api.direct.single.complete(result(true));
    expect(await switching, isFalse);
    expect(h.model.route.state, MapRouteState.NO_ROUTE);
    expect(h.model.hasRouteComparison, isFalse);
    expect(h.model.temporaryShortestRouteEnabled, isFalse);
  });

  test(
      'selecting standard again cancels a pending switch without cancelling its cache',
      () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    final standard = h.model.route.route;
    final switching = h.model.setTemporaryShortestRouteEnabled(true);
    await h.model.setTemporaryShortestRouteEnabled(false);
    h.api.direct.single.complete(result(true));
    expect(await switching, isFalse);
    expect(h.model.route.route, same(standard));
    expect(h.model.routeVariant(true)!.state, MapRouteState.SHOWN);
  });

  test(
      'direct choice persists for refresh; standard follows without taking over',
      () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    h.api.direct.single.complete(result(true));
    await h.model.setTemporaryShortestRouteEnabled(true);
    final refresh = h.model.refreshRoute();
    await flush();
    expect(h.api.standardCalls, 1); // direct must finish first
    final replacement = result(true);
    h.api.direct.last.complete(replacement);
    expect(await refresh, isTrue);
    await flush();
    expect(h.api.standardCalls, 2);
    expect(h.model.route.route, same(replacement));
    expect(h.api.requests.last, points);
    expect(h.model.temporaryShortestRouteEnabled, isTrue);
  });

  test(
      'navigation start cancels pending selection but preserves background metadata',
      () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    final standard = h.model.route.route;
    final switching = h.model.setTemporaryShortestRouteEnabled(true);
    h.model.routeStart = null; // These tests cover an already GPS-based plan.
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    expect(await h.model.startNavigation(), isTrue);
    h.api.direct.single.complete(result(true));
    expect(await switching, isFalse);
    expect(h.model.pendingRouteVariant, isNull);
    expect(h.model.route.route, same(standard));
    expect(h.model.navigationStarted, isTrue);
  });

  for (final selected in RouteVariant.values) {
    test(
        'navigation refresh only requests the active ${selected.name} route and comfort',
        () async {
      final h = Harness();
      await h.model.refreshRoute();
      await h.api.waitForDirect(1);
      h.api.direct.single.complete(result(true));
      await flush();
      if (selected != RouteVariant.standard) {
        expect(await h.model.selectRouteVariant(selected), isTrue);
      }
      h.model.routeStart = null;
      h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
      await h.model.startNavigation();
      final standard = h.api.standardCalls;
      final discovery = h.api.discoveryCalls;
      final direct = h.api.direct.length;
      final analyses = {
        for (final entry in h.api.analyses.entries)
          entry.key: entry.value.length
      };
      final refresh = h.model.refreshRoute();
      await flush();
      if (selected == RouteVariant.direct) {
        h.api.direct.last.complete(result(true, h.api.requests.last));
      }
      expect(await refresh, isTrue);
      await flush();
      expect(h.api.standardCalls,
          standard + (selected == RouteVariant.standard ? 1 : 0));
      expect(h.api.discoveryCalls,
          discovery + (selected == RouteVariant.discovery ? 1 : 0));
      expect(h.api.direct.length,
          direct + (selected == RouteVariant.direct ? 1 : 0));
      expect(h.model.route.route!.analysisContext!.variant, selected.name);
      expect(h.model.navigationActive, isTrue);
      for (final variant in RouteVariant.values) {
        expect(h.api.analyses[variant.name]!.length,
            analyses[variant.name]! + (variant == selected ? 1 : 0));
        if (variant != selected)
          expect(h.model.routeVariantFor(variant), isNull);
      }
      // Explicitly selecting an unloaded type still recalculates from current GPS.
      final next = selected == RouteVariant.direct
          ? RouteVariant.discovery
          : RouteVariant.direct;
      final switching = h.model.selectRouteVariant(next);
      await flush();
      if (next == RouteVariant.direct) {
        h.api.direct.last.complete(result(true, h.api.requests.last));
      }
      expect(await switching, isTrue);
      expect(h.model.route.route!.points.first, const LatLng(48.11, 11.60));
      expect(h.model.route.route!.analysisContext!.variant, next.name);
      expect(h.model.navigationActive, isTrue);
    });
  }

  test('direct navigation reroutes from GPS with only remaining stops',
      () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    h.api.direct.single.complete(result(true));
    await h.model.setTemporaryShortestRouteEnabled(true);
    h.model.routeStart = null; // These tests cover an already GPS-based plan.
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    h.model.updateWaypointProgress(points[1]);
    final refresh = h.model.refreshRoute();
    await flush();
    expect(h.api.requests.last,
        [const LatLng(48.11, 11.60), points[2], points[3]]);
    expect(h.model.waypoints, hasLength(1));
    h.api.direct.last.complete(result(true, h.api.requests.last));
    expect(await refresh, isTrue);
    expect(h.model.temporaryShortestRouteEnabled, isTrue);
    expect(h.model.navigationStarted, isTrue);
    expect(h.model.voiceGuidanceAvailable, isTrue);
    expect(h.model.route.route!.maneuvers, hasLength(2));
  });

  for (final distanceMeters in [34.0, 36.0]) {
    test('rerouting retains only stops outside 35 metres ($distanceMeters m)',
        () async {
      final h = Harness();
      await h.model.refreshRoute();
      await h.api.waitForDirect(1);
      h.model.routeStart = null;
      h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
      await h.model.startNavigation();
      h.model.updateWaypointProgress(
          const Distance().offset(points[1], distanceMeters, 270));

      final remainingStops =
          distanceMeters < 35 ? [points[2]] : [points[1], points[2]];
      expect(await h.model.refreshRoute(), isTrue);
      await flush();
      expect(h.api.direct, hasLength(1));
      expect(h.model.waypoints.map((stop) => stop.latLng), remainingStops);
      expect(h.api.standardRequests.last,
          [const LatLng(48.11, 11.60), ...remainingStops, points.last]);
    });
  }

  test('nearby passed stops stay removed through a failed reroute and retry',
      () async {
    final h = Harness();
    final first = points[1];
    final second = const Distance().offset(first, 10, 0);
    final midpoint = const Distance().offset(first, 5, 0);
    final passingPosition = const Distance().offset(midpoint, 34, 270);
    final pendingStop = Place('Noch offen', points[2]);
    h.model.waypoints
      ..clear()
      ..addAll([
        Place('Weganfang', first),
        Place('Wegende', second),
        pendingStop,
      ]);
    for (final stop in [first, second]) {
      expect(const Distance()(passingPosition, stop), inExclusiveRange(30, 35));
    }
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    h.api.direct.single.complete(result(true, h.api.requests.single));
    await h.model.setTemporaryShortestRouteEnabled(true);
    h.model.routeStart = null;
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    // Stop progress must also work while voice guidance is muted.
    h.model.setVoiceGuidanceEnabled(false);
    h.model.updateWaypointProgress(passingPosition);

    final expectedRequest = [
      const LatLng(48.11, 11.60),
      pendingStop.latLng,
      points.last,
    ];
    h.fallback.fail = true;
    final failed = h.model.refreshRoute();
    await h.api.waitForDirect(2);
    expect(h.api.requests.last, expectedRequest);
    expect(h.model.waypoints, [pendingStop]);
    h.api.direct.last.completeError(StateError('offline'));
    expect(await failed, isFalse);

    h.fallback.fail = false;
    final retry = h.model.refreshRoute();
    await h.api.waitForDirect(3);
    expect(h.api.requests.last, expectedRequest);
    h.api.direct.last.complete(result(true, expectedRequest));
    expect(await retry, isTrue);
    expect(h.model.waypoints, [pendingStop]);
    expect(h.model.navigationActive, isTrue);
  });

  test('switch during navigation recalculates from GPS before replacing route',
      () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    final standard = h.model.route.route;
    h.model.routeStart = null; // These tests cover an already GPS-based plan.
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    h.model.updateWaypointProgress(points[1]);

    final switching = h.model.setTemporaryShortestRouteEnabled(true);
    await h.api.waitForDirect(2);

    expect(h.model.route.route, same(standard));
    expect(h.model.pendingRouteVariant, isTrue);
    expect(h.api.requests.last, [
      const LatLng(48.11, 11.60),
      points[2],
      points[3],
    ]);

    final direct = result(true, h.api.requests.last);
    h.api.direct.last.complete(direct);
    expect(await switching, isTrue);
    expect(h.model.route.route, same(direct));
    expect(h.model.temporaryShortestRouteEnabled, isTrue);
    expect(h.model.navigationStarted, isTrue);
    expect(h.model.pendingRouteVariant, isNull);

    expect(await h.model.setTemporaryShortestRouteEnabled(false), isTrue);
    expect(h.model.temporaryShortestRouteEnabled, isFalse);
    expect(h.model.route.route!.points.first, const LatLng(48.11, 11.60));
    expect(h.model.navigationStarted, isTrue);
  });

  test('failed switch during navigation preserves the active route', () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    final standard = h.model.route.route;
    h.model.routeStart = null; // These tests cover an already GPS-based plan.
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    h.fallback.fail = true;

    final switching = h.model.setTemporaryShortestRouteEnabled(true);
    await h.api.waitForDirect(2);
    h.api.direct.last.completeError(StateError('offline'));

    expect(await switching, isFalse);
    expect(h.model.route.route, same(standard));
    expect(h.model.temporaryShortestRouteEnabled, isFalse);
    expect(h.model.navigationStarted, isTrue);
    expect(h.model.pendingRouteVariant, isNull);
  });

  test('retained route comfort completes after a cancelled navigation switch',
      () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    final active = h.model.route;
    h.model.routeStart = null; // These tests cover an already GPS-based plan.
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    final switching = h.model.setTemporaryShortestRouteEnabled(true);
    await h.api.waitForDirect(2);
    await h.model.setTemporaryShortestRouteEnabled(false);
    h.api.direct.last.complete(result(true, h.api.requests.last));
    expect(await switching, isFalse);
    h.api.analyses['standard']!.single.complete(comfort);
    await flush();
    expect(h.model.route, same(active));
    expect(active.comfortState, RouteComfortState.ready);
    expect(active.route!.comfort, same(comfort));
  });

  testWidgets('open planner does not restore stops passed before recalculation',
      (tester) async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    h.model.routeStart = null; // These tests cover an already GPS-based plan.
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      showRoutePlannerSheet(context, model: h.model),
                  child: const Text('Open'),
                ),
              )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    h.model.updateWaypointProgress(points[1]);
    await tester.tap(find.text('Route berechnen'));
    await tester.pumpAndSettle();
    expect(h.model.route.route!.points,
        [const LatLng(48.11, 11.60), points[2], points[3]]);
    expect(h.model.navigationStarted, isTrue);
    // Finish both generations' fake requests, including discarded results.
    for (final pending in h.api.direct) {
      pending.complete(result(true));
    }
    await tester.pump();
    for (final pending in h.api.analyses.values.expand((list) => list)) {
      pending.complete(comfort);
    }
    await tester.pumpAndSettle();
  });

  test('comfort retry for the inactive variant preserves the active route',
      () async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    final standard = h.model.route.route;
    h.api.direct.single.complete(result(true));
    await flush();
    h.api.analyses['direct']!.single
        .completeError(StateError('analysis offline'));
    await flush();
    expect(h.model.routeVariant(true)!.comfortState, RouteComfortState.error);
    final retry = h.model.retryRouteComfort(direct: true);
    h.api.analyses['direct']!.last.complete(comfort);
    await retry;
    expect(h.model.route.route, same(standard));
    expect(h.model.routeVariant(true)!.comfortState, RouteComfortState.ready);
    expect(h.model.temporaryShortestRouteEnabled, isFalse);
  });

  testWidgets('navigation keeps both route radio controls available',
      (tester) async {
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    h.api.direct.single.complete(result(true));
    await tester.pump();
    for (final pending in h.api.analyses.values.expand((list) => list)) {
      pending.complete(comfort);
    }
    h.model.routeStart = null; // These tests cover an already GPS-based plan.
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RouteVariantComparison(model: h.model)))));
    await tester.pumpAndSettle();
    expect(find.text('Standard Route'), findsOneWidget);
    expect(find.text('Direkte Route'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    expect(find.byKey(const ValueKey('route-variant-true')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparison fits 320px at 200% text and exposes selection',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = Harness();
    await h.model.refreshRoute();
    await h.api.waitForDirect(1);
    h.api.direct.single.complete(result(true));
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SizedBox(
                    width: 320,
                    child: SingleChildScrollView(
                        child: ListenableBuilder(
                            listenable: h.model,
                            builder: (context, child) =>
                                RouteVariantComparison(model: h.model))))))));
    expect(find.text('Direkte Route'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final selectedColor = tester
        .widget<Card>(find.byKey(const ValueKey('route-variant-card-false')))
        .color;
    expect(
        tester
            .widget<Card>(find.byKey(const ValueKey('route-variant-card-true')))
            .color,
        isNot(selectedColor));
    final direct = find.byKey(const ValueKey('route-variant-true'));
    await tester.ensureVisible(direct);
    await tester.tap(direct);
    await tester.pumpAndSettle();
    expect(h.model.temporaryShortestRouteEnabled, isTrue);
    expect(
        tester
            .widget<Card>(find.byKey(const ValueKey('route-variant-card-true')))
            .color,
        selectedColor);
    expect(tester.takeException(), isNull);
    h.api.analyses['standard']!.single.complete(comfort);
    h.api.analyses['direct']!.single.complete(const RouteComfort(
        index: null,
        coverage: 50,
        sufficientCoverage: false,
        distribution: RouteComfortDistribution(
            black: 0, red: 10, yellow: 10, green: 30, unrated: 50)));

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('variant-comfort-bar-false')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('variant-comfort-bar-true')), findsOneWidget);
    final directBar = find.byKey(const ValueKey('variant-comfort-bar-true'));
    final unrated = tester.widget<Expanded>(find.descendant(
        of: directBar,
        matching: find.byKey(const ValueKey('comfort-segment-unrated'))));
    expect(
        unrated.flex, 50); // A bar is useful even when no index is available.

    expect(tester.takeException(), isNull);
    expect(find.text('Radl-Komfort 77/100'), findsOneWidget);
    expect(find.text('Radl-Komfort -'), findsOneWidget);
    expect(find.text('50 % bewertet'), findsOneWidget);
    expect(
        tester
            .getSize(find.byKey(const ValueKey('route-variant-card-true')))
            .height,
        lessThan(tester
            .getSize(find.byKey(const ValueKey('route-variant-card-false')))
            .height));
    final directTitle = tester.widget<Text>(find.text('Direkte Route'));
    expect(directTitle.style?.fontWeight, isNot(FontWeight.bold));
    final info = find.byKey(const ValueKey('variant-comfort-info-true'));
    await tester.ensureVisible(info);
    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(find.text('50 % der Route bewertet'), findsOneWidget);
    expect(find.text('Radl-Komfort -'), findsWidgets);
    expect(find.byKey(const ValueKey('comfort-info-close')), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getSize(find.byType(BottomSheet)).width, 320);
    expect(find.textContaining('Index 0 bis 100:'), findsOneWidget);
    final links = find.text('Weitere Infos zum Komfort-Index');
    expect(tester.getTopLeft(links).dx,
        tester.getTopLeft(find.text('Farben dieser Route')).dx);

    final link = find.widgetWithText(TextButton, 'Info zur direkten Route');
    expect(link, findsOneWidget);
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'Die direkte Route bevorzugt zügiges Fahren ohne Berücksichtigung'),
        findsOneWidget);
    expect(find.text('Direkte Route berechnen'), findsNothing);
    expect(find.text('Bei Standard bleiben'), findsNothing);
    final topDialog = find.byType(AlertDialog).last;
    expect(find.descendant(of: topDialog, matching: find.byType(FilledButton)),
        findsOneWidget);
    await tester.tap(
        find.descendant(of: topDialog, matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(h.model.temporaryShortestRouteEnabled, isTrue);
    expect(find.text('Radl-Komfort-Index'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('comfort-info-close')));
    await tester.pumpAndSettle();
    expect(find.text('Radl-Komfort-Index'), findsNothing);
    expect(tester.takeException(), isNull);
    await h.finishPending(tester);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.info_outline), findsNWidgets(6));
    for (final entry in [
      ('false', 'Standard Route', RouteRecommendation.standard),
      ('discovery', 'Entdeckertour', RouteRecommendation.discovery),
    ]) {
      final info = find.byKey(ValueKey('variant-mode-info-${entry.$1}'));
      final title = find.text(entry.$2);
      expect(tester.getSize(info).height,
          lessThanOrEqualTo(tester.getSize(title).height));
      expect(
          tester.getTopLeft(info).dx, greaterThan(tester.getTopLeft(title).dx));
      await tester.ensureVisible(info);
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(
          find.text(const AppLocalizations(Locale('de'))
              .routeRecommendationInfo(entry.$3)),
          findsOneWidget);
      expect(h.model.selectedRouteVariant, RouteVariant.direct);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
    }
    final directInfo = find.byKey(const ValueKey('variant-mode-info-true'));
    await tester.ensureVisible(directInfo);
    await tester.tap(directInfo);
    await tester.pumpAndSettle();
    expect(find.textContaining('Die direkte Route bevorzugt'), findsOneWidget);
    expect(h.model.selectedRouteVariant, RouteVariant.direct);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    final comfortInfo = find.byKey(const ValueKey('variant-comfort-info-true'));
    final index = find.text('Radl-Komfort -');
    expect(tester.getSize(comfortInfo).height,
        lessThanOrEqualTo(tester.getSize(index).height));
    expect(tester.getCenter(comfortInfo).dy,
        closeTo(tester.getCenter(index).dy, 1));
    expect(tester.takeException(), isNull);
  });
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

class Harness {
  Future<void> finishPending(WidgetTester tester) async {
    for (final request in api.direct) {
      if (!request.isCompleted) request.complete(result(true));
    }
    await tester.pump();
    for (final pending in api.analyses.values.expand((list) => list)) {
      if (!pending.isCompleted) pending.complete(comfort);
    }
    await tester.pump();
  }

  final api = VariantApi();
  final fallback = Fallback();
  late final TestModel model;
  Harness({MemorySettings? store}) {
    model = TestModel(
        store: store ?? MemorySettings(),
        routingService: RoutingService(
            radlNavi: api, bRouter: fallback, radlNaviCoverage: Coverage()));
    model.routeStart = Place('Start', points.first);
    model.destination = Place('Ziel', points.last);
    model.waypoints
        .addAll([Place('Stop 1', points[1]), Place('Stop 2', points[2])]);
    addTearDown(() {
      model.dispose();
      for (final pending in api.direct) {
        if (!pending.isCompleted) pending.complete(result(true));
      }
      for (final pending in api.analyses.values.expand((list) => list)) {
        if (!pending.isCompleted) pending.complete(comfort);
      }
    });
  }
}

class MemorySettings extends SettingsStore {
  SettingsData data = SettingsData.defaults;

  Future<SettingsData>? loadReply;
  @override
  Future<SettingsData> load() async => loadReply ?? Future.value(data);

  @override
  Future<void> saveRouteRecommendation(RouteRecommendation? value) async {
    data = data.copyWith(routeRecommendation: value);
  }

  @override
  Future<void> saveRoutingMode(RoutingMode value) async {
    data = data.copyWith(routingMode: value);
  }

  @override
  Future<void> saveBRouterProfile(BRouterProfile value) async {
    data = data.copyWith(bRouterProfile: value);
  }

  @override
  Future<void> saveVoiceGuidanceEnabled(bool enabled) async {
    data = data.copyWith(voiceGuidanceEnabled: enabled);
  }
}

class Coverage implements RoutingCoverage {
  @override
  Future<bool> contains(LatLng point) async => true;
}

class VariantApi
    implements
        RoutingProvider,
        DirectRoutingProvider,
        RouteComfortProvider,
        DiscoveryRoutingProvider {
  int standardCalls = 0;
  final standardRequests = <List<LatLng>>[];
  final direct = <Completer<CycleRoute>>[];
  final _requestWaiters = <Completer<void>>[];
  Future<void> waitForDirect(int count) async {
    while (direct.length < count) {
      final waiter = Completer<void>();
      _requestWaiters.add(waiter);
      await waiter.future;
    }
  }

  int discoveryCalls = 0;
  Completer<CycleRoute>? discoveryReply;
  final discoveryRequests = <List<LatLng>>[];
  @override
  Future<CycleRoute> routeDiscovery(List<LatLng> coordinates) async {
    discoveryCalls++;
    discoveryRequests.add(coordinates);
    if (discoveryReply != null) return discoveryReply!.future;
    return CycleRoute(coordinates, 50000, 10000,
        maneuvers: result(false, coordinates).maneuvers,
        analysisContext: RouteAnalysisContext(const [
          [1, 2]
        ], variant: 'discovery'));
  }

  final requests = <List<LatLng>>[];
  final analyses = <String, List<Completer<RouteComfort>>>{};
  @override
  Future<CycleRoute> route(List<LatLng> coordinates,
      {BRouterProfile profile = BRouterProfile.trekking}) async {
    standardCalls++;
    standardRequests.add(coordinates);
    return result(false, coordinates);
  }

  @override
  Future<CycleRoute> routeDirect(List<LatLng> coordinates) {
    requests.add(coordinates);
    final pending = Completer<CycleRoute>();
    direct.add(pending);
    for (final waiter in _requestWaiters) {
      waiter.complete();
    }
    _requestWaiters.clear();
    return pending.future;
  }

  @override
  Future<RouteComfort> analyzeComfort(RouteAnalysisContext context) {
    final pending = Completer<RouteComfort>();
    analyses.putIfAbsent(context.variant, () => []).add(pending);
    return pending.future;
  }
}

class Fallback implements RoutingProvider {
  int calls = 0;
  bool fail = false;
  @override
  Future<CycleRoute> route(List<LatLng> coordinates,
      {BRouterProfile profile = BRouterProfile.trekking}) async {
    calls++;
    if (fail) throw StateError('fallback offline');
    return CycleRoute(coordinates, 100, 30, supportsVoiceGuidance: false);
  }
}

class TestModel extends MapScreenViewModel {
  TestModel({required super.store, required super.routingService});
  Future<Position?>? gpsReply;
  Object? gpsError;
  @override
  Future<Position?> resolveRouteStartPosition() async {
    // Deliver a GPS failure when called, as the real provider does, rather
    // than creating an unhandled failed future before settings have loaded.
    if (gpsError != null) throw gpsError!;
    if (gpsReply != null) return gpsReply;
    return Position(
        latitude: 48.11,
        longitude: 11.60,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 3,
        speedAccuracy: 0);
  }
}
