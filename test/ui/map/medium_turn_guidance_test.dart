import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

CycleRoute load(String name) {
  final data = jsonDecode(
      File('test/fixtures/medium-turns/$name.json').readAsStringSync());
  final coords = data['routes'][0]['geometry']['coordinates'] as List;
  return RadlNaviApi(bigJunctionGuidance: true).parseResponse(data, [
    for (final p in [coords.first, coords.last])
      LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())
  ]);
}

LatLng at(CycleRoute route, double station) {
  for (var i = 1; i < route.points.length; i++) {
    final a = route.points[i - 1], b = route.points[i];
    final length = const Distance().as(LengthUnit.Meter, a, b);
    if (station <= length && length > 0) {
      final t = station / length;
      return LatLng(a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t);
    }
    station -= length;
  }
  return route.points.last;
}

double station(CycleRoute route, LatLng point) {
  var result = 0.0;
  for (var i = 1; i < route.points.length; i++) {
    if (route.points[i - 1] == point) return result;
    result += const Distance()
        .as(LengthUnit.Meter, route.points[i - 1], route.points[i]);
    if (route.points[i] == point) return result;
  }
  throw StateError('Maneuver missing from route geometry');
}

void main() {
  for (final name in [
    'weissensee-forward',
    'weissensee-reverse',
    'freibad',
    'auen-junction'
  ]) {
    for (final english in [false, true]) {
      test('$name warns about the second turn in advance ($english)', () {
        final route = load(name);
        final first = route.maneuvers
            .firstWhere((m) => m.type != 'depart' && m.type != 'arrive');
        final firstAt = station(route, first.location);
        final voice = VoiceGuidance()..setRoute(route);
        final spoken = <String>[];
        for (var distance = 0.0; distance <= firstAt + 7; distance += 2) {
          final instruction =
              voice.update(at(route, distance), english: english);
          if (instruction != null) spoken.add(instruction);
        }
        final connector = english ? 'then turn' : 'danach';
        expect(spoken.where((s) => s.contains(connector)), isNotEmpty);
        expect(
            spoken.any((s) => s.contains(english ? 'immediately' : 'sofort')),
            isFalse);
        final second = route.maneuvers
            .where((m) => m.type != 'depart' && m.type != 'arrive')
            .skip(1)
            .first;
        expect(
            voice.display(at(route, firstAt + 7), english: english)?.modifier,
            second.modifier);
      });
    }
  }
  test(
      'Kobell announces the following large junction explicitly without duplicate interruption',
      () {
    final route = load('kobell-junction');
    expect(route.bigJunctions, hasLength(1));
    final first = route.maneuvers
        .firstWhere((m) => m.type == 'turn' && m.bigJunction == null);
    final firstAt = station(route, first.location);
    final voice = VoiceGuidance()..setRoute(route);
    final spoken = <String>[];
    for (var distance = 0.0; distance <= firstAt + 7; distance += 2) {
      final instruction = voice.update(at(route, distance), english: false);
      if (instruction != null) spoken.add(instruction);
    }
    expect(
        spoken.any(
            (s) => s.contains('danach an der gro\u00dfen Kreuzung geradeaus')),
        isTrue);
    expect(spoken.any((s) => s.contains('sofort')), isFalse);
    expect(spoken.where((s) => s.startsWith('An der gro\u00dfen Kreuzung')),
        isEmpty);
  });
  for (final gap in [35.0, 36.0, 75.0, 76.0]) {
    test(
        'combined prompt boundary at $gap meters and no predicted early handover',
        () {
      const origin = LatLng(48.14, 11.57);
      final first = LatLng(origin.latitude + 100 / 111320, origin.longitude);
      final second =
          LatLng(origin.latitude + (100 + gap) / 111320, origin.longitude);
      final end = LatLng(origin.latitude + 300 / 111320, origin.longitude);
      final route = CycleRoute([origin, first, second, end], 300, 60,
          maneuvers: [
            RouteManeuver(
                location: first,
                type: 'turn',
                modifier: 'left',
                roadName: 'First'),
            RouteManeuver(
                location: second,
                type: 'turn',
                modifier: 'right',
                roadName: 'Second')
          ]);
      final voice = VoiceGuidance()..setRoute(route);
      final instruction =
          voice.update(at(route, 90), english: false, speedMetersPerSecond: 5)!;
      expect(instruction.contains('danach'), gap <= 75);
      expect(instruction.contains('sofort'), gap <= 35);
      voice.update(at(route, 99), english: false, speedMetersPerSecond: 5);
      expect(voice.display(at(route, 99), english: false)?.modifier, 'left');
    });
  }
}
