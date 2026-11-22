import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

void main() {
  const start = LatLng(48.14, 11.57);

  for (final gap in [999.0, 1001.0, 1400.0]) {
    for (final english in [false, true]) {
      test('long-section suffix only at the turn: $gap ($english)', () {
        // Match the guidance projection's metres-per-latitude model exactly.
        LatLng at(double meters) =>
            LatLng(start.latitude + meters / 111320, start.longitude);
        final guidance = VoiceGuidance()
          ..setRoute(CycleRoute(
            [start, at(100), at(100 + gap), at(200 + gap)],
            200 + gap,
            500,
            maneuvers: [
              RouteManeuver(
                  location: at(100),
                  type: 'turn',
                  modifier: 'left',
                  roadName: 'Maximiliansplatz',
                  wayType: RouteWayType.road),
              RouteManeuver(
                  location: at(100 + gap), type: 'turn', modifier: 'right'),
            ],
          ));
        expect(guidance.resumeAt(at(50)), isTrue);
        expect(
            guidance.update(at(50), english: english),
            english
                ? 'In 50 meters, turn left, onto Maximiliansplatz.'
                : 'In 50 Metern links abbiegen, auf Maximiliansplatz.');
        final now = guidance.update(at(95), english: english);
        if (gap > 1000) {
          final distance = gap == 1400 ? '1.4' : '1.0';
          expect(
              now,
              english
                  ? 'Turn left, onto Maximiliansplatz here, then continue straight for $distance kilometers.'
                  : 'Hier links abbiegen, auf Maximiliansplatz, danach ${distance.replaceAll('.', ',')} Kilometer geradeaus weiterfahren.');
        } else {
          expect(
              now,
              english
                  ? 'Turn left, onto Maximiliansplatz here.'
                  : 'Hier links abbiegen, auf Maximiliansplatz.');
        }
        expect(guidance.update(at(95), english: english), isNull);
        // The new suffix must leave the existing midpoint reminder available.
        final midpoint = at(100 + gap / 2 + 1);
        expect(guidance.resumeAt(midpoint), isTrue);
        expect(guidance.update(midpoint, english: english),
            startsWith(english ? 'Continue straight.' : 'Weiter geradeaus.'));
      });
    }
  }

  for (final english in [false, true]) {
    test('reported Balan route reminds once before Thomasiusplatz ($english)',
        () {
      final data = jsonDecode(
          File('test/fixtures/balan-thomasius-straight-reminder.json')
              .readAsStringSync()) as Map<String, dynamic>;
      final route = RadlNaviApi().parseResponse(data, const [
        LatLng(48.127695, 11.594441),
        LatLng(48.113126, 11.602699),
      ]);
      final junction = route.bigJunctions.single;
      expect(junction.entryDistance, closeTo(1428, 2));
      LatLng at(double station) {
        final mx = 111320 * cos(route.points.first.latitude * pi / 180);
        for (var i = 0; i < route.points.length - 1; i++) {
          final a = route.points[i], b = route.points[i + 1];
          final dx = (b.longitude - a.longitude) * mx;
          final dy = (b.latitude - a.latitude) * 111320;
          final length = sqrt(dx * dx + dy * dy);
          if (station <= length) {
            final t = station / length;
            return LatLng(a.latitude + (b.latitude - a.latitude) * t,
                a.longitude + (b.longitude - a.longitude) * t);
          }
          station -= length;
        }
        return route.points.last;
      }

      final guidance = VoiceGuidance()..setRoute(route);
      final reminders = <String>[];
      for (var meters = 0.0;
          meters < junction.entryDistance - 130;
          meters += 10) {
        final text = guidance.update(at(meters), english: english);
        if (text != null) reminders.add(text);
      }
      expect(reminders, hasLength(1));
      expect(
          reminders.single,
          startsWith(english
              ? 'Continue straight. In 710 meters'
              : 'Weiter geradeaus. In 710 Metern'));
      expect(
          reminders.single, contains(english ? 'large junction' : 'Kreuzung'));
      // Leave room for the continuity match on curved real geometry; exact
      // 120/40 metre thresholds are covered by the straight fixture tests.
      for (final distance in [110.0, 30.0]) {
        final position = at(junction.entryDistance - distance);
        final prompt = guidance.update(position, english: english);
        expect(prompt, contains(junction.sentenceAction(english)),
            reason:
                'remaining=$distance, display=${guidance.display(position, english: english)?.text}');
        expect(prompt, isNot(contains(english ? 'meters' : 'Metern')));
        expect(guidance.update(position, english: english), isNull);
      }
      final repeated = VoiceGuidance()..setRoute(route);
      final midpoint = at(junction.entryDistance / 2 + 1);
      expect(repeated.resumeAt(midpoint), isTrue);
      expect(repeated.announceCurrentManeuver(midpoint, english: english),
          isNotNull);
      expect(repeated.update(midpoint, english: english), isNull);
    });
  }

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
      'Weiter geradeaus. In 400 Metern rechts abbiegen.',
    );
    expect(guidance.update(midpoint, english: false), isNull);
    advanceSilently(guidance, 0.0036, 0.0067);
    expect(
      guidance.update(nearTurn, english: false),
      'In 60 Metern rechts abbiegen.',
    );
    expect(guidance.update(nearTurn, english: false), isNull);
  });

  test('straight reminder omits the close second turn', () {
    const midpoint = LatLng(48.1436, 11.57);
    const firstTurn = LatLng(48.1472, 11.57);
    const secondTurn = LatLng(48.1472, 11.57027);
    const end = LatLng(48.148, 11.57027);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [start, midpoint, firstTurn, secondTurn, end],
        900,
        100,
        maneuvers: const [
          RouteManeuver(location: firstTurn, type: 'turn', modifier: 'right'),
          RouteManeuver(location: secondTurn, type: 'turn', modifier: 'left'),
        ],
      ));

    advanceSilently(guidance, 0, 0.0036);
    expect(
      guidance.update(midpoint, english: false),
      'Weiter geradeaus. In 400 Metern rechts abbiegen.',
    );
    advanceSilently(guidance, 0.0036, 0.0067);
    expect(
      guidance.update(const LatLng(48.1467, 11.57), english: false),
      contains('danach sofort'),
    );
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
      'Weiter geradeaus. In 400 Metern erreichst du dein Ziel.',
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
