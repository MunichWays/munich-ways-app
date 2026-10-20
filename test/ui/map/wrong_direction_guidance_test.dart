import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

LatLng at(double meters, [double east = 0]) =>
    LatLng(48 + meters / 111195, 11.5 + east / 74400);

CycleRoute northbound({bool voice = true}) => CycleRoute(
      [at(0), at(100), at(200), at(300)],
      300,
      90,
      supportsVoiceGuidance: voice,
      maneuvers: [
        RouteManeuver(location: at(200), type: 'turn', modifier: 'right'),
        RouteManeuver(location: at(300), type: 'arrive'),
      ],
    );

class Ride {
  final guidance = VoiceGuidance();
  final motion = NavigationMotionTracker();
  final epoch = DateTime(2026, 10, 17, 12);

  void fix(double meters, int seconds, {double accuracy = 5}) {
    final position = at(meters);
    final time = epoch.add(Duration(seconds: seconds));
    motion.update(position, accuracy, now: time);
    guidance.updateTravelDirection(position, motion.bearingAt(time),
        movementStart: motion.movementStart,
        directionConfirmed: motion.directionConfirmed);
  }
}

void main() {
  test('reroute opposing confirmed travel immediately asks to turn around', () {
    final ride = Ride();
    ride.fix(30, 0);
    ride.fix(10, 5);
    ride.guidance.setRoute(northbound());
    // Route replacement refreshes the most recent fix without new movement.
    ride.fix(10, 5);
    expect(ride.guidance.display(at(10), english: false)?.modifier, 'uturn');
    expect(ride.guidance.announceCurrentManeuver(at(10), english: false),
        'Bitte wenden, sobald es sicher möglich ist.');
    expect(ride.guidance.update(at(10), english: false), isNull);
    expect(ride.guidance.remainingEstimate, isNull);
    expect(ride.guidance.isOffRouteForRerouting(at(10)), isFalse);
  });

  test('backwards travel suppresses ordinary speech across consumed progress',
      () {
    final ride = Ride();
    ride.guidance.setRoute(northbound());
    ride.fix(180, 0);
    ride.guidance.resumeAt(at(180));
    ride.fix(160, 5);
    expect(ride.guidance.update(at(160), english: true),
        'When safe, turn around.');
    for (var i = 0; i < 6; i++) {
      final meters = 140.0 - 20 * i;
      ride.fix(meters, 10 + i * 5);
      expect(
          ride.guidance.display(at(meters), english: true)?.modifier, 'uturn');
      expect(ride.guidance.update(at(meters), english: true), isNull);
      expect(ride.guidance.announceCurrentManeuver(at(meters), english: true),
          isNull);
    }
    expect(
        ride.guidance
            .announceCurrentManeuver(at(40), english: true, repeat: true),
        'When safe, turn around.');
  });

  test(
      'turning back reanchors and restores regular instructions and statistics',
      () {
    final ride = Ride();
    ride.guidance.setRoute(northbound());
    ride.guidance.resumeAt(at(220)); // The turn was already consumed.
    ride.fix(100, 0);
    ride.fix(80, 5);
    expect(
        ride.guidance.update(at(80), english: true), contains('turn around'));
    ride.fix(100, 10);
    expect(ride.guidance.display(at(100), english: true)?.modifier, 'right');
    expect(ride.guidance.remainingEstimate, isNotNull);
    expect(ride.guidance.announceCurrentManeuver(at(100), english: true),
        contains('turn right'));
    ride.fix(80, 15);
    expect(
        ride.guidance.update(at(80), english: true), contains('turn around'));
  });

  test('stationary jitter, poor fixes and GPS gaps never invent a direction',
      () {
    final ride = Ride();
    ride.guidance.setRoute(northbound());
    ride.fix(100, 0);
    ride.fix(99, 5);
    ride.fix(101, 10);
    expect(ride.guidance.display(at(101), english: true)?.modifier, 'right');
    ride.fix(80, 15, accuracy: 80);
    ride.fix(60, 20);
    expect(ride.motion.bearingAt(ride.epoch.add(const Duration(seconds: 20))),
        isNull);
    expect(
        ride.guidance.display(at(60), english: true)?.modifier, isNot('uturn'));
    ride.fix(40, 60);
    expect(ride.motion.bearingAt(ride.epoch.add(const Duration(seconds: 60))),
        isNull);
    expect(
        ride.guidance.display(at(40), english: true)?.modifier, isNot('uturn'));
    ride.fix(20, 65);
    expect(
        ride.guidance.display(at(20), english: true)?.modifier, isNot('uturn'));
    // After GPS returns, one displacement can still be an anchor correction.
    // A second agreeing movement confirms a real backwards ride.
    ride.fix(0, 70);
    expect(ride.guidance.display(at(0), english: true)?.modifier, 'uturn');
  });

  test('movement bearing expires and resets with the shared motion source', () {
    final ride = Ride();
    ride.fix(100, 0);
    expect(ride.motion.bearingAt(ride.epoch), isNull);
    ride.fix(80, 5);
    expect(ride.motion.bearingAt(ride.epoch.add(const Duration(seconds: 5))),
        isNotNull);
    expect(ride.motion.bearingAt(ride.epoch.add(const Duration(seconds: 4))),
        isNull);
    expect(ride.motion.bearingAt(ride.epoch.add(const Duration(seconds: 14))),
        isNull);
    ride.fix(500, 15); // Implausible jump.
    expect(ride.motion.bearingAt(ride.epoch.add(const Duration(seconds: 15))),
        isNull);
    ride.fix(480, 20);
    ride.motion.reset();
    expect(ride.motion.bearingAt(ride.epoch.add(const Duration(seconds: 20))),
        isNull);
  });

  test('stopping preserves the warning until confirmed forward travel', () {
    final ride = Ride();
    ride.guidance.setRoute(northbound());
    ride.fix(100, 0);
    ride.fix(80, 5);
    expect(
        ride.guidance.update(at(80), english: true), contains('turn around'));
    ride.fix(80, 30);
    expect(ride.guidance.display(at(80), english: true)?.modifier, 'uturn');
    expect(ride.guidance.update(at(80), english: true), isNull);
    ride.fix(100, 35);
    expect(ride.guidance.display(at(100), english: true)?.modifier, 'right');
  });

  test('spatial departure still invokes the established off-route handling',
      () {
    final ride = Ride();
    ride.guidance.setRoute(northbound());
    ride.fix(10, 0);
    ride.fix(-10, 5);
    expect(
        ride.guidance.update(at(-10), english: true), contains('turn around'));
    ride.fix(-60, 10);
    expect(ride.guidance.display(at(-60), english: true), isNull);
    expect(ride.guidance.isOffRouteForRerouting(at(-60)), isTrue);
    expect(
        ride.guidance.announceCurrentManeuver(at(-60), english: true), isNull);
  });

  test('wrong direction cannot announce arrival while moving away from it', () {
    final ride = Ride();
    ride.guidance.setRoute(northbound());
    ride.guidance.resumeAt(at(290));
    ride.fix(310, 0);
    ride.fix(290, 5);
    expect(ride.guidance.display(at(290), english: true)?.modifier, 'uturn');
    expect(
        ride.guidance.update(at(290), english: true), contains('turn around'));
    expect(ride.guidance.finalDestinationReached, isFalse);
    ride.fix(310, 10);
    expect(ride.guidance.display(at(310), english: true)?.isFinalDestination,
        isTrue);
  });

  test('perpendicular departure and forward travel keep regular guidance', () {
    final guidance = VoiceGuidance()..setRoute(northbound());
    for (final bearing in [0.0, 45.0, 90.0, 270.0, 315.0]) {
      guidance.updateTravelDirection(at(100), bearing);
      expect(guidance.display(at(100), english: true)?.modifier, 'right');
    }
  });

  test(
      'westbound routes use the same direction check across bearing wraparound',
      () {
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute([at(0), at(0, -100), at(0, -200)], 200, 60,
          maneuvers: [
            RouteManeuver(
                location: at(0, -200), type: 'turn', modifier: 'left'),
          ]));
    guidance.updateTravelDirection(at(0, -50), 270);
    expect(guidance.display(at(0, -50), english: true)?.modifier, 'left');
    guidance.updateTravelDirection(at(0, -50), 90);
    expect(guidance.display(at(0, -50), english: true)?.modifier, 'uturn');
    guidance.updateTravelDirection(at(0, -50), -90);
    expect(guidance.display(at(0, -50), english: true)?.modifier, 'left');
  });

  test('unsupported routes retain map-only navigation', () {
    final ride = Ride();
    ride.guidance.setRoute(northbound(voice: false));
    ride.fix(100, 0);
    ride.fix(80, 5);
    expect(ride.guidance.display(at(80), english: true), isNull);
    expect(ride.guidance.update(at(80), english: true), isNull);
    expect(ride.guidance.remainingEstimate, isNotNull);
  });

  test('ambiguous parallel return legs never invent a turn-around', () {
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute([at(0), at(200), at(200, 4), at(0, 4)], 400, 120));
    final before = guidance.display(at(50), english: true);
    guidance.updateTravelDirection(at(50), 180);
    expect(guidance.display(at(50), english: true), before);
    expect(guidance.update(at(50), english: true), isNull);
  });

  test('following a sharp route bend does not invent a turn-around', () {
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute([at(0), at(100), at(0, -60)], 220, 60));
    final motion = NavigationMotionTracker();
    final epoch = DateTime(2026, 10, 17);
    motion.update(at(70), 5, now: epoch);
    final time = epoch.add(const Duration(seconds: 5));
    motion.update(at(95, -3), 5, now: time);
    guidance.updateTravelDirection(at(95, -3), motion.bearingAt(time),
        movementStart: motion.movementStart);
    expect(
        guidance.display(at(95, -3), english: true)?.modifier, isNot('uturn'));
    expect(guidance.update(at(95, -3), english: true),
        isNot(contains('turn around')));
  });

  test('known outbound and return overlap preserves intentional map guidance',
      () {
    final guidance = VoiceGuidance()
      ..setRoute(
        CycleRoute([at(0), at(100), at(200), at(100), at(0)], 400, 120),
        intermediateDestinationNames: ['Stop'],
      );
    guidance.updateTravelDirection(at(50), 180);
    expect(guidance.display(at(50), english: true)?.mapReason,
        VoiceGuidanceMapReason.overlappingRoute);
    expect(
        guidance.update(at(50), english: true), isNot(contains('turn around')));
  });

  test('replacement and navigation end clear the prior direction episode', () {
    final guidance = VoiceGuidance()..setRoute(northbound());
    guidance.updateTravelDirection(at(100), 180);
    expect(guidance.update(at(100), english: true), contains('turn around'));
    guidance.setRoute(northbound());
    expect(guidance.display(at(100), english: true)?.modifier, 'right');
    guidance.updateTravelDirection(at(100), 180);
    guidance.reset();
    expect(guidance.update(at(100), english: true), isNull);
    guidance.setRoute(northbound());
    expect(guidance.display(at(100), english: true)?.modifier, 'right');
  });
}
