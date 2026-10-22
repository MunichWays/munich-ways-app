import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

// A westbound leg followed by a right turn north, independent of live routing.
LatLng at(double north, double east) =>
    LatLng(48 + north / 111195, 11.5 + east / 74400);

void main() {
  for (final accuracy in [5.0, 10.0, 20.0]) {
    for (final english in [false, true]) {
      test('reported missed right turn recovers ($accuracy m, $english)',
          () async {
        final fixture = jsonDecode(await File(
          'test_resources/routing/missed-turn-osrm-2026-10-22.json',
        ).readAsString()) as Map<String, dynamic>;
        final client = MockClient((request) async {
          expect(request.url.path,
              '/route/v1/bike/11.629968,48.119083;11.62581,48.121327');
          return Response(jsonEncode(fixture['response']), 200,
              headers: {'content-type': 'application/json; charset=UTF-8'});
        });
        addTearDown(client.close);
        final route = await RadlNaviApi(client: client).route(const [
          LatLng(48.119083, 11.629968),
          LatLng(48.121327, 11.625810),
        ]);
        expect(route.maneuvers[1].modifier, 'right');
        final guidance = VoiceGuidance()..setRoute(route);
        final motion = NavigationMotionTracker();
        final epoch = DateTime(2026, 10, 22);
        const positions = [
          LatLng(48.119085, 11.629969),
          LatLng(48.119352, 11.628762),
          LatLng(48.119544, 11.627904),
          LatLng(48.119699, 11.627170), // Reported turnaround point.
          LatLng(48.119680, 11.627420),
          LatLng(48.119650, 11.627570),
          LatLng(48.119594, 11.627678), // Return to the missed junction.
          LatLng(48.119618, 11.627690),
          LatLng(48.119783, 11.627796),
          LatLng(48.119896, 11.627853), // Reported false-warning location.
          LatLng(48.120117, 11.627991),
        ];
        for (var i = 0; i < positions.length; i++) {
          final point = positions[i];
          final now = epoch.add(Duration(seconds: i * 5));
          motion.update(point, accuracy, now: now);
          guidance.updateTravelDirection(point, motion.bearingAt(now),
              movementStart: motion.movementStart,
              directionConfirmed: motion.directionConfirmed);
          final display = guidance.display(point, english: english);
          final spoken = guidance.update(point, english: english);
          if (i >= 9) {
            expect(display?.modifier, isNot('uturn'));
            expect(
                spoken,
                isNot(english
                    ? 'When safe, turn around.'
                    : 'Bitte wenden, sobald es sicher möglich ist.'));
            expect(guidance.remainingEstimate, isNotNull);
          }
        }
      });
    }
  }

  for (final english in [false, true]) {
    test('correct outgoing progress clears a prior U-turn warning ($english)',
        () {
      final guidance = VoiceGuidance()
        ..setRoute(CycleRoute(
          [at(0, 0), at(0, -180), at(200, -180)],
          380,
          100,
          maneuvers: [
            RouteManeuver(
                location: at(0, -180), type: 'turn', modifier: 'right'),
            RouteManeuver(location: at(200, -180), type: 'arrive'),
          ],
        ));
      final motion = NavigationMotionTracker();
      final epoch = DateTime(2026, 10, 22);
      void fix(LatLng point, int seconds) {
        final now = epoch.add(Duration(seconds: seconds));
        motion.update(point, 14, now: now);
        guidance.updateTravelDirection(point, motion.bearingAt(now),
            movementStart: motion.movementStart,
            directionConfirmed: motion.directionConfirmed);
      }

      fix(at(0, -145), 0);
      fix(at(0, -175), 5);
      fix(at(0, -197), 10);
      fix(at(0, -175), 15); // Back towards the missed junction.
      expect(
          guidance.update(at(0, -175), english: english),
          english
              ? 'When safe, turn around.'
              : 'Bitte wenden, sobald es sicher möglich ist.');
      fix(at(18, -180), 17); // Correct leg, but not yet a new movement anchor.
      expect(guidance.display(at(18, -180), english: english)?.modifier,
          isNot('uturn'));
      expect(
          guidance.announceCurrentManeuver(at(18, -180),
              english: english, repeat: true),
          isNot(english
              ? 'When safe, turn around.'
              : 'Bitte wenden, sobald es sicher möglich ist.'));
      fix(at(45, -180), 25);
      fix(at(20, -180), 30); // A real backwards ride still needs its warning.
      expect(
          guidance.update(at(20, -180), english: english),
          english
              ? 'When safe, turn around.'
              : 'Bitte wenden, sobald es sicher möglich ist.');
    });
  }

  test('returning from a missed turn onto the outgoing leg is not backwards',
      () {
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        [at(0, 0), at(0, -180), at(200, -180)],
        380,
        100,
        maneuvers: [
          RouteManeuver(location: at(0, -180), type: 'turn', modifier: 'right'),
          RouteManeuver(location: at(200, -180), type: 'arrive'),
        ],
      ));
    final motion = NavigationMotionTracker();
    final epoch = DateTime(2026, 10, 22);
    void fix(LatLng point, int seconds) {
      final now = epoch.add(Duration(seconds: seconds));
      motion.update(point, 10, now: now);
      guidance.updateTravelDirection(point, motion.bearingAt(now),
          movementStart: motion.movementStart,
          directionConfirmed: motion.directionConfirmed);
    }

    fix(at(0, -150), 0);
    fix(at(0, -180), 5);
    fix(at(0, -202), 10); // Pass the junction and immediately turn back.
    fix(at(5, -175),
        15); // Turn onto the northbound leg with a small GPS offset.
    fix(at(18, -180), 17); // Below the accuracy-aware movement threshold.
    expect(guidance.update(at(18, -180), english: false),
        isNot('Bitte wenden, sobald es sicher möglich ist.'));
    expect(guidance.display(at(18, -180), english: false)?.modifier,
        isNot('uturn'));
  });
}
