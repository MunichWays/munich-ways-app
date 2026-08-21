import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

void main() {
  const start = LatLng(48.1400, 11.5700);
  const beforeTurn = LatLng(48.1405, 11.5700);
  const turn = LatLng(48.1410, 11.5700);
  const end = LatLng(48.1415, 11.5700);

  CycleRoute routeWith(RouteManeuver maneuver) => CycleRoute(
        const [start, beforeTurn, turn, end],
        170,
        40,
        maneuvers: [maneuver],
      );

  test('holds initial guidance until movement establishes direction', () {
    final gate = NavigationOrientationGate()..reset(start);

    expect(
      gate.isWaiting(
        start,
        horizontalAccuracyMeters: 5,
        speedMetersPerSecond: 0,
      ),
      isTrue,
    );
    expect(
      gate.isWaiting(
        const LatLng(48.14005, 11.5700),
        horizontalAccuracyMeters: 5,
        speedMetersPerSecond: 2,
      ),
      isTrue,
    );
    expect(
      gate.isWaiting(
        const LatLng(48.14010, 11.5700),
        horizontalAccuracyMeters: 5,
        speedMetersPerSecond: 2,
      ),
      isFalse,
    );
  });

  test('uses a distance fallback when GPS speed is unavailable', () {
    final gate = NavigationOrientationGate()..reset(start);

    expect(
      gate.isWaiting(
        const LatLng(48.14010, 11.5700),
        horizontalAccuracyMeters: 8,
        speedMetersPerSecond: 0,
      ),
      isTrue,
    );
    expect(
      gate.isWaiting(
        const LatLng(48.14016, 11.5700),
        horizontalAccuracyMeters: 8,
        speedMetersPerSecond: 0,
      ),
      isFalse,
    );
  });

  test('recognizes route re-entry behind the previous guidance progress', () {
    final guidance = VoiceGuidance()
      ..setRoute(
        routeWith(
          const RouteManeuver(
            location: turn,
            type: 'turn',
            modifier: 'right',
          ),
        ),
      );

    // Stay clearly outside the 20 m destination radius while advancing more
    // than the 120 m local guidance window.
    guidance
      ..display(turn, english: false)
      ..display(const LatLng(48.14125, 11.5700), english: false);

    expect(guidance.isOffRoute(start), isTrue);
    expect(guidance.isOnRouteAnywhere(start), isTrue);
  });

  test('resumes turn guidance when rejoining far from the route start', () {
    const reentry = LatLng(48.1430, 11.5700);
    const laterTurn = LatLng(48.1435, 11.5700);
    const routeEnd = LatLng(48.1440, 11.5700);
    final route = CycleRoute(
      const [start, reentry, laterTurn, routeEnd],
      450,
      100,
      maneuvers: const [
        RouteManeuver(
          location: laterTurn,
          type: 'turn',
          modifier: 'left',
        ),
      ],
    );
    final guidance = VoiceGuidance()..setRoute(route);

    // This position is outside the 120 m progress window of a fresh session.
    expect(guidance.display(reentry, english: false), isNull);

    guidance
      ..reset()
      ..setRoute(route)
      ..resumeAt(reentry);

    expect(
      guidance.display(reentry, english: false),
      isA<VoiceGuidanceDisplay>()
          .having((display) => display.type, 'type', 'turn')
          .having((display) => display.modifier, 'modifier', 'left'),
    );
  });

  test('uses GPS accuracy when resuming after an off-route episode', () {
    const reentry = LatLng(48.1430, 11.5700);
    final guidance = VoiceGuidance()
      ..setRoute(
        CycleRoute(
          const [start, reentry, end],
          400,
          100,
          maneuvers: const [],
        ),
      );
    const impreciseFixNearRoute = LatLng(48.1430, 11.5704);

    expect(guidance.resumeAt(impreciseFixNearRoute), isFalse);
    expect(
      guidance.resumeAt(
        impreciseFixNearRoute,
        horizontalAccuracyMeters: 15,
      ),
      isTrue,
    );
  });

  test('automatically restores guidance after a brief route departure', () {
    const reentry = LatLng(48.1430, 11.5700);
    const laterTurn = LatLng(48.1435, 11.5700);
    const routeEnd = LatLng(48.1440, 11.5700);
    final guidance = VoiceGuidance()
      ..setRoute(
        CycleRoute(
          const [start, reentry, laterTurn, routeEnd],
          450,
          100,
          maneuvers: const [
            RouteManeuver(
              location: laterTurn,
              type: 'turn',
              modifier: 'left',
            ),
          ],
        ),
      );

    guidance
      ..resumeAt(reentry)
      ..display(const LatLng(48.1430, 11.5710), english: false);

    expect(
      guidance.display(reentry, english: false),
      isA<VoiceGuidanceDisplay>()
          .having((display) => display.text, 'text', contains('links'))
          .having((display) => display.type, 'type', 'turn'),
    );
  });

  test('does not derive directions for routes without guidance support', () {
    final guidance = VoiceGuidance()
      ..setRoute(
        CycleRoute(
          const [
            LatLng(48.1000, 11.5000),
            LatLng(48.1000, 11.5010),
            LatLng(48.1010, 11.5010),
          ],
          200,
          60,
          supportsVoiceGuidance: false,
        ),
      );

    const position = LatLng(48.1000, 11.5005);
    expect(guidance.display(position, english: false), isNull);
    expect(guidance.update(position, english: false), isNull);
  });

  test('announces approach and turn only once', () {
    final guidance = VoiceGuidance();
    guidance.setRoute(routeWith(const RouteManeuver(
      location: turn,
      type: 'turn',
      modifier: 'right',
    )));

    expect(
      guidance.update(beforeTurn, english: false),
      'In 60 Metern rechts abbiegen.',
    );
    expect(guidance.update(beforeTurn, english: false), isNull);
    expect(
      guidance.update(const LatLng(48.1409, 11.5700), english: false),
      'Hier rechts abbiegen.',
    );
    expect(
      guidance.update(const LatLng(48.14095, 11.5700), english: false),
      isNull,
    );
  });

  test('provides a short readable instruction for the navigation header', () {
    final guidance = VoiceGuidance();
    guidance.setRoute(routeWith(const RouteManeuver(
      location: turn,
      type: 'turn',
      modifier: 'right',
    )));

    final display = guidance.display(beforeTurn, english: false);
    expect(display?.text, 'In 60 m rechts');
    expect(display?.modifier, 'right');

    final now = guidance.display(
      const LatLng(48.1409, 11.5700),
      english: false,
    );
    expect(now?.text, 'Hier rechts abbiegen');
  });

  test('announces a right-angle corner omitted by the routing service', () {
    const corner = LatLng(48.1410, 11.5700);
    const afterCorner = LatLng(48.1410, 11.5710);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [start, beforeTurn, corner, afterCorner],
        190,
        45,
      ));

    expect(
      guidance.update(beforeTurn, english: false),
      'In 60 Metern rechts abbiegen.',
    );
  });

  test('does not duplicate a routed maneuver at a geometry corner', () {
    const corner = LatLng(48.1410, 11.5700);
    const afterCorner = LatLng(48.1410, 11.5710);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [start, beforeTurn, corner, afterCorner],
        190,
        45,
        maneuvers: const [
          RouteManeuver(
            location: corner,
            type: 'turn',
            modifier: 'right',
          ),
        ],
      ));

    expect(
      guidance.update(beforeTurn, english: false),
      'In 60 Metern rechts abbiegen.',
    );
    expect(
      guidance.update(const LatLng(48.1409, 11.5700), english: false),
      'Hier rechts abbiegen.',
    );
    expect(
      guidance.update(const LatLng(48.1410, 11.5701), english: false),
      isNull,
    );
  });

  test('looks ahead by about eleven metres at normal bicycle speed', () {
    final guidance = VoiceGuidance();
    guidance.setRoute(routeWith(const RouteManeuver(
      location: turn,
      type: 'turn',
      modifier: 'right',
    )));

    final display = guidance.display(
      beforeTurn,
      english: false,
      speedMetersPerSecond: 20 / 3.6,
    );
    expect(display?.text, 'In 40 m rechts');

    final now = guidance.display(
      const LatLng(48.1408, 11.5700),
      english: false,
      speedMetersPerSecond: 20 / 3.6,
    );
    expect(now?.text, 'Hier rechts abbiegen');
  });

  test('keeps guidance nearly unchanged at walking speed', () {
    final guidance = VoiceGuidance();
    guidance.setRoute(routeWith(const RouteManeuver(
      location: turn,
      type: 'turn',
      modifier: 'right',
    )));

    final display = guidance.display(
      beforeTurn,
      english: false,
      speedMetersPerSecond: 1,
    );
    expect(display?.text, 'In 50 m rechts');
  });

  test('announces the approach earlier based on bicycle speed', () {
    const position = LatLng(48.14032, 11.5700);
    final stationaryGuidance = VoiceGuidance()
      ..setRoute(routeWith(const RouteManeuver(
        location: turn,
        type: 'turn',
        modifier: 'left',
      )));
    final movingGuidance = VoiceGuidance()
      ..setRoute(routeWith(const RouteManeuver(
        location: turn,
        type: 'turn',
        modifier: 'left',
      )));

    expect(
      stationaryGuidance.update(position, english: false),
      isNull,
    );
    expect(
      movingGuidance.update(
        position,
        english: false,
        speedMetersPerSecond: 20 / 3.6,
      ),
      'In 60 Metern links abbiegen.',
    );
    expect(
      movingGuidance
          .display(
            position,
            english: false,
            speedMetersPerSecond: 20 / 3.6,
          )
          ?.text,
      'In 60 m links',
    );
  });

  test('formats roundabout and arrival instructions', () {
    expect(
      VoiceGuidance.formatManeuver(
        const RouteManeuver(
          location: turn,
          type: 'turn',
          modifier: 'right',
        ),
        english: true,
        now: true,
      ),
      'Turn right here.',
    );
    expect(
      VoiceGuidance.formatManeuver(
        const RouteManeuver(
          location: turn,
          type: 'roundabout',
          exit: 2,
        ),
        english: false,
        distanceMeters: 50,
      ),
      'In 50 Metern im Kreisverkehr die zweite Ausfahrt nehmen.',
    );
    expect(
      VoiceGuidance.formatManeuver(
        const RouteManeuver(location: end, type: 'arrive'),
        english: true,
        now: true,
      ),
      'You have reached your destination.',
    );
  });

  test('route replacement resets announcement state', () {
    final maneuver = const RouteManeuver(
      location: turn,
      type: 'turn',
      modifier: 'left',
    );
    final guidance = VoiceGuidance()..setRoute(routeWith(maneuver));
    expect(guidance.update(beforeTurn, english: true), isNotNull);

    guidance.setRoute(routeWith(maneuver));
    expect(guidance.update(beforeTurn, english: true), isNotNull);
  });

  test('does not announce while rider is on a parallel path off route', () {
    final guidance = VoiceGuidance();
    guidance.setRoute(routeWith(const RouteManeuver(
      location: turn,
      type: 'turn',
      modifier: 'left',
    )));

    // Roughly 40 metres east of the route at Munich's latitude.
    expect(
      guidance.update(
        const LatLng(48.1405, 11.57054),
        english: false,
      ),
      isNull,
    );
    expect(
      guidance.display(
        const LatLng(48.1405, 11.57054),
        english: false,
      ),
      isNull,
    );
    expect(
      guidance.update(beforeTurn, english: false),
      'In 60 Metern links abbiegen.',
    );
  });

  test('warns once after repeated positions off the route', () {
    final guidance = VoiceGuidance();
    guidance.setRoute(routeWith(const RouteManeuver(
      location: turn,
      type: 'turn',
      modifier: 'left',
    )));
    const offRoute = LatLng(48.1405, 11.57054);

    for (var update = 0; update < 9; update++) {
      expect(guidance.update(offRoute, english: false), isNull);
    }
    expect(
      guidance.update(offRoute, english: false),
      'Keine Ansage. Route möglicherweise verlassen oder kein GPS-Signal.',
    );
    expect(guidance.update(offRoute, english: false), isNull);
  });

  test('combines two closely spaced turns in one announcement', () {
    const secondTurn = LatLng(48.1410, 11.5703);
    const afterSecondTurn = LatLng(48.1413, 11.5698);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [start, beforeTurn, turn, secondTurn, afterSecondTurn],
        170,
        40,
        maneuvers: const [
          RouteManeuver(
            location: turn,
            type: 'turn',
            modifier: 'right',
          ),
          RouteManeuver(
            location: secondTurn,
            type: 'turn',
            modifier: 'left',
          ),
        ],
      ));

    expect(
      guidance.update(beforeTurn, english: false),
      'In 60 Metern rechts abbiegen, danach sofort links abbiegen.',
    );
  });

  test('ignores the offset straight crossing at Balanstraße', () {
    const startOnCyclePath = LatLng(48.104805, 11.605651);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [
          LatLng(48.104810, 11.605648),
          LatLng(48.104772, 11.605490),
          LatLng(48.104770, 11.605477),
          LatLng(48.104724, 11.605284),
          LatLng(48.104743, 11.605201),
          LatLng(48.104719, 11.605100),
          LatLng(48.104691, 11.604985),
          LatLng(48.104650, 11.604948),
          LatLng(48.104568, 11.604590),
          LatLng(48.104562, 11.604566),
          LatLng(48.104485, 11.604226),
          LatLng(48.104425, 11.603980),
        ],
        133.7,
        32.1,
        maneuvers: const [
          RouteManeuver(
            location: LatLng(48.104743, 11.605201),
            type: 'turn',
            modifier: 'left',
          ),
          RouteManeuver(
            location: LatLng(48.104650, 11.604948),
            type: 'turn',
            modifier: 'slight right',
          ),
        ],
      ));

    expect(guidance.display(startOnCyclePath, english: false), isNull);
    expect(guidance.update(startOnCyclePath, english: false), isNull);
  });

  test('treats the shallow Lautensackstrasse cycle-path entry as slight right',
      () {
    const routeStart = LatLng(48.138215, 11.517741);
    const cyclePathEntry = LatLng(48.138692, 11.517890);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [
          routeStart,
          LatLng(48.138620, 11.517868),
          cyclePathEntry,
          LatLng(48.138733, 11.517973),
          LatLng(48.138905, 11.518033),
          LatLng(48.139006, 11.518223),
          LatLng(48.139153, 11.518281),
          LatLng(48.139328, 11.518345),
          LatLng(48.139556, 11.518421),
        ],
        162.6,
        35.9,
        maneuvers: const [
          RouteManeuver(
            location: cyclePathEntry,
            type: 'turn',
            modifier: 'right',
          ),
        ],
      ));

    expect(
      guidance.display(routeStart, english: false)?.text,
      'In 50 m leicht rechts',
    );
    expect(
      guidance.display(cyclePathEntry, english: false)?.text,
      'Hier leicht rechts halten',
    );
  });

  test('announces arrival independently of route progress projection', () {
    final guidance = VoiceGuidance();
    guidance.setRoute(CycleRoute(
      const [start, beforeTurn, turn, end],
      170,
      40,
      maneuvers: const [
        RouteManeuver(location: end, type: 'arrive'),
      ],
    ));

    expect(
      guidance.update(end, english: false),
      'Du hast das Ziel erreicht.',
    );
    expect(guidance.update(end, english: false), isNull);
  });

  test('keeps final arrival latched and disables off-route handling', () {
    final guidance = VoiceGuidance();
    guidance.setRoute(CycleRoute(
      const [start, beforeTurn, turn, end],
      170,
      40,
      maneuvers: const [
        RouteManeuver(location: end, type: 'arrive'),
      ],
    ));

    final arrival = guidance.display(end, english: false);
    expect(arrival?.text, 'Ziel erreicht');
    expect(arrival?.isFinalDestination, isTrue);
    expect(guidance.finalDestinationReached, isTrue);
    expect(
      guidance.update(end, english: false),
      'Du hast das Ziel erreicht.',
    );

    const afterDestination = LatLng(48.1430, 11.5700);
    expect(guidance.isOffRoute(afterDestination), isFalse);
    expect(
      guidance.display(afterDestination, english: false),
      const VoiceGuidanceDisplay(
        text: 'Ziel erreicht',
        type: 'arrive',
        isFinalDestination: true,
      ),
    );
    expect(guidance.update(afterDestination, english: false), isNull);
  });

  test('announces a named intermediate destination separately', () {
    const intermediate = LatLng(48.1410, 11.5690);
    final guidance = VoiceGuidance();
    guidance.setRoute(
      CycleRoute(
        const [start, intermediate, end],
        200,
        50,
        maneuvers: const [
          RouteManeuver(location: intermediate, type: 'arrive'),
          RouteManeuver(location: end, type: 'arrive'),
        ],
      ),
      intermediateDestinationNames: const ['Marienplatz'],
    );

    expect(
      guidance.update(intermediate, english: false),
      'Du hast das Zwischenziel 1, Marienplatz, erreicht.',
    );
    expect(guidance.update(intermediate, english: false), isNull);
    expect(
      guidance.update(end, english: false),
      'Du hast das Ziel erreicht.',
    );
  });

  test('announces the map number before a named intermediate destination', () {
    const stop1 = LatLng(48.1405, 11.5700);
    const stop2 = LatLng(48.1410, 11.5700);
    const stop3 = LatLng(48.1415, 11.5700);
    final guidance = VoiceGuidance()
      ..setRoute(
        CycleRoute(
          const [start, stop1, stop2, stop3, end],
          300,
          60,
          maneuvers: const [
            RouteManeuver(location: stop1, type: 'arrive'),
            RouteManeuver(location: stop2, type: 'arrive'),
            RouteManeuver(location: stop3, type: 'arrive'),
            RouteManeuver(location: end, type: 'arrive'),
          ],
        ),
        intermediateDestinationNames: const [null, null, 'Marienplatz'],
      );

    expect(
      guidance.update(stop1, english: false),
      'Du hast das Zwischenziel 1 erreicht.',
    );
    expect(
      guidance.update(stop2, english: false),
      'Du hast das Zwischenziel 2 erreicht.',
    );
    expect(
      guidance.update(stop3, english: false),
      'Du hast das Zwischenziel 3, Marienplatz, erreicht.',
    );
  });

  test('uses the 20 metre radius for final arrival', () {
    final guidance = VoiceGuidance();
    guidance.setRoute(CycleRoute(
      const [start, end],
      170,
      40,
      maneuvers: const [
        RouteManeuver(location: end, type: 'arrive'),
      ],
    ));

    const aboutTwentyFiveMetresBeforeEnd = LatLng(48.14127, 11.5700);
    expect(
      guidance.update(aboutTwentyFiveMetresBeforeEnd, english: false),
      isNull,
    );
    expect(
      guidance.update(end, english: false),
      'Du hast das Ziel erreicht.',
    );
  });

  test('final arrival takes precedence over an off-route classification', () {
    final guidance = VoiceGuidance(maximumRouteDistanceMeters: 10)
      ..setRoute(CycleRoute(
        const [start, end],
        170,
        40,
        maneuvers: const [RouteManeuver(location: end, type: 'arrive')],
      ));

    const nearAddressButOffRoute = LatLng(48.14142, 11.57015);
    expect(
      guidance.update(nearAddressButOffRoute, english: false),
      'Du hast das Ziel erreicht.',
    );
  });

  test('keeps an intermediate stop and restores a missing final arrival', () {
    const intermediate = LatLng(48.1410, 11.5700);
    const cyclingEnd = LatLng(48.1414, 11.5700);
    const destination = LatLng(48.1415, 11.5700);
    final guidance = VoiceGuidance()
      ..setRoute(
        CycleRoute(
          const [start, intermediate, cyclingEnd],
          170,
          40,
          maneuvers: const [
            RouteManeuver(location: intermediate, type: 'arrive'),
          ],
          destinationConnector: const [cyclingEnd, destination],
        ),
        intermediateDestinationNames: const ['Marienplatz'],
      );

    expect(
      guidance.update(intermediate, english: false),
      'Du hast das Zwischenziel 1, Marienplatz, erreicht.',
    );
    expect(
      guidance.update(destination, english: false),
      'Du hast das Ziel erreicht.',
    );
  });

  test('GPS accuracy increases the off-route tolerance up to 25 metres', () {
    final guidance = VoiceGuidance()
      ..setRoute(routeWith(const RouteManeuver(
        location: turn,
        type: 'turn',
        modifier: 'left',
      )));
    const roughlyFortyMetresOffRoute = LatLng(48.1405, 11.57054);

    expect(guidance.isOffRoute(roughlyFortyMetresOffRoute), isTrue);
    expect(
      guidance.isOffRoute(
        roughlyFortyMetresOffRoute,
        horizontalAccuracyMeters: 20,
      ),
      isFalse,
    );
  });

  test('off-route detection checks the whole route after progress advanced',
      () {
    const routeStart = LatLng(48.1400, 11.5700);
    const routeMiddle = LatLng(48.1410, 11.5700);
    const routeEnd = LatLng(48.1420, 11.5700);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [routeStart, routeMiddle, routeEnd],
        220,
        50,
        maneuvers: const [
          RouteManeuver(
            location: routeEnd,
            type: 'turn',
            modifier: 'left',
          ),
        ],
      ));

    // Establish progress near the end, then simulate a corrected GPS fix on
    // an earlier portion of the same route. This must not create a false
    // off-route episode merely because guidance progress is monotonic.
    guidance
      ..display(routeMiddle, english: false)
      ..display(const LatLng(48.14175, 11.5700), english: false);

    expect(guidance.isOffRoute(routeStart), isTrue);
    expect(guidance.isOnRouteAnywhere(routeStart), isTrue);
    expect(guidance.isOffRouteForRerouting(routeStart), isFalse);
  });

  test('does not jump to a later route section on another OSM level', () {
    const lowerRampStart = LatLng(48.14000, 11.57000);
    const lowerRampMiddle = LatLng(48.14000, 11.57075);
    const rampEnd = LatLng(48.14000, 11.57150);
    const bridgeEntry = LatLng(48.14004, 11.57000);
    const bridge = LatLng(48.14004, 11.56950);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [
          lowerRampStart,
          lowerRampMiddle,
          rampEnd,
          bridgeEntry,
          bridge,
        ],
        300,
        90,
        maneuvers: const [
          RouteManeuver(
            location: bridgeEntry,
            type: 'turn',
            modifier: 'right',
          ),
        ],
      ));

    // The later bridge section is only about four metres away in 2D, but
    // more than 200 metres ahead along the ramp.
    expect(
      guidance.display(lowerRampStart, english: false)?.text,
      isNot('Hier rechts abbiegen'),
    );
    expect(guidance.update(lowerRampStart, english: false), isNull);
    expect(guidance.isOffRoute(lowerRampMiddle), isFalse);
    expect(guidance.update(lowerRampMiddle, english: false), isNull);
  });

  test('shows map guidance when two nearby route levels are ambiguous', () {
    const upperRampStart = LatLng(48.13970, 11.57080);
    const upperRampAtRoad = LatLng(48.14000, 11.57100);
    const outerRamp = LatLng(48.14030, 11.57120);
    const lowerRoadAtRamp = LatLng(48.14004, 11.57100);
    const lowerRoadAfterTurn = LatLng(48.14004, 11.57050);
    const gpsNearLowerRoad = LatLng(48.140035, 11.57100);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [
          upperRampStart,
          upperRampAtRoad,
          outerRamp,
          lowerRoadAtRamp,
          lowerRoadAfterTurn,
        ],
        300,
        90,
        maneuvers: const [
          RouteManeuver(
            location: lowerRoadAtRamp,
            type: 'turn',
            modifier: 'left',
          ),
        ],
      ));

    // The GPS fix is about half a metre from the later lower road, but only
    // about four metres from the current upper ramp. Both are plausible in
    // 2D, so route continuity must win over the marginally closer section.
    expect(
      guidance.display(gpsNearLowerRoad, english: false)?.text,
      'Auf Karte achten',
    );
    expect(guidance.update(gpsNearLowerRoad, english: false), isNull);
  });

  test('keeps maneuvers in route order on an overlapping return section', () {
    const junction = LatLng(48.1400, 11.5710);
    const intermediate = LatLng(48.1400, 11.5720);
    const destination = LatLng(48.1400, 11.5690);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [start, junction, intermediate, junction, destination],
        300,
        70,
        maneuvers: const [
          RouteManeuver(
            location: junction,
            type: 'turn',
            modifier: 'right',
          ),
          RouteManeuver(location: intermediate, type: 'arrive'),
          RouteManeuver(
            location: junction,
            type: 'turn',
            modifier: 'left',
          ),
          RouteManeuver(location: destination, type: 'arrive'),
        ],
      ));

    expect(
      guidance.update(intermediate, english: false),
      'Du hast das Zwischenziel 1 erreicht.',
    );
    expect(
      guidance.display(junction, english: false)?.text,
      'Hier links abbiegen',
    );
  });

  test('does not reach the final destination before an overlapping stop', () {
    const intermediate = LatLng(48.1400, 11.5720);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [start, intermediate, start],
        300,
        70,
        maneuvers: const [
          RouteManeuver(location: intermediate, type: 'arrive'),
          RouteManeuver(location: start, type: 'arrive'),
        ],
      ));

    expect(guidance.update(start, english: false), isNull);
    expect(
      guidance.update(intermediate, english: false),
      'Du hast das Zwischenziel 1 erreicht.',
    );
    expect(
      guidance.update(start, english: false),
      'Du hast das Ziel erreicht.',
    );
  });

  test('only suppresses directions on an overlapping route section', () {
    const intermediate = LatLng(48.1400, 11.5720);
    final guidance = VoiceGuidance();
    guidance.setRoute(
      CycleRoute(
        const [start, beforeTurn, intermediate, beforeTurn, end],
        300,
        70,
      ),
      intermediateDestinationNames: const ['Zwischenziel'],
    );

    expect(guidance.display(start, english: false)?.type, isNot('map'));
    expect(guidance.update(start, english: false), isNot(contains('Karte')));

    expect(
      guidance.display(beforeTurn, english: false)?.text,
      'Auf Karte achten',
    );
    expect(
      guidance.update(beforeTurn, english: false),
      'Hin- und Rückweg sind hier gleich. Auf Karte achten.',
    );
    expect(guidance.update(beforeTurn, english: false), isNull);

    expect(guidance.display(end, english: false)?.type, isNot('map'));
  });
}
