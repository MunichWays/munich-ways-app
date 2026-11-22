import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/big_junction_guidance.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

const names = [
  'wilram-entry-3-exit-5',
  'wilram-entry-4-exit-5',
  'wilram-entry-5-exit-1',
  'wilram-entry-5-exit-4',
  'wilram-entry-5-exit-3'
];
Map<String, dynamic> fixture(String name) => jsonDecode(
    File('test/fixtures/wilram-sequences/$name.json').readAsStringSync());
CycleRoute parse(Map<String, dynamic> data) {
  final coords = data['routes'][0]['geometry']['coordinates'] as List;
  return RadlNaviApi().parseResponse(
      data,
      [coords.first, coords.last]
          .map(
              (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
          .toList());
}

LatLng at(CycleRoute route, double distance) {
  final mx = 111320 * cos(route.points.first.latitude * pi / 180);
  for (var i = 0; i < route.points.length - 1; i++) {
    final a = route.points[i], b = route.points[i + 1];
    final length = sqrt(pow((b.longitude - a.longitude) * mx, 2) +
        pow((b.latitude - a.latitude) * 111320, 2));
    if (distance <= length) {
      final t = distance / length;
      return LatLng(a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t);
    }
    distance -= length;
  }
  return route.points.last;
}

DateTime time(int second) =>
    DateTime.utc(2026, 11, 14).add(Duration(seconds: second));

void main() {
  for (final name in names) {
    test('$name parses real v2 contract and keeps two advance prompts', () {
      final route = parse(fixture(name));
      final junction = route.bigJunctions.single;
      expect(junction.sequence, isNotNull);
      expect(junction.sequence!.checkpoints.length,
          name.endsWith('exit-5') ? 2 : 1);
      final state = BigJunctionGuidance()..reset([junction]);
      for (final english in [false, true]) {
        state.reset([junction]);
        final advance = junction.sequence!.advance[english ? 'en' : 'de']!;
        final expected = advance[0].toUpperCase() + advance.substring(1) + '.';
        expect(state.announce(junction, 119, english: english), expected);
        expect(state.announce(junction, 60, english: english), isNull);
        expect(state.announce(junction, 39, english: english), expected);
        expect(state.announce(junction, 25, english: english), isNull);
      }
      if (name.endsWith('exit-3')) expect(junction.modifier, 'uturn');
    });
  }

  for (final name in names) {
    test('$name emits every planned checkpoint exactly once during a ride', () {
      final route = parse(fixture(name)), j = route.bigJunctions.single;
      final state = BigJunctionGuidance()..reset([j]);
      var second = 0;
      final spoken = <String>[];
      for (var station = j.entryDistance - 15;
          station < j.exitDistance;
          station += 2) {
        state.observe(at(route, station),
            fixTime: time(second++),
            accuracy: 5,
            progress: station,
            distanceFromRoute: 0);
        final instruction = state.takeCheckpointInstruction(false);
        if (instruction != null) spoken.add(instruction);
      }
      expect(spoken,
          j.sequence!.checkpoints.map((cp) => cp.instruction['de']).toList());
    });
  }

  test(
      'internal voice checkpoints replace silence once and keep ordinary turns suppressed',
      () {
    final route = parse(fixture(names.first)),
        junction = route.bigJunctions.single;
    final voice = VoiceGuidance()..setRoute(route);
    var second = 0;
    void fix(double station) {
      final position = at(route, station);
      voice.updateBigJunctionPosition(position,
          fixTime: time(second), horizontalAccuracyMeters: 5);
      voice.display(position, english: false);
      second += 2;
    }

    fix(junction.entryDistance - 15);
    fix(junction.entryDistance + 3);
    expect(voice.inBigJunction, isTrue);
    expect(voice.update(at(route, junction.entryDistance + 3), english: false),
        isNull);
    for (final checkpoint in junction.sequence!.checkpoints) {
      fix(checkpoint.distance - 20);
      fix(checkpoint.distance - 10);
      final position = at(route, checkpoint.distance - 10);
      expect(
          voice.update(position, english: false), checkpoint.instruction['de']);
      expect(voice.update(position, english: false), isNull);
      expect(voice.isOffRouteForRerouting(position), isFalse);
    }
  });

  for (final aligned in [false, true]) {
    test('Entry-4 actual approach selects ${aligned ? 'straight' : 'right'}',
        () {
      final route = parse(fixture(names[1])),
          junction = route.bigJunctions.single;
      final checkpoint = junction.sequence!.checkpoints.first;
      final state = BigJunctionGuidance()..reset([junction]);
      void fix(LatLng position, int second, double progress,
          {double accuracy = 5}) {
        state.observe(position,
            fixTime: time(second),
            accuracy: accuracy,
            progress: progress,
            distanceFromRoute: 0);
      }

      fix(at(route, junction.entryDistance - 15), 0,
          junction.entryDistance - 15);
      fix(at(route, junction.entryDistance + 3), 2, junction.entryDistance + 3);
      if (aligned) {
        fix(
            LatLng(checkpoint.location.latitude + 25 / 111320,
                checkpoint.location.longitude),
            8,
            checkpoint.distance - 20);
        fix(
            LatLng(checkpoint.location.latitude + 10 / 111320,
                checkpoint.location.longitude),
            10,
            checkpoint.distance - 10);
      } else {
        fix(at(route, checkpoint.distance - 22), 8, checkpoint.distance - 22);
        fix(at(route, checkpoint.distance - 10), 10, checkpoint.distance - 10);
      }
      expect(state.takeCheckpointInstruction(false),
          aligned ? 'Hier geradeaus.' : 'Hier rechts.');
      expect(state.checkpointModifier, aligned ? 'straight' : 'right');
      expect(state.takeCheckpointInstruction(false), isNull);
    });
  }

  for (final scenario in [
    'poor GPS',
    'stationary',
    'wrong heading',
    'GPS gap'
  ]) {
    test('checkpoint stays silent for $scenario', () {
      final route = parse(fixture(names.first)),
          junction = route.bigJunctions.single;
      final cp = junction.sequence!.checkpoints.first;
      final state = BigJunctionGuidance()..reset([junction]);
      void fix(LatLng p, int s, double station, [double accuracy = 5]) {
        state.observe(p,
            fixTime: time(s),
            accuracy: accuracy,
            progress: station,
            distanceFromRoute: 0);
      }

      fix(at(route, junction.entryDistance - 15), 0,
          junction.entryDistance - 15);
      fix(at(route, junction.entryDistance + 3), 2, junction.entryDistance + 3);
      if (scenario == 'stationary' || scenario == 'GPS gap') {
        fix(at(route, cp.distance - 10), 20, cp.distance - 10);
        fix(at(route, cp.distance - 10), 22, cp.distance - 10);
      } else if (scenario == 'wrong heading') {
        fix(LatLng(cp.location.latitude - 25 / 111320, cp.location.longitude),
            8, cp.distance - 25);
        fix(LatLng(cp.location.latitude - 10 / 111320, cp.location.longitude),
            10, cp.distance - 10);
      } else {
        fix(at(route, cp.distance - 20), 8, cp.distance - 20, 35);
        fix(at(route, cp.distance - 10), 10, cp.distance - 10, 35);
      }
      expect(state.quiet, isTrue);
      expect(state.takeCheckpointInstruction(false), isNull);
    });
  }

  test('malformed v2 metadata falls back to ordinary raw maneuvers', () {
    for (final corruption in [
      'language',
      'version',
      'anchor',
      'bearing',
      'order',
      'uturn'
    ]) {
      final data = fixture(corruption == 'uturn' ? names.last : names.first);
      final guidance = data['routes'][0]['guidance'];
      final item = guidance['junctions'][0];
      final seq = item['sequence'];
      switch (corruption) {
        case 'language':
          seq['advance'].remove('en');
        case 'version':
          guidance['version'] = 'big-junctions-v1';
        case 'anchor':
          seq['checkpoints'][0]['anchor']['location'][0] += .001;
        case 'bearing':
          seq['checkpoints'][0]['incomingBearing'] = double.nan;
        case 'order':
          seq['checkpoints'] = (seq['checkpoints'] as List).reversed.toList();
        case 'uturn':
          item.remove('sequence');
      }
      final route = parse(data);
      expect(route.bigJunctions, isEmpty, reason: corruption);
      expect(route.maneuvers, isNotEmpty, reason: corruption);
    }
  });

  test('capability uses an HTTP header and respects opt-out', () async {
    for (final enabled in [false, true]) {
      final data = fixture(names.first);
      final api = RadlNaviApi(
          bigJunctionGuidance: enabled,
          client: MockClient((request) async {
            final headers = {
              for (final e in request.headers.entries)
                e.key.toLowerCase(): e.value
            };
            expect(
                headers['x-junction-guidance-version'], enabled ? '3' : isNull);
            expect(
                request.url.queryParameters
                    .containsKey('junction_guidance_version'),
                isFalse);
            return Response(jsonEncode(data), 200,
                headers: {'content-type': 'application/json'});
          }));
      final route = await api
          .route(const [LatLng(48.115, 11.601), LatLng(48.1154, 11.603)]);
      expect(route.bigJunctions.isNotEmpty, enabled);
    }
  });
}
