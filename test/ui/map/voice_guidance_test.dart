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
      'Jetzt rechts abbiegen.',
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
    expect(now?.text, 'Jetzt rechts');
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
    expect(now?.text, 'Jetzt rechts');
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
    const position = LatLng(48.14028, 11.5700);
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
      'In 70 m links',
    );
  });

  test('formats roundabout and arrival instructions', () {
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
      'Sie haben das Ziel erreicht.',
    );
    expect(guidance.update(end, english: false), isNull);
  });

  test('does not announce arrival outside the 20 metre destination radius', () {
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
      'Sie haben das Ziel erreicht.',
    );
  });
}
