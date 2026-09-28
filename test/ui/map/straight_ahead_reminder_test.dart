import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

void main() {
  const start = LatLng(48.14, 11.57);

  CycleRoute routeToTurn(double latitudeDelta) {
    final midpoint =
        LatLng(start.latitude + latitudeDelta / 2, start.longitude);
    final turn = LatLng(start.latitude + latitudeDelta, start.longitude);
    final end = LatLng(turn.latitude, turn.longitude + 0.001);
    return CycleRoute(
      [start, midpoint, turn, end],
      900,
      100,
      maneuvers: [
        RouteManeuver(location: turn, type: 'turn', modifier: 'right'),
      ],
    );
  }

  void advanceSilently(
    VoiceGuidance guidance,
    double fromDelta,
    double toDelta, {
    bool english = false,
  }) {
    for (var delta = fromDelta + 0.0008; delta < toDelta; delta += 0.0008) {
      expect(
        guidance.update(
          LatLng(start.latitude + delta, start.longitude),
          english: english,
        ),
        isNull,
      );
    }
  }

  test('reminds once halfway to a turn about 800 metres away', () {
    final route = routeToTurn(0.0072);
    final guidance = VoiceGuidance()..setRoute(route);
    final beforeMidpoint = LatLng(start.latitude + 0.0034, start.longitude);
    final midpoint = route.points[1];
    final nearTurn = LatLng(start.latitude + 0.0067, start.longitude);

    expect(guidance.update(start, english: false), isNull);
    advanceSilently(guidance, 0, 0.0034);
    expect(guidance.update(beforeMidpoint, english: false), isNull);
    expect(
      guidance.update(midpoint, english: false),
      'Weiter geradeaus, in 400 Metern rechts abbiegen.',
    );
    expect(guidance.update(midpoint, english: false), isNull);
    advanceSilently(guidance, 0.0036, 0.0067);
    expect(
      guidance.update(nearTurn, english: false),
      'In 60 Metern rechts abbiegen.',
    );
    expect(guidance.update(nearTurn, english: false), isNull);
  });

  test('does not remind on a section shorter than 500 metres', () {
    final route = routeToTurn(0.0043);
    final guidance = VoiceGuidance()..setRoute(route);

    expect(guidance.resumeAt(route.points[1]), isTrue);
    expect(guidance.update(route.points[1], english: false), isNull);
  });

  test('uses English and resets the reminder when the route changes', () {
    final route = routeToTurn(0.0072);
    final guidance = VoiceGuidance()..setRoute(route);

    advanceSilently(guidance, 0, 0.0036, english: true);
    expect(
      guidance.update(route.points[1], english: true),
      'Continue straight. In 400 meters, turn right.',
    );
    expect(guidance.update(route.points[1], english: true), isNull);
    guidance.setRoute(routeToTurn(0.0072));
    advanceSilently(guidance, 0, 0.0036, english: true);
    expect(
      guidance.update(route.points[1], english: true),
      'Continue straight. In 400 meters, turn right.',
    );
  });

  test('reminds halfway to a distant destination without a turn', () {
    const destination = LatLng(48.1472, 11.57);
    const midpoint = LatLng(48.1436, 11.57);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [start, midpoint, destination],
        800,
        100,
        maneuvers: const [
          RouteManeuver(location: destination, type: 'arrive'),
        ],
      ));

    advanceSilently(guidance, 0, 0.0036);
    expect(
      guidance.update(midpoint, english: false),
      'Weiter geradeaus, in 400 Metern erreichst du dein Ziel.',
    );
    expect(guidance.update(midpoint, english: false), isNull);
  });

  test('a late position jump leaves priority to the approach announcement', () {
    final route = routeToTurn(0.0072);
    final guidance = VoiceGuidance()..setRoute(route);
    final nearTurn = LatLng(start.latitude + 0.0067, start.longitude);

    expect(guidance.resumeAt(nearTurn), isTrue);
    expect(guidance.update(nearTurn, english: false),
        'In 60 Metern rechts abbiegen.');
  });

  test('enabling voice at the midpoint does not produce a second prompt', () {
    final route = routeToTurn(0.0072);
    final guidance = VoiceGuidance()..setRoute(route);
    final midpoint = route.points[1];

    expect(guidance.resumeAt(midpoint), isTrue);
    expect(guidance.announceCurrentManeuver(midpoint, english: false),
        'In 400 Metern rechts abbiegen.');
    expect(guidance.update(midpoint, english: false), isNull);
  });
}
