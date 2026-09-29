import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

const _start = LatLng(48.14, 11.57);
const _turn = LatLng(48.141, 11.57);
const _end = LatLng(48.141, 11.571);

Map<String, Object?> _step(
        String type, LatLng point, List<List<String>> classes,
        {String modifier = 'right', String mode = 'cycling'}) =>
    {
      'mode': mode,
      'maneuver': {
        'type': type,
        'modifier': modifier,
        'location': [point.longitude, point.latitude],
      },
      'intersections': [
        for (final value in classes) {'classes': value},
      ],
    };

Future<CycleRoute> _parse(List<Map<String, Object?>> steps) async {
  final api = RadlNaviApi(
      client: MockClient((_) async => Response(
          jsonEncode({
            'routes': [
              {
                'distance': 190,
                'duration': 40,
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    for (final p in [_start, _turn, _end])
                      [p.longitude, p.latitude],
                  ],
                },
                'legs': [
                  {'steps': steps},
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=UTF-8'})));
  return api.route(const [_start, _end]);
}

void main() {
  test('keeps a way-type change when geometry softens a turn', () {
    const entry = LatLng(48.138692, 11.517890);
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [
          LatLng(48.138215, 11.517741),
          LatLng(48.138620, 11.517868),
          entry,
          LatLng(48.138733, 11.517973),
          LatLng(48.138905, 11.518033),
        ],
        90,
        20,
        maneuvers: const [
          RouteManeuver(
              location: entry,
              type: 'turn',
              modifier: 'right',
              enteringWayType: RouteWayType.cycleway),
        ],
      ));
    expect(guidance.update(const LatLng(48.138215, 11.517741), english: false),
        'In 50 Metern leicht rechts halten, auf Radweg.');
  });

  test('does not suppress slight offset turns with a way-type change', () {
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [
          _start,
          LatLng(48.1403, 11.57),
          LatLng(48.1403, 11.57015),
          LatLng(48.1408, 11.57015)
        ],
        100,
        20,
        maneuvers: const [
          RouteManeuver(
              location: LatLng(48.1403, 11.57),
              type: 'turn',
              modifier: 'slight right',
              enteringWayType: RouteWayType.road),
          RouteManeuver(
              location: LatLng(48.1403, 11.57015),
              type: 'turn',
              modifier: 'slight left',
              enteringWayType: RouteWayType.cycleway),
        ],
      ));
    expect(guidance.update(_start, english: false),
        'In 30 Metern leicht rechts halten, auf Straße, danach sofort leicht links halten, auf Radweg.');
  });

  for (final entering in RouteWayType.values) {
    test('parses and speaks a transition onto ${entering.name}', () async {
      final leaving = entering == RouteWayType.road ? 'cycleway' : 'road';
      final route = await _parse([
        _step('depart', _start, [
          [leaving]
        ]),
        _step('turn', _turn, [
          [entering.name]
        ]),
        _step('arrive', _end, []),
      ]);
      expect(route.maneuvers[1].enteringWayType, entering);
      final suffix = entering == RouteWayType.road ? 'Straße' : 'Radweg';
      final guidance = VoiceGuidance()..setRoute(route);
      expect(guidance.update(const LatLng(48.1405, 11.57), english: false),
          'In 60 Metern rechts abbiegen, auf $suffix.');
      expect(guidance.update(const LatLng(48.1409, 11.57), english: false),
          'Hier rechts abbiegen, auf $suffix.');
    });
  }

  test('uses the last incoming intersection rather than the step start',
      () async {
    final route = await _parse([
      _step('depart', _start, [
        ['cycleway'],
        ['road']
      ]),
      _step('turn', _turn, [
        ['cycleway']
      ]),
    ]);
    expect(route.maneuvers.last.enteringWayType, RouteWayType.cycleway);
  });

  test('ignored or missing classes break the transition chain', () async {
    for (final incoming in <List<String>>[
      [],
      ['tunnel'],
      ['road', 'cycleway']
    ]) {
      final route = await _parse([
        _step('depart', _start, [
          ['road'],
          incoming
        ]),
        _step('turn', _turn, [
          ['cycleway']
        ]),
      ]);
      expect(route.maneuvers.last.enteringWayType, isNull);
    }
  });

  test('same types and old responses do not add a suffix', () async {
    for (final classes in <List<String>>[
      ['road'],
      []
    ]) {
      final route = await _parse([
        _step('depart', _start, [classes]),
        _step('turn', _turn, [classes]),
      ]);
      expect(route.maneuvers.last.enteringWayType, isNull);
      expect(
          VoiceGuidance.formatManeuver(route.maneuvers.last,
              english: false, distanceMeters: 60),
          'In 60 Metern rechts abbiegen.');
    }
  });

  test('retains a straight name change when the road type changes', () async {
    final route = await _parse([
      _step('depart', _start, [
        ['road']
      ]),
      _step(
          'new name',
          _turn,
          [
            ['cycleway']
          ],
          modifier: 'straight'),
    ]);
    final guidance = VoiceGuidance()..setRoute(route);
    expect(guidance.update(const LatLng(48.1405, 11.57), english: false),
        'In 60 Metern geradeaus weiterfahren, auf Radweg.');
  });

  test('pushing does not establish a cycling transition', () async {
    final route = await _parse([
      _step(
          'depart',
          _start,
          [
            ['road']
          ],
          mode: 'pushing bike'),
      _step('turn', _turn, [
        ['cycleway']
      ]),
    ]);
    expect(route.maneuvers.last.enteringWayType, isNull);
  });

  test('adds each suffix to its own clause in a combined instruction', () {
    final guidance = VoiceGuidance()
      ..setRoute(CycleRoute(
        const [_start, _turn, _end],
        190,
        40,
        maneuvers: const [
          RouteManeuver(
              location: _turn,
              type: 'turn',
              modifier: 'left',
              enteringWayType: RouteWayType.cycleway),
          RouteManeuver(
              location: LatLng(48.141, 11.5702),
              type: 'turn',
              modifier: 'right',
              enteringWayType: RouteWayType.road),
        ],
      ));
    expect(guidance.update(const LatLng(48.1405, 11.57), english: false),
        'In 60 Metern links abbiegen, auf Radweg, danach sofort rechts abbiegen, auf Straße.');
  });
}
