import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/api_exception.dart';
import 'package:munich_ways/api/brouter_api.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

void main() {
  test('sends a BRouter request and parses its GeoJSON route', () async {
    final api = BRouterApi(
      client: MockClient((request) async {
        expect(request.url.path, '/brouter');
        expect(request.url.queryParameters, {
          'lonlats': '11.57,48.14|13.405,52.52',
          'profile': 'trekking',
          'alternativeidx': '0',
          'format': 'geojson',
          'timode': '2',
        });
        expect(request.headers['User-Agent'], 'com.munichways.app/flutter');
        return Response(
          '{"type":"FeatureCollection","features":[{"type":"Feature",'
          '"properties":{"track-length":"1234","total-time":"456"},'
          '"geometry":{"type":"LineString","coordinates":'
          '[[11.57,48.14,520],[13.405,52.52,34]]}}]}',
          200,
        );
      }),
    );

    final route = await api.route(const [
      LatLng(48.14, 11.57),
      LatLng(52.52, 13.405),
    ]);

    expect(route.points, hasLength(2));
    expect(route.points.last, const LatLng(52.52, 13.405));
    expect(route.distance, 1234);
    expect(route.duration, 456);
    expect(route.supportsVoiceGuidance, isFalse);
  });

  test('throws ApiException for a BRouter error', () async {
    final api = BRouterApi(
      client: MockClient((_) async => Response('section not found', 400)),
    );

    expect(
      () => api.route(const [LatLng(48.14, 11.57), LatLng(52.52, 13.405)]),
      throwsA(isA<ApiException>()),
    );
  });

  test('retries once when the BRouter watchdog stops a request', () async {
    var requestCount = 0;
    final api = BRouterApi(
      client: MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          expect(request.url.queryParameters['profile'], 'trekking');
          return Response('killed by thread-priority-watchdog', 503);
        }
        expect(request.url.queryParameters['profile'], 'shortest');
        return Response(
          '{"features":[{"properties":{"track-length":1500,"total-time":1080},'
          '"geometry":{"coordinates":[[11.57,48.14],[12.3155,45.4408]]}}]}',
          200,
        );
      }),
    );

    final route = await api.route(const [
      LatLng(48.14, 11.57),
      LatLng(45.4408, 12.3155),
    ]);

    expect(requestCount, 2);
    expect(route.points, hasLength(2));
    expect(route.duration, 337.5);
  });

  test('uses cycling time for the selected shortest profile', () async {
    final api = BRouterApi(
      client: MockClient((request) async {
        expect(request.url.queryParameters['profile'], 'shortest');
        return Response(
          '{"features":[{"properties":{"track-length":3000,"total-time":2160},'
          '"geometry":{"coordinates":[[11.57,48.14],[11.58,48.15]]}}]}',
          200,
        );
      }),
    );

    final route = await api.route(const [
      LatLng(48.14, 11.57),
      LatLng(48.15, 11.58),
    ], profile: BRouterProfile.shortest);

    expect(route.duration, 675);
  });

  test(
    'fastbike stays fastbike on retry and preserves its travel time',
    () async {
      var requests = 0;
      final api = BRouterApi(
        client: MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['profile'], 'fastbike');
          if (requests == 1) return Response('temporarily overloaded', 503);
          return Response(
            '{"features":[{"properties":{"track-length":1500,"total-time":456},'
            '"geometry":{"coordinates":[[11.57,48.14],[11.58,48.15]]}}]}',
            200,
          );
        }),
      );

      final route = await api.route(const [
        LatLng(48.14, 11.57),
        LatLng(48.15, 11.58),
      ], profile: BRouterProfile.fastBike);

      expect(requests, 2);
      expect(route.duration, 456);
    },
  );

  const start = LatLng(52.5163, 13.3777);
  const middle = LatLng(52.5170, 13.3777);
  const end = LatLng(52.5200, 13.4050);

  BRouterApi apiWithHints(
    Object? hints, {
    List<LatLng> points = const [start, middle, end],
  }) =>
      BRouterApi(
        client: MockClient(
          (request) async => Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'track-length': 1234,
                    'total-time': 456,
                    'voicehints': hints,
                  },
                  'geometry': {
                    'coordinates': [
                      for (final point in points)
                        [point.longitude, point.latitude],
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );

  test(
    'BRouter hints feed the existing German and English instruction formatter',
    () async {
      final route = await apiWithHints([
        [1, 5, 0, 50, 90],
      ]).route(const [start, end]);
      expect(route.supportsVoiceGuidance, isTrue);
      expect(route.maneuvers.single.location, middle);
      expect(route.maneuvers.single.roadName, isEmpty);
      expect(
        VoiceGuidance.formatManeuver(
          route.maneuvers.single,
          english: false,
          now: true,
        ),
        contains('rechts'),
      );
      expect(
        VoiceGuidance.formatManeuver(
          route.maneuvers.single,
          english: true,
          now: true,
        ),
        contains('right'),
      );
    },
  );

  test(
    'roundabout hints retain exit numbers for both driving directions',
    () async {
      for (final hint in [
        [1, 13, 3, 50, 90],
        [1, 14, -3, 50, -90],
      ]) {
        final route = await apiWithHints([hint]).route(const [start, end]);
        expect(route.supportsVoiceGuidance, isTrue);
        expect(route.maneuvers.single.type, 'roundabout');
        expect(route.maneuvers.single.exit, 3);
        expect(
          VoiceGuidance.formatManeuver(
            route.maneuvers.single,
            english: false,
            now: true,
          ),
          contains('dritte'),
        );
      }
    },
  );

  test('maps keep-left, keep-right and U-turn hints', () async {
    for (final entry in {
      8: 'slight left',
      9: 'slight right',
      10: 'uturn',
      11: 'uturn',
      15: 'uturn',
    }.entries) {
      final route = await apiWithHints([
        [1, entry.key, 0, 50, 90],
      ]).route(const [start, end]);
      expect(route.supportsVoiceGuidance, isTrue);
      expect(route.maneuvers.single.modifier, entry.value);
    }
  });

  test(
    'invalid hints keep the map route and disable incomplete guidance',
    () async {
      for (final hints in [
        null,
        [],
        'invalid',
        [
          [1, 5],
        ],
        [
          [-1, 5, 0, 50, 90],
        ],
        [
          [3, 5, 0, 50, 90],
        ],
        [
          [1.5, 5, 0, 50, 90],
        ],
        [
          [1, 999, 0, 50, 90],
        ],
        [
          [1, 12, 0, 50, 90],
        ],
        [
          [1, 16, 0, 50, 90],
        ],
        [
          [1, 13, 0, 50, 90],
        ],
        [
          [1, 5, 0, 50, 90],
          [0, 2, 0, 50, -90],
        ],
        [
          [1, 5, 0, 50, 90],
          [1, 2, 0, 50, -90],
        ],
        [
          [0, 5, 0, 50, 90],
          [1, 999, 0, 50, 90],
        ],
      ]) {
        final route = await apiWithHints(hints).route(const [start, end]);
        expect(route.points, hasLength(3), reason: '$hints');
        expect(route.distance, 1234);
        expect(route.supportsVoiceGuidance, isFalse, reason: '$hints');
        expect(route.maneuvers, isEmpty);
      }
    },
  );

  test(
    'a later valid response restores guidance after invalid hints',
    () async {
      var calls = 0;
      final api = BRouterApi(
        client: MockClient(
          (request) async => Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'track-length': 1234,
                    'total-time': 456,
                    'voicehints': [
                      [1, calls++ == 0 ? 999 : 5, 0, 50, 90],
                    ],
                  },
                  'geometry': {
                    'coordinates': [
                      [13.3777, 52.5163],
                      [13.3777, 52.5170],
                      [13.4050, 52.5200],
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      expect(
        (await api.route(const [start, end])).supportsVoiceGuidance,
        isFalse,
      );
      expect(
        (await api.route(const [start, end])).supportsVoiceGuidance,
        isTrue,
      );
    },
  );

  test('announces a stop once, continues turns, then reaches the destination',
      () async {
    const turn = LatLng(52.5180, 13.3777);
    final route = await apiWithHints([
      [2, 5, 0, 50, 90],
    ], points: const [
      start,
      middle,
      turn,
      end
    ]).route(const [start, middle, end]);
    expect(route.supportsVoiceGuidance, isTrue);
    expect(route.maneuvers.map((maneuver) => maneuver.type),
        ['arrive', 'turn', 'arrive']);
    final guidance = VoiceGuidance()
      ..setRoute(route, intermediateDestinationNames: const ['Museum']);
    expect(guidance.update(middle, english: false),
        'Du hast das Zwischenziel 1, Museum, erreicht.');
    expect(
        guidance.update(middle, english: false), isNot(contains('erreicht')));
    expect(
        guidance.display(middle, english: false)?.isFinalDestination, isFalse);
    expect(guidance.update(turn, english: false), contains('rechts'));
    expect(guidance.update(end, english: false), 'Du hast das Ziel erreicht.');
    expect(guidance.update(end, english: false), isNull);
  });

  test('keeps multiple numbered stops and a turn at the same vertex in order',
      () async {
    const stop2 = LatLng(52.5180, 13.3777);
    final route = await apiWithHints([
      [1, 5, 0, 50, 90],
      [2, 2, 0, 50, -90],
    ], points: const [
      start,
      middle,
      stop2,
      end
    ]).route(const [start, middle, stop2, end]);
    expect(route.supportsVoiceGuidance, isTrue);
    expect(route.maneuvers.map((maneuver) => maneuver.type),
        ['arrive', 'turn', 'arrive', 'turn', 'arrive']);
    final guidance = VoiceGuidance()..setRoute(route);
    expect(guidance.update(middle, english: true),
        'You have reached intermediate destination 1.');
    expect(guidance.update(stop2, english: true),
        'You have reached intermediate destination 2.');
    expect(guidance.update(end, english: true),
        'You have reached your destination.');
  });

  test('keeps the requested stop location when BRouter snaps it nearby',
      () async {
    const requestedStop = LatLng(52.51704, 13.3777);
    final route = await apiWithHints([
      [1, 5, 0, 50, 90],
    ]).route(const [start, requestedStop, end]);
    expect(route.supportsVoiceGuidance, isTrue);
    expect(route.maneuvers.first.location, requestedStop);
    final guidance = VoiceGuidance()..setRoute(route);
    expect(guidance.update(middle, english: false), contains('Zwischenziel 1'));
  });

  test('a round trip does not announce final arrival before its stop',
      () async {
    final route = await apiWithHints([
      [1, 15, 0, 50, 180],
    ], points: const [
      start,
      middle,
      start
    ]).route(const [start, middle, start]);
    expect(route.supportsVoiceGuidance, isTrue);
    final guidance = VoiceGuidance()..setRoute(route);
    expect(guidance.update(start, english: false),
        isNot(contains('Ziel erreicht')));
    expect(guidance.update(middle, english: false), contains('Zwischenziel 1'));
    expect(
        guidance.update(start, english: false), 'Du hast das Ziel erreicht.');
  });

  test('ambiguous, distant or unordered stops preserve map navigation',
      () async {
    const distant = LatLng(52.5170, 13.3800);
    const later = LatLng(52.5180, 13.3777);
    for (final scenario in [
      (
        points: const [start, middle, later, middle, end],
        stops: const [start, middle, end]
      ),
      (points: const [start, middle, end], stops: const [start, distant, end]),
      (
        points: const [start, middle, later, end],
        stops: const [start, later, middle, end]
      ),
      (
        points: const [start, middle, end],
        stops: const [start, middle, middle, end]
      ),
      (points: const [start, middle, end], stops: const [start, start, end]),
      (points: const [start, middle, end], stops: const [start, end, end]),
    ]) {
      final route = await apiWithHints([
        [1, 5, 0, 50, 90],
      ], points: scenario.points)
          .route(scenario.stops);
      expect(route.supportsVoiceGuidance, isFalse,
          reason: scenario.stops.toString());
      expect(route.maneuvers, isEmpty);
      expect(route.points, scenario.points);
      expect(route.distance, 1234);
      expect(route.duration, 456);
    }
  });

  test('invalid hints still disable guidance with valid intermediate stops',
      () async {
    for (final hints in [
      null,
      [],
      [
        [1, 999, 0, 50, 90]
      ]
    ]) {
      final route = await apiWithHints(hints).route(const [start, middle, end]);
      expect(route.supportsVoiceGuidance, isFalse);
      expect(route.maneuvers, isEmpty);
      expect(route.points, hasLength(3));
    }
  });

  test('the same provider recovers after an unassignable stop', () async {
    final api = apiWithHints([
      [1, 5, 0, 50, 90]
    ]);
    final invalid = await api.route(const [start, end, middle, end]);
    expect(invalid.supportsVoiceGuidance, isFalse);
    final valid = await api.route(const [start, middle, end]);
    expect(valid.supportsVoiceGuidance, isTrue);
    final guidance = VoiceGuidance()..setRoute(valid);
    expect(guidance.update(middle, english: false), contains('Zwischenziel 1'));
    expect(guidance.update(end, english: false), 'Du hast das Ziel erreicht.');
  });

  test('parses recorded BRouter multi-stop geometry with global hint indices',
      () async {
    final body =
        File('test/fixtures/brouter/berlin_multistop.json').readAsStringSync();
    var calls = 0;
    final api = BRouterApi(client: MockClient((request) async {
      calls++;
      expect(request.url.queryParameters['lonlats'],
          '13.3777,52.5163|13.39,52.518|13.405,52.52');
      expect(request.url.queryParameters['timode'], '2');
      return Response(body, 200);
    }));
    const stop = LatLng(52.5180, 13.3900);
    final route = await api.route(const [start, stop, end]);
    expect(calls, 1);
    expect(route.supportsVoiceGuidance, isTrue);
    expect(route.points, hasLength(130));
    expect(route.maneuvers, hasLength(23));
    final arrival = route.maneuvers.indexWhere((m) => m.type == 'arrive');
    expect(route.maneuvers[arrival].location, stop);
    expect(route.maneuvers[arrival + 1].modifier, 'uturn');
    expect(route.maneuvers[arrival + 1].location, route.points[71]);
    expect(route.maneuvers.last.location, end);
    final guidance = VoiceGuidance()
      ..setRoute(route, intermediateDestinationNames: const ['Zwischenhalt']);
    expect(guidance.update(stop, english: false), contains('Zwischenziel 1'));
    expect(guidance.update(end, english: false), 'Du hast das Ziel erreicht.');
  });
  test('parsed hints drive navigation updates and final arrival', () async {
    final route = await apiWithHints([
      [1, 5, 0, 50, 90]
    ]).route(const [start, end]);
    final guidance = VoiceGuidance()..setRoute(route);
    expect(guidance.update(middle, english: false), contains('rechts'));
    expect(guidance.update(middle, english: false), isNull);
    expect(guidance.update(end, english: false), contains('Ziel'));
  });
}
