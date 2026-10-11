import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/navigation_remaining.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

const _start = LatLng(48.1400, 11.57);
const _middle = LatLng(48.1420, 11.57);
const _end = LatLng(48.1440, 11.57);

CycleRoute _route() => CycleRoute(const [_start, _middle, _end], 1000, 600);

void _rideToMiddle(VoiceGuidance guidance) {
  for (var step = 0; step <= 4; step++) {
    guidance.display(LatLng(48.1400 + step * 0.0005, 11.57),
        english: false, speedMetersPerSecond: 10);
  }
}

void main() {
  test('uses the actual matched fraction, independent of speech lookahead', () {
    final route = _route();
    final guidance = VoiceGuidance()..setRoute(route);
    _rideToMiddle(guidance);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 5);
    expect(guidance.remainingEstimate?.minutes, 5);
    expect(guidance.remainingEstimate?.route, same(route));
    // The optional statistic never rewrites the routing response.
    expect(route.distance, 1000);
    expect(route.duration, 600);
    expect(guidance.display(_middle, english: false), isNull);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 5);
  });

  test('off-route invalidation and reanchoring can increase remaining distance',
      () {
    final guidance = VoiceGuidance()..setRoute(_route());
    _rideToMiddle(guidance);
    guidance.display(const LatLng(48.1420, 11.574), english: false);
    expect(guidance.remainingEstimate, isNull);
    const earlier = LatLng(48.1410, 11.57);
    expect(guidance.resumeAt(earlier), isTrue);
    expect(guidance.remainingEstimate, isNull);
    guidance.display(earlier, english: false);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 8);
    expect(guidance.remainingEstimate?.minutes, 8);
  });

  test('an intermediate arrival retains the distance to the final destination',
      () {
    final route = _route()
      ..maneuvers = const [
        RouteManeuver(location: _middle, type: 'arrive'),
        RouteManeuver(location: _end, type: 'arrive'),
      ];
    final guidance = VoiceGuidance()..setRoute(route);
    _rideToMiddle(guidance);
    expect(guidance.finalDestinationReached, isFalse);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 5);
  });

  test('only matched final arrival yields zero and remains latched', () {
    final guidance = VoiceGuidance()..setRoute(_route());
    for (var step = 0; step <= 8; step++) {
      guidance.display(LatLng(48.1400 + step * 0.0005, 11.57), english: false);
    }
    expect(guidance.finalDestinationReached, isTrue);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 0);
    expect(guidance.remainingEstimate?.minutes, 0);
    guidance.display(const LatLng(48.15, 11.58), english: false);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 0);
  });

  test('passing an earlier occurrence retains distance and does not arrive',
      () {
    const passedDestination = LatLng(48.141, 11.57);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [
          _start,
          passedDestination,
          LatLng(48.142, 11.571),
          LatLng(48.140, 11.572),
          passedDestination
        ],
        1000,
        600,
      ));
    guidance.display(passedDestination, english: false);
    expect(guidance.remainingEstimate?.hundredsOfMeters, greaterThan(0));
    expect(guidance.finalDestinationReached, isFalse);
    expect(guidance.update(passedDestination, english: false),
        isNot(contains('Ziel erreicht')));
  });

  test('ambiguous bridge match is unavailable and a later clear fix recovers',
      () {
    const upperStart = LatLng(48.13970, 11.57080);
    const upperRoad = LatLng(48.14000, 11.57100);
    const outer = LatLng(48.14030, 11.57120);
    const lowerRoad = LatLng(48.14004, 11.57100);
    const end = LatLng(48.14004, 11.57050);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
          const [upperStart, upperRoad, outer, lowerRoad, end], 300, 90));
    guidance.display(const LatLng(48.140035, 11.57100), english: false);
    expect(guidance.remainingEstimate, isNull);
    expect(guidance.resumeAt(end), isTrue);
    guidance.display(end, english: false);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 0);
  });

  test('route replacement and reset never retain an old estimate', () {
    final route = _route();
    final guidance = VoiceGuidance()..setRoute(route);
    _rideToMiddle(guidance);
    guidance.setRoute(_route());
    expect(guidance.remainingEstimate, isNull);
    guidance.display(_start, english: false);
    expect(guidance.remainingEstimate?.route, isNot(same(route)));
    guidance.reset();
    expect(guidance.remainingEstimate, isNull);
  });

  final unsupported = <String, CycleRoute Function()>{
    'empty geometry': () => CycleRoute(const [], 1000, 600),
    'zero-length geometry': () => CycleRoute(const [_start, _start], 1000, 600),
  };
  for (final entry in unsupported.entries) {
    test('${entry.key} has no fabricated estimate', () {
      final guidance = VoiceGuidance()..setRoute(entry.value());
      guidance.display(_start, english: false);
      expect(guidance.remainingEstimate, isNull);
    });
  }

  test('destination access retains values up to the route end, not the door',
      () {
    final route = _route()
      ..destinationConnector = const [_end, LatLng(48.146, 11.57)];
    final guidance = VoiceGuidance()..setRoute(route);
    _rideToMiddle(guidance);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 5);
    expect(guidance.remainingEstimate?.minutes, 5);
    for (var step = 5; step <= 8; step++) {
      guidance.display(LatLng(48.1400 + step * 0.0005, 11.57), english: false);
    }
    expect(guidance.remainingEstimate?.hundredsOfMeters, 0);
    expect(guidance.remainingEstimate?.minutes, 0);
    expect(guidance.finalDestinationReached, isFalse);
  });

  test('map-only BRouter geometry has progress, expiry recovery and endpoint',
      () {
    final route = _route()..supportsVoiceGuidance = false;
    final guidance = VoiceGuidance()..setRoute(route);
    _rideToMiddle(guidance);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 5);
    guidance.display(const LatLng(48.142, 11.574), english: false);
    expect(guidance.remainingEstimate, isNull);
    guidance.display(_middle, english: false);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 5);
    for (var step = 5; step <= 8; step++) {
      guidance.display(LatLng(48.1400 + step * 0.0005, 11.57), english: false);
    }
    expect(guidance.remainingEstimate?.hundredsOfMeters, 0);
    expect(guidance.update(_end, english: false), isNull);
  });

  test('a closed loop shows valid remaining values away from ambiguous matches',
      () {
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
          const [_start, _middle, LatLng(48.142, 11.572), _start], 1000, 600));
    guidance.display(_start, english: false);
    expect(guidance.finalDestinationReached, isFalse);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 10);
    _rideToMiddle(guidance);
    expect(
        guidance.remainingEstimate?.hundredsOfMeters, inInclusiveRange(1, 9));
  });

  test('a repeated segment does not suppress unambiguous parts of the route',
      () {
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
          const [_start, _middle, _start, LatLng(48.14, 11.575)], 1000, 600));
    guidance.display(_start, english: false);
    expect(guidance.remainingEstimate, isNotNull);
  });

  test('remaining metrics exclude OSRM final access without changing totals',
      () {
    final route = CycleRoute(const [_start, _middle, _end], 1200, 900,
        navigationDistance: 1000,
        navigationDuration: 600,
        destinationConnector: const [_end, LatLng(48.146, 11.57)]);
    final guidance = VoiceGuidance()..setRoute(route);
    _rideToMiddle(guidance);
    expect(guidance.remainingEstimate?.hundredsOfMeters, 5);
    expect(guidance.remainingEstimate?.minutes, 5);
    expect(route.distance, 1200);
    expect(route.duration, 900);
  });

  test('invalid metrics are rejected and non-arrival values stay above zero',
      () {
    final route = _route();
    expect(NavigationRemaining.estimate(route, double.nan), isNull);
    route.distance = double.infinity;
    expect(NavigationRemaining.estimate(route, 0.5), isNull);
    route.distance = 1000;
    route.duration = -1;
    expect(NavigationRemaining.estimate(route, 0.5), isNull);
    final almostThere = NavigationRemaining.estimate(_route(), 0.001)!;
    expect(almostThere.hundredsOfMeters, 1);
    expect(almostThere.minutes, 1);
  });

  testWidgets('fresh identical values renew expiry without notifying listeners',
      (tester) async {
    var now = DateTime.utc(2026, 10, 11);
    final controller = NavigationRemainingController(now: () => now);
    addTearDown(controller.dispose);
    final estimate = NavigationRemaining.estimate(_route(), 0.5);
    var changes = 0;
    controller.addListener(() => changes++);
    controller.update(estimate, fixTime: now);
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    controller.update(estimate, fixTime: now);
    expect(changes, 1);
    await tester.pump(const Duration(seconds: 14));
    expect(controller.value, estimate);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.value, isNull);
    expect(changes, 2);
  });

  testWidgets('old and future fixes fail closed; clear and fresh retry recover',
      (tester) async {
    final now = DateTime.utc(2026, 10, 11);
    final controller = NavigationRemainingController(now: () => now);
    addTearDown(controller.dispose);
    final estimate = NavigationRemaining.estimate(_route(), 0.5);
    for (final timestamp in [
      now.subtract(const Duration(seconds: 15)),
      now.add(const Duration(seconds: 1))
    ]) {
      controller.update(estimate, fixTime: timestamp);
      expect(controller.value, isNull);
    }
    controller.update(estimate, fixTime: now);
    expect(controller.value, estimate);
    controller.update(null, fixTime: now);
    expect(controller.value, isNull);
    controller.update(estimate, fixTime: now);
    controller.clear();
    expect(controller.value, isNull);
    controller.update(estimate, fixTime: now);
    expect(controller.value, estimate);
    controller.clear();
  });

  testWidgets('partially aged fixes expire at the original freshness deadline',
      (tester) async {
    final now = DateTime.utc(2026, 10, 11);
    final controller = NavigationRemainingController(now: () => now);
    addTearDown(controller.dispose);
    controller.update(NavigationRemaining.estimate(_route(), 0.5),
        fixTime: now.subtract(const Duration(seconds: 12)));
    await tester.pump(const Duration(seconds: 3));
    expect(controller.value, isNull);
  });

  testWidgets('confirmed arrival remains available without further GPS',
      (tester) async {
    final now = DateTime.utc(2026, 10, 11);
    final controller = NavigationRemainingController(now: () => now);
    addTearDown(controller.dispose);
    controller.update(
        NavigationRemaining.estimate(_route(), 0, destinationReached: true),
        fixTime: now);
    await tester.pump(const Duration(minutes: 1));
    expect(controller.value?.hundredsOfMeters, 0);
    controller.clear();
    expect(controller.value, isNull);
  });

  testWidgets(
      'pause freezes values and expiry, then a fresh fix resumes updates',
      (tester) async {
    var now = DateTime.utc(2026, 10, 11);
    final controller = NavigationRemainingController(now: () => now);
    addTearDown(controller.dispose);
    final route = _route();
    final sample = NavigationRemaining.estimate(route, 0.5);
    controller.update(sample, fixTime: now);
    controller.setPaused(true);
    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(minutes: 2));
    controller.update(null, fixTime: now);
    controller.update(NavigationRemaining.estimate(route, 0.25), fixTime: now);
    expect(controller.value, sample);
    controller.setPaused(false);
    // Resuming with no fresh fix expires the retained sample on the next turn.
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.value, isNull);
    controller.update(NavigationRemaining.estimate(route, 0.25), fixTime: now);
    expect(controller.value?.hundredsOfMeters, 3);
    await tester.pump(const Duration(seconds: 15));
    expect(controller.value, isNull);
  });

  testWidgets('route/end invalidation still clears a frozen sample',
      (tester) async {
    final now = DateTime.utc(2026, 10, 11);
    final controller = NavigationRemainingController(now: () => now);
    addTearDown(controller.dispose);
    controller.update(NavigationRemaining.estimate(_route(), 0.5),
        fixTime: now);
    controller.setPaused(true);
    controller.clear();
    expect(controller.value, isNull);
    controller.setPaused(false);
    await tester.pump(const Duration(minutes: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing cancels expiry without a late notification',
      (tester) async {
    final now = DateTime.utc(2026, 10, 11);
    final controller = NavigationRemainingController(now: () => now);
    controller.update(NavigationRemaining.estimate(_route(), 0.5),
        fixTime: now);
    controller.dispose();
    await tester.pump(const Duration(minutes: 1));
    expect(tester.takeException(), isNull);
  });
}
