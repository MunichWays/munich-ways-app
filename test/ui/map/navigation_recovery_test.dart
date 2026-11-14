import 'dart:convert';
import 'dart:io';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

void main() {
  final startTime = DateTime(2026, 9, 12, 12);
  LatLng at(double meters) => LatLng(48 + meters / 111195, 11.5);
  DateTime time(int seconds) => startTime.add(Duration(seconds: seconds));

  bool retryDue(
          {bool navigation = true,
          bool automatic = true,
          bool suspended = false,
          bool inFlight = false,
          bool fresh = true,
          bool moving = true,
          bool arrived = false,
          bool expired = true,
          DateTime? retryAt,
          int seconds = 60}) =>
      automaticRerouteRecoveryDue(
          navigationActive: navigation,
          automaticEnabled: automatic,
          suspended: suspended,
          inFlight: inFlight,
          freshFix: fresh,
          moving: moving,
          destinationReached: arrived,
          committedTimerElapsed: expired,
          retryAt: retryAt,
          now: time(seconds));

  test(
      'expired committed timer resumes after stop or GPS loss, never in parallel',
      () {
    expect(retryDue(), isTrue);
    expect(retryDue(moving: false), isFalse);
    expect(retryDue(fresh: false), isFalse);
    expect(retryDue(inFlight: true), isFalse);
    expect(retryDue(expired: false), isFalse);
    expect(retryDue(automatic: false), isFalse);
    expect(retryDue(suspended: true), isFalse);
    expect(retryDue(navigation: false), isFalse);
    expect(retryDue(arrived: true), isFalse);
  });

  test('failed request retries after cooldown and restored moving GPS', () {
    final retryAt = time(90);
    expect(retryDue(retryAt: retryAt, seconds: 89), isFalse);
    expect(retryDue(retryAt: retryAt, seconds: 90, moving: false), isFalse);
    expect(retryDue(retryAt: retryAt, seconds: 100, fresh: false), isFalse);
    expect(retryDue(retryAt: retryAt, seconds: 110), isTrue);
    expect(retryDue(retryAt: retryAt, seconds: 110, suspended: true), isFalse);
    expect(retryDue(retryAt: retryAt, seconds: 110, inFlight: true), isFalse);
  });

  test('timer cannot keep using stale moving state without new fixes', () {
    final motion = NavigationMotionTracker();
    motion.update(at(0), 5, now: time(0));
    motion.update(at(20), 5, now: time(5));
    expect(motion.isMovingAt(time(10)), isTrue);
    expect(motion.isMovingAt(time(14)), isFalse);
    motion.update(at(40), 5, now: time(15));
    expect(motion.isMovingAt(time(15)), isTrue);
  });

  test('GPS gap over 200m rebases and detects subsequent riding', () {
    final motion = NavigationMotionTracker();
    motion.update(at(0), 5, now: time(0));
    expect(motion.update(at(20), 5, now: time(5)).moving, isTrue);
    final afterGap = motion.update(at(350), 5, now: time(65));
    expect(afterGap.moving, isFalse);
    expect(afterGap.confirmedMeters, 0);
    expect(afterGap.movingDuration, Duration.zero);
    final resumed = motion.update(at(370), 5, now: time(70));
    expect(resumed.moving, isTrue);
    expect(resumed.confirmedMeters, closeTo(20, 1));
  });

  for (final interruption in ['gap', 'jump', 'poor fix']) {
    test(
        'direction needs agreeing movements after $interruption, motion does not',
        () {
      final motion = NavigationMotionTracker();
      motion.update(at(0), 5, now: time(0));
      motion.update(at(20), 5, now: time(5));
      expect(motion.bearingAt(time(5)), isNotNull);
      final anchor = interruption == 'jump' ? 500.0 : 100.0;
      if (interruption == 'poor fix') {
        motion.update(at(80), 80, now: time(60));
      }
      final recoveredAt = interruption == 'jump' ? 10 : 65;
      expect(
          motion.update(at(anchor), 5, now: time(recoveredAt)).moving, isFalse);
      expect(motion.bearingAt(time(recoveredAt)), isNull);
      expect(motion.directionConfirmed, isFalse);

      // A backwards correction is movement, but not yet a reliable direction.
      final firstAt = recoveredAt + 5;
      expect(
          motion.update(at(anchor - 20), 5, now: time(firstAt)).moving, isTrue);
      expect(motion.bearingAt(time(firstAt)), isNotNull);
      expect(motion.directionConfirmed, isFalse);
      // An identical fix must not count as another confirmation.
      motion.update(at(anchor - 20), 5, now: time(firstAt));
      expect(motion.directionConfirmed, isFalse);
      motion.update(at(anchor), 5, now: time(firstAt + 5));
      expect(motion.directionConfirmed, isFalse);
      motion.update(at(anchor + 20), 5, now: time(firstAt + 10));
      expect(motion.bearingAt(time(firstAt + 10)), closeTo(0, 1));
      expect(motion.directionConfirmed, isTrue);
      expect(motion.bearingAt(time(firstAt + 19)), isNull);
    });
  }

  test('isolated jump and correction do not count as movement', () {
    final motion = NavigationMotionTracker();
    motion.update(at(0), 5, now: time(0));
    expect(motion.update(at(500), 5, now: time(1)).moving, isFalse);
    expect(motion.update(at(0), 5, now: time(2)).moving, isFalse);
    expect(motion.update(at(0), 5, now: time(3)).confirmedMeters, 0);
    expect(motion.update(at(20), 5, now: time(7)).moving, isTrue);
  });

  test('poor accuracy, stale fixes and reset cannot contribute progress', () {
    final motion = NavigationMotionTracker();
    motion.update(at(0), 5, now: time(0));
    expect(motion.update(at(20), 5, now: time(5)).moving, isTrue);
    expect(motion.update(at(40), 5, now: time(5)).confirmedMeters, 0);
    expect(motion.update(at(40), 80, now: time(10)).moving, isFalse);
    expect(motion.update(at(80), 5, now: time(15)).confirmedMeters, 0);
    expect(motion.update(at(100), 5, now: time(20)).moving, isTrue);
    motion.reset();
    expect(motion.update(at(120), 5, now: time(25)).moving, isFalse);
  });

  test('stop and GPS gap pause an unresolved episode without forgetting it',
      () {
    final motion = NavigationMotionTracker();
    final gate = StalledGuidanceRecoveryGate();
    bool fix(int seconds, double meters) => gate.update(
        stalled: true,
        motion: motion.update(at(meters), 5, now: time(seconds)));
    expect(fix(0, 0), isFalse);
    expect(fix(10, 20), isFalse);
    expect(fix(20, 40), isFalse);
    // Stop. The wait is not treated as riding time.
    expect(fix(30, 40), isFalse);
    expect(fix(40, 40), isFalse);
    // GPS returns much later, 350m further on: no credit for the gap.
    expect(fix(100, 390), isFalse);
    expect(fix(105, 410), isFalse);
    expect(fix(110, 430), isTrue);
  });

  test('off-route and ambiguous and missing states share one recovery budget',
      () {
    final gate = StalledGuidanceRecoveryGate();
    const step = NavigationMotionSample(
        moving: true,
        confirmedMeters: 12,
        movingDuration: Duration(seconds: 10));
    bool update(VoiceGuidanceDisplay? display, {bool offRoute = false}) =>
        gate.update(
            stalled: recoverableGuidanceStall(display,
                    voiceGuidanceAvailable: true, offRoute: offRoute) !=
                null,
            motion: step);
    expect(update(null), isFalse);
    expect(update(null, offRoute: true), isFalse);
    expect(
        update(const VoiceGuidanceDisplay(
            text: 'Any localized text',
            type: 'map',
            mapReason: VoiceGuidanceMapReason.ambiguousPosition)),
        isFalse);
    expect(update(null), isTrue);
    // A new attempt needs its own complete movement/time budget.
    expect(update(null), isFalse);
  });

  test(
      'a healthy instruction ends the episode; stationary drift never opens it',
      () {
    final gate = StalledGuidanceRecoveryGate();
    const progress = NavigationMotionSample(
        moving: true,
        confirmedMeters: 100,
        movingDuration: Duration(seconds: 20));
    gate.update(stalled: true, motion: progress);
    gate.update(stalled: true, motion: progress);
    gate.update(stalled: false, motion: progress);
    expect(gate.update(stalled: true, motion: progress), isFalse);
    expect(gate.update(stalled: true, motion: const NavigationMotionSample()),
        isFalse);
    expect(gate.update(stalled: true, motion: progress), isFalse);
  });

  test('healthy final straight and intentional map states do not trigger', () {
    expect(
        recoverableGuidanceStall(null,
            voiceGuidanceAvailable: true, healthyMapProgress: true),
        isNull);
    expect(
        recoverableGuidanceStall(null, voiceGuidanceAvailable: false), isNull);
    for (final reason in [
      VoiceGuidanceMapReason.navigationStart,
      VoiceGuidanceMapReason.trackingInterrupted,
      VoiceGuidanceMapReason.overlappingRoute
    ]) {
      expect(
          recoverableGuidanceStall(
              VoiceGuidanceDisplay(
                  text: 'Watch map', type: 'map', mapReason: reason),
              voiceGuidanceAvailable: true),
          isNull);
    }
    expect(
        recoverableGuidanceStall(
            const VoiceGuidanceDisplay(
                text: 'Watch map',
                type: 'map',
                mapReason: VoiceGuidanceMapReason.noInstruction),
            voiceGuidanceAvailable: true),
        VoiceGuidanceStallReason.missingInstruction);
  });

  CycleRoute route() =>
      CycleRoute([at(0), at(300), at(600), at(1000)], 1000, 240,
          maneuvers: [
            RouteManeuver(location: at(600), type: 'turn', modifier: 'left')
          ]);

  test(
      'GPS returns beyond local matching window: recover and announce next turn',
      () {
    final guidance = VoiceGuidance()..setRoute(route());
    guidance.display(at(0), english: false);
    expect(guidance.display(at(350), english: false), isNull);
    expect(guidance.hasHealthyMapProgress(at(350)), isFalse);
    final result = guidance.recoverGuidance(at(350),
        horizontalAccuracyMeters: 5, english: false);
    expect(result.requiresReroute, isFalse);
    expect(result.display?.type, 'turn');
    expect(
        guidance.announceCurrentManeuver(at(350), english: false), isNotNull);
    expect(guidance.display(at(400), english: false)?.type, 'turn');
  });

  test('Laimer tunnel resumes promptly after two confirmed GPS fixes', () {
    // Frozen Standard route fetched 2026-11-14 for the reported ride.
    final data = jsonDecode(
            File('test/fixtures/laimer_tunnel_route.json').readAsStringSync())
        as Map<String, dynamic>;
    final route = RadlNaviApi().parseResponse(data, const [
      LatLng(48.143538, 11.502751),
      LatLng(48.147033, 11.504913),
    ]);
    final guidance = VoiceGuidance()..setRoute(route);
    // Last accepted fix before the gap, then GPS resumes near the northern exit.
    const before = LatLng(48.143893, 11.503114);
    const after = LatLng(48.146649, 11.503083);
    guidance.recoverAfterGpsGap(before,
        fixTime: time(0), horizontalAccuracyMeters: 5);
    guidance.display(before, english: false);
    guidance.update(before, english: false);
    expect(
        guidance.recoverAfterGpsGap(after,
            fixTime: time(60), horizontalAccuracyMeters: 5),
        isFalse);
    expect(
        guidance.isOnRouteAnywhere(after, horizontalAccuracyMeters: 5), isTrue);
    expect(guidance.display(after, english: false), isNull);
    expect(guidance.update(after, english: false), isNull);
    expect(guidance.hasHealthyMapProgress(after), isFalse);
    const confirmed = LatLng(48.14676, 11.503086);
    expect(
        guidance.recoverAfterGpsGap(confirmed,
            fixTime: time(62), horizontalAccuracyMeters: 5),
        isTrue);
    expect(guidance.display(confirmed, english: false)?.modifier, 'right');
    expect(guidance.announceCurrentManeuver(confirmed, english: false),
        contains('rechts'));
    expect(
        guidance.recoverAfterGpsGap(confirmed,
            fixTime: time(63), horizontalAccuracyMeters: 5),
        isFalse);
  });

  for (final scenario in [
    'no gap',
    'stationary',
    'reverse',
    'poor accuracy',
    'off route',
    'ambiguous',
    'expired',
    'reroute in flight',
    'duplicate fix'
  ]) {
    test('GPS gap recovery rejects $scenario', () {
      final r = scenario == 'ambiguous'
          ? CycleRoute([at(0), at(1000), at(0)], 2000, 480,
              maneuvers: [
                RouteManeuver(location: at(600), type: 'turn', modifier: 'left')
              ])
          : route();
      final guidance = VoiceGuidance()..setRoute(r);
      guidance.recoverAfterGpsGap(at(0),
          fixTime: time(0), horizontalAccuracyMeters: 5);
      guidance.display(at(0), english: false);
      final firstTime = scenario == 'no gap' ? 2 : 60;
      expect(
          guidance.recoverAfterGpsGap(at(350),
              fixTime: time(firstTime), horizontalAccuracyMeters: 5),
          isFalse);
      final position = switch (scenario) {
        'stationary' => at(350),
        'reverse' => at(335),
        'off route' => const LatLng(48.0033, 11.501),
        _ => at(365),
      };
      expect(
          guidance.recoverAfterGpsGap(position,
              fixTime: time(scenario == 'expired'
                  ? 80
                  : scenario == 'duplicate fix'
                      ? firstTime
                      : firstTime + 2),
              horizontalAccuracyMeters: scenario == 'poor accuracy' ? 40 : 5,
              allowRecovery: scenario != 'reroute in flight'),
          isFalse);
    });
  }

  test(
      'short forward fixes accumulate and route replacement clears GPS recovery',
      () {
    final guidance = VoiceGuidance()..setRoute(route());
    guidance.recoverAfterGpsGap(at(0),
        fixTime: time(0), horizontalAccuracyMeters: 5);
    guidance.display(at(0), english: false);
    expect(
        guidance.recoverAfterGpsGap(at(350),
            fixTime: time(60), horizontalAccuracyMeters: 5),
        isFalse);
    expect(
        guidance.recoverAfterGpsGap(at(354),
            fixTime: time(61), horizontalAccuracyMeters: 5),
        isFalse);
    expect(
        guidance.recoverAfterGpsGap(at(359),
            fixTime: time(62), horizontalAccuracyMeters: 5),
        isTrue);
    guidance.setRoute(route());
    expect(
        guidance.recoverAfterGpsGap(at(370),
            fixTime: time(63), horizontalAccuracyMeters: 5),
        isFalse);
  });

  test('failed re-anchor requests rerouting instead of silently giving up', () {
    final guidance = VoiceGuidance()..setRoute(route());
    final result = guidance.recoverGuidance(const LatLng(48.003, 11.51),
        horizontalAccuracyMeters: 5, english: false);
    expect(result.requiresReroute, isTrue);
    // A successful replacement route restores normal instructions.
    guidance.setRoute(route());
    expect(
        guidance
            .recoverGuidance(at(100),
                horizontalAccuracyMeters: 5, english: false)
            .requiresReroute,
        isFalse);
  });

  test('successful re-anchor but still missing guidance requests rerouting',
      () {
    final guidance = VoiceGuidance()..setRoute(route());
    // 35m beside the route: accepted by accuracy-aware resumeAt (50m),
    // but not sufficiently close for a safe maneuver (25m).
    const position = LatLng(48.003, 11.50047);
    expect(guidance.resumeAt(position, horizontalAccuracyMeters: 25), isTrue);
    final result = guidance.recoverGuidance(position,
        horizontalAccuracyMeters: 25, english: false);
    expect(result.display, isNull);
    expect(result.requiresReroute, isTrue);
  });

  test('a final straight needs no invented maneuver or network request', () {
    final guidance = VoiceGuidance()..setRoute(route());
    final result = guidance.recoverGuidance(at(750),
        horizontalAccuracyMeters: 5, english: false);
    expect(result.display, isNull);
    expect(guidance.hasHealthyMapProgress(at(750)), isTrue);
    expect(result.requiresReroute, isFalse);
  });
}
