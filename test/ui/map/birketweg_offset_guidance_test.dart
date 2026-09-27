import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

Future<CycleRoute> birketweg() async {
  final saved = jsonDecode(await File(
    'test_resources/routing/birketweg-osrm-2026-09-26.json',
  ).readAsString()) as Map<String, dynamic>;
  final client = MockClient((request) async {
    expect(request.url.path,
        '/route/v1/bike/11.520751,48.145395;11.522572,48.145413');
    return Response(jsonEncode(saved['response']), 200,
        headers: {'content-type': 'application/json; charset=UTF-8'});
  });
  addTearDown(client.close);
  return RadlNaviApi(client: client).route(const [
    LatLng(48.145395, 11.520751),
    LatLng(48.145413, 11.522572),
  ]);
}

void main() {
  test('Birketweg parser retains both original maneuvers and full geometry',
      () async {
    final route = await birketweg();
    expect(route.maneuvers.map((m) => '${m.type}/${m.modifier}'), [
      'depart/null',
      'continue/left',
      'turn/right',
      'arrive/null',
    ]);
    expect(route.points.first, const LatLng(48.145394, 11.520751));
    expect(route.points.last, const LatLng(48.145421, 11.522573));
    expect(route.points, contains(const LatLng(48.145503, 11.521401)));
    expect(route.distance, 147.2);
  });

  for (final firstType in ['continue', 'turn']) {
    test('Birketweg $firstType left then right remains visible and spoken',
        () async {
      final route = await birketweg();
      if (firstType == 'turn') {
        final original = route.maneuvers[1];
        route.maneuvers[1] = RouteManeuver(
          location: original.location,
          type: 'turn',
          modifier: 'left',
          roadName: original.roadName,
        );
      }
      final originalManeuvers = List<RouteManeuver>.of(route.maneuvers);
      final guidance = VoiceGuidance()..setRoute(route);
      expect(guidance.display(route.points.first, english: false)?.text,
          'In 50 m links');
      expect(guidance.update(route.points.first, english: false),
          'In 50 Metern links abbiegen, danach sofort rechts abbiegen.');
      expect(guidance.update(route.points.first, english: false), isNull);
      expect(route.maneuvers, orderedEquals(originalManeuvers));

      final immediate = VoiceGuidance()..setRoute(route);
      expect(immediate.update(route.maneuvers[1].location, english: false),
          'Hier links abbiegen, danach sofort rechts abbiegen.');
      final english = VoiceGuidance()..setRoute(route);
      expect(english.update(route.points.first, english: true),
          'In 50 meters, turn left, then immediately turn right.');
    });
  }

  CycleRoute offset(String firstType, String firstModifier, String secondType,
          String secondModifier) =>
      CycleRoute(
        const [
          LatLng(48.14, 11.57),
          LatLng(48.1403, 11.57),
          LatLng(48.1403, 11.57015),
          LatLng(48.1406, 11.57015)
        ],
        78,
        20,
        maneuvers: [
          RouteManeuver(
              location: const LatLng(48.1403, 11.57),
              type: firstType,
              modifier: firstModifier),
          RouteManeuver(
              location: const LatLng(48.1403, 11.57015),
              type: secondType,
              modifier: secondModifier),
        ],
      );

  test('still suppresses eligible opposite slight turns in either order', () {
    for (final modifiers in [
      ['slight right', 'slight left'],
      ['slight left', 'slight right'],
    ]) {
      final route = offset('turn', modifiers[0], 'turn', modifiers[1]);
      final guidance = VoiceGuidance()..setRoute(route);
      expect(guidance.display(route.points.first, english: false), isNull);
      expect(guidance.update(route.points.first, english: false), isNull);
    }
  });

  test('preserves normal, sharp and non-turn maneuvers in short offsets', () {
    for (final pair in [
      ['turn', 'right', 'turn', 'slight left'],
      ['turn', 'slight right', 'turn', 'left'],
      ['turn', 'sharp right', 'turn', 'slight left'],
      ['turn', 'slight right', 'turn', 'sharp left'],
      ['continue', 'slight right', 'turn', 'slight left'],
      ['turn', 'slight right', 'fork', 'slight left'],
      ['roundabout', 'slight right', 'turn', 'slight left'],
      ['turn', 'slight right', 'turn', 'slight right'],
    ]) {
      final route = offset(pair[0], pair[1], pair[2], pair[3]);
      final guidance = VoiceGuidance()..setRoute(route);
      expect(guidance.display(route.points.first, english: false), isNotNull,
          reason: pair.toString());
      expect(guidance.update(route.points.first, english: false),
          contains('danach sofort'),
          reason: pair.toString());
    }
  });
}
