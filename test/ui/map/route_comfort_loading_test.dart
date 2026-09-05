import 'dart:async';

import '../../support/wakelock_stub.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';
import 'package:munich_ways/routing/routing_service.dart';
import 'package:munich_ways/ui/map/map_overlay/map_route_comfort_summary.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';
import 'package:munich_ways/ui/map/route_planner_sheet.dart';

const _comfort = RouteComfort(
    index: 77,
    coverage: 83,
    sufficientCoverage: true,
    distribution: RouteComfortDistribution(
        black: 1, red: 8, yellow: 43, green: 31, unrated: 17));
const _start = LatLng(48.156304, 11.540013);
const _end = LatLng(47.991860, 11.828568);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(stubWakelock);

  test(
      'route and navigation are ready while comfort waits; no route event on completion',
      () async {
    final h = await _Harness.create();
    final events = <MapRoute>[];
    final subscription = h.model.routeStream.listen(events.add);
    addTearDown(subscription.cancel);
    expect(await h.model.refreshRoute(), isTrue);
    await _flush();
    final route = h.model.route.route!;
    final guidance = VoiceGuidance();
    expect(guidance.setRoute(route), isTrue);
    expect(h.model.route.state, MapRouteState.SHOWN);
    expect(h.model.route.comfortState, RouteComfortState.loading);
    expect(h.primary.coordinates.single, hasLength(4));
    expect(h.primary.pending, hasLength(1));
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    expect(await h.model.startNavigation(), isTrue);
    h.primary.pending.single.complete(_comfort);
    await _flush();
    expect(h.model.route.route, same(route));
    expect(route.comfort, same(_comfort));
    expect(guidance.setRoute(h.model.route.route), isFalse);
    expect(h.model.navigationStarted, isTrue);
    expect(h.model.route.comfortState, RouteComfortState.ready);
    expect(events, hasLength(1));
    expect(h.fallback.calls, 0);
  });

  test('analysis failure and retry keep routing and navigation identity',
      () async {
    final h = await _Harness.create();
    final errors = <String>[];
    final subscription = h.model.errorMsgs.listen(errors.add);
    addTearDown(subscription.cancel);
    await h.model.refreshRoute();
    final route = h.model.route.route;
    h.primary.pending[0].completeError(StateError('offline'));
    await _flush();
    expect(h.model.route.state, MapRouteState.SHOWN);
    expect(h.model.route.comfortState, RouteComfortState.error);
    final retry = h.model.retryRouteComfort();
    await h.model.retryRouteComfort(); // Double tap must not duplicate work.
    expect(h.primary.pending, hasLength(2));
    h.primary.pending[1].complete(_comfort);
    await retry;
    expect(h.model.route.route, same(route));
    expect(h.model.route.comfortState, RouteComfortState.ready);
    expect(h.primary.coordinates, hasLength(1));
    expect(h.fallback.calls, 0);
    expect(errors, isEmpty);
  });

  test(
      'analysis timeout recovers and ignores a late result from the timed-out attempt',
      () async {
    final h = await _Harness.create(timeout: const Duration(milliseconds: 20));
    await h.model.refreshRoute();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(h.model.route.state, MapRouteState.SHOWN);
    expect(h.model.route.comfortState, RouteComfortState.error);
    final retry = h.model.retryRouteComfort();
    h.primary.pending[0].complete(_comfort);
    await _flush();
    expect(h.model.route.route!.comfort, isNull);
    h.primary.pending[1].complete(_comfort);
    await retry;
    expect(h.model.route.comfortState, RouteComfortState.ready);
    expect(h.fallback.calls, 0);
  });

  test(
      'refresh discards old analysis while the new route can finish independently',
      () async {
    final h = await _Harness.create();
    await h.model.refreshRoute();
    final oldRoute = h.model.route.route!;
    await h.model.refreshRoute();
    final current = h.model.route.route!;
    h.primary.pending[0].complete(_comfort);
    await _flush();
    expect(oldRoute.comfort, isNull);
    expect(current.comfort, isNull);
    h.primary.pending[1].complete(_comfort);
    await _flush();
    expect(current.comfort, same(_comfort));
  });

  test(
      'plan revision invalidates pending analysis before a replacement route arrives',
      () async {
    final h = await _Harness.create();
    await h.model.refreshRoute();
    final previous = h.model.route.route!;
    h.model.setRoutePlan(
        start: Place('Start', _start),
        stops: [],
        destination: Place('Changed destination', const LatLng(48.0, 11.8)));
    await _flush();
    h.primary.pending[0].completeError(StateError('old request failed'));
    await _flush();
    expect(h.model.route.route, isNot(same(previous)));
    expect(h.model.route.comfortState, RouteComfortState.loading);
    h.primary.pending[1].complete(_comfort);
    await _flush();
    expect(h.model.route.comfortState, RouteComfortState.ready);
  });

  test('ending a route discards pending comfort', () async {
    final h = await _Harness.create();
    await h.model.refreshRoute();
    final previous = h.model.route.route!;
    h.model.clearDestination();
    h.primary.pending.single.complete(_comfort);
    await _flush();
    expect(h.model.route.state, MapRouteState.NO_ROUTE);
    expect(previous.comfort, isNull);
  });

  test(
      'switching to the temporary direct provider ignores standard-route comfort',
      () async {
    final h = await _Harness.create();
    await h.model.refreshRoute();
    final previous = h.model.route.route!;
    await h.model.setTemporaryShortestRouteEnabled(true);
    final direct = h.model.route.route;
    h.primary.pending.single.complete(_comfort);
    await _flush();
    expect(h.model.route.route, same(direct));
    expect(previous.comfort, isNull);
    expect(h.model.route.comfortState, RouteComfortState.unavailable);
    expect(h.fallback.calls, 1);
  });

  test('a genuine routing error still falls back without requesting comfort',
      () async {
    final h = await _Harness.create();
    h.primary.failRouting = true;
    expect(await h.model.refreshRoute(), isTrue);
    expect(h.model.route.state, MapRouteState.SHOWN);
    expect(h.model.route.comfortState, RouteComfortState.unavailable);
    expect(h.primary.pending, isEmpty);
    expect(h.fallback.calls, 1);
  });

  test('disposing the view model ignores optional analysis completion',
      () async {
    final h = await _Harness.create(disposeAtEnd: false);
    await h.model.refreshRoute();
    final route = h.model.route.route!;
    h.model.dispose();
    h.primary.pending.single.complete(_comfort);
    await _flush();
    expect(route.comfort, isNull);
  });

  testWidgets('open planner updates when comfort arrives during navigation',
      (tester) async {
    final h = await _Harness.create();
    await h.model.refreshRoute();
    h.model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await h.model.startNavigation();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showRoutePlannerSheet(context, model: h.model),
        child: const Text('Open planner'),
      ),
    ))));
    await tester.tap(find.text('Open planner'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-comfort-loading')), findsOneWidget);
    h.primary.pending.single.complete(_comfort);
    await tester.pumpAndSettle();
    expect(find.text('77/100'), findsOneWidget);
    expect(find.byKey(const ValueKey('route-comfort-loading')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'loading and error are independent visible states; retry recovers',
      (tester) async {
    final h = await _Harness.create();
    await h.model.refreshRoute();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SizedBox(
              width: 320,
              child: ListenableBuilder(
                listenable: h.model,
                builder: (context, _) => MapRouteComfortSummary(model: h.model),
              ))),
    ));
    expect(find.byKey(const ValueKey('route-comfort-loading')), findsOneWidget);
    h.primary.pending[0].completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-comfort-error')), findsOneWidget);
    await tester.tap(find.byTooltip('Komfort erneut laden'));
    await tester.pump();
    expect(find.byKey(const ValueKey('route-comfort-loading')), findsOneWidget);
    h.primary.pending[1].complete(_comfort);
    await tester.pumpAndSettle();
    expect(find.text('77/100'), findsOneWidget);
    expect(h.model.route.state, MapRouteState.SHOWN);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _Harness {
  _Harness(this.model, this.primary, this.fallback);
  final MapScreenViewModel model;
  final _ComfortProvider primary;
  final _FallbackProvider fallback;

  static Future<_Harness> create(
      {Duration timeout = const Duration(seconds: 30),
      bool disposeAtEnd = true}) async {
    final primary = _ComfortProvider();
    final fallback = _FallbackProvider();
    final model = MapScreenViewModel(
        store: _Settings(),
        routingService: RoutingService(
          radlNavi: primary,
          bRouter: fallback,
          radlNaviCoverage: _Coverage(),
          comfortRequestTimeout: timeout,
        ));
    await Future<void>.value();
    model.routeStart = Place('Start', _start);
    model.destination = Place('Ziel', _end);
    model.waypoints.addAll([
      Place('Stop 1', const LatLng(48.102548, 11.568796)),
      Place('Stop 2', const LatLng(48.120477, 11.655645)),
    ]);
    if (disposeAtEnd) addTearDown(model.dispose);
    return _Harness(model, primary, fallback);
  }
}

class _Settings extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

class _Coverage implements RoutingCoverage {
  @override
  Future<bool> contains(LatLng point) async => true;
}

class _ComfortProvider implements RoutingProvider, RouteComfortProvider {
  bool failRouting = false;
  final coordinates = <List<LatLng>>[];
  final pending = <Completer<RouteComfort>>[];

  @override
  Future<CycleRoute> route(List<LatLng> points,
      {BRouterProfile profile = BRouterProfile.trekking}) async {
    coordinates.add(points);
    if (failRouting) throw StateError('Routing failed');
    return CycleRoute(points, 43193, 9495.3,
        maneuvers: [
          for (final point in points.skip(1))
            RouteManeuver(location: point, type: 'arrive')
        ],
        analysisContext: RouteAnalysisContext([
          [1, 2],
          [2, 3],
          [3, 4]
        ]));
  }

  @override
  Future<RouteComfort> analyzeComfort(RouteAnalysisContext context) {
    final result = Completer<RouteComfort>();
    pending.add(result);
    return result.future;
  }
}

class _FallbackProvider implements RoutingProvider {
  int calls = 0;
  @override
  Future<CycleRoute> route(List<LatLng> points,
      {BRouterProfile profile = BRouterProfile.trekking}) async {
    calls++;
    return CycleRoute(points, 100, 30, supportsVoiceGuidance: false);
  }
}
