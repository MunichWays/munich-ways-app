import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/api_exception.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/route.dart';

const _points = [
  LatLng(48.156304, 11.540013),
  LatLng(48.102548, 11.568796),
  LatLng(48.120477, 11.655645),
  LatLng(47.991860, 11.828568),
];

Map<String, dynamic> _routePayload(List<Object?> annotations) => {
      'waypoints': [
        for (final p in _points)
          <String, dynamic>{
            'location': [p.longitude, p.latitude]
          }
      ],
      'routes': [
        {
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final point in _points) [point.longitude, point.latitude],
            ]
          },
          'distance': 43193,
          'duration': 9495.3,
          'legs': [
            for (var i = 0; i < annotations.length; i++)
              {
                'annotation': annotations[i],
                'steps': [
                  {
                    'mode': 'cycling',
                    'maneuver': {
                      'type': 'arrive',
                      'location': [
                        _points[i + 1].longitude,
                        _points[i + 1].latitude,
                      ]
                    },
                  }
                ],
              }
          ],
        }
      ],
    };

Response _response(Object body, [int status = 200]) => Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test(
      'full URLs, discovery cache and analysis stay bound to the direct origin',
      () async {
    var discoveries = 0;
    final api = RadlNaviApi(
        baseUrl: 'http://localhost:8080/api/',
        client: MockClient((request) async {
          if (request.url.path == '/api/routing_variants') {
            discoveries++;
            expect(request.url.port, 8080);
            return _response({
              'direct': {
                'available': true,
                'base_url': 'http://localhost:8081/direct/'
              }
            });
          }
          expect(request.url.scheme, 'http');
          expect(request.url.port, 8081);
          if (request.method == 'GET') {
            expect(request.url.path, startsWith('/direct/route/v1/bike/'));
            expect(request.url.queryParameters['variant'], 'direct');
            expect(request.url.queryParameters['steps'], 'true');
            expect(
                request.url.queryParameters['annotations'], 'nodes,distance');
            return _response(_routePayload([
              {
                'nodes': [1, 2, 1],
                'distance': [2.5, 3]
              },
              {
                'nodes': [1, 3],
                'distance': [4]
              },
              {
                'nodes': [3, 2],
                'distance': [5]
              },
            ]));
          }
          expect(request.url.path, '/direct/tag_distribution');
          final body = jsonDecode(request.body);
          expect(body['variant'], 'direct');
          expect(body['legs'][0]['nodes'], [1, 2, 1]);
          expect(body['legs'][0]['distance'], [2.5, 3]);
          expect(body['legs'][2]['end'],
              [_points.last.longitude, _points.last.latitude]);
          return _response({
            'ok': true,
            'comfort': {
              'index': null,
              'coverage': 52,
              'sufficientCoverage': false,
              'distribution': {
                'black': 0,
                'red': 0,
                'yellow': 0,
                'green': 52,
                'unrated': 48
              }
            }
          });
        }));
    final route = await api.routeDirect(_points);
    expect(route.supportsVoiceGuidance, isTrue);
    expect(route.maneuvers, hasLength(3));
    final context = route.analysisContext!;
    expect(context.variant, 'direct');
    expect(context.baseUrl, 'http://localhost:8081/direct/');
    expect(() => context.legs[0].distance.add(1), throwsUnsupportedError);
    final comfort = await api.analyzeComfort(context);
    expect(comfort.coverage, 52);
    expect(comfort.index, isNull);
    await api.routeDirect(_points);
    expect(discoveries, 1);
  });

  test('discovery failure recovers on retry and does not block standard',
      () async {
    var attempts = 0;
    final api = RadlNaviApi(client: MockClient((request) async {
      if (request.url.path == '/routing_variants') {
        attempts++;
        return attempts == 1
            ? _response({}, 404)
            : _response({
                'direct': {
                  'available': true,
                  'base_url': 'https://direct.example'
                }
              });
      }
      return _response(_routePayload([null, null, null]));
    }));
    await expectLater(api.routeDirect(_points), throwsA(isA<ApiException>()));
    expect((await api.route(_points)).distance, 43193);
    expect(attempts, 1); // standard never discovers variants
    expect((await api.routeDirect(_points)).distance, 43193);
    expect(attempts, 2);
  });

  test(
      'malformed partial-edge metadata is optional and snapped endpoints are preserved',
      () async {
    for (final bad in ['distance', 'endpoint']) {
      final payload = _routePayload([
        {
          'nodes': [1, 2],
          'distance': [2.5]
        },
        {
          'nodes': [2, 3],
          'distance': [4]
        },
        {
          'nodes': [3, 4],
          'distance': [5]
        },
      ]);
      if (bad == 'distance') {
        payload['routes'][0]['legs'][0]['annotation']['distance'] = [-1];
      } else {
        payload['waypoints'][0]['location'] = ['bad', 48];
      }
      final api =
          RadlNaviApi(client: MockClient((_) async => _response(payload)));
      final route = await api.route(_points);
      expect(route.analysisContext, isNull);
      expect(route.maneuvers, hasLength(3));
    }
    final payload = _routePayload([
      {
        'nodes': [1, 2],
        'distance': [2.5]
      },
      {
        'nodes': [2, 3],
        'distance': [4]
      },
      {
        'nodes': [3, 4],
        'distance': [5]
      },
    ]);
    payload['waypoints'][0]['location'] = [11.541, 48.157];
    final api =
        RadlNaviApi(client: MockClient((_) async => _response(payload)));
    final route = await api.route(_points);
    expect(
        route.analysisContext!.legs.first.start, const LatLng(48.157, 11.541));
  });

  test('route is returned without analysis and preserves all three legs',
      () async {
    final requests = <Request>[];
    final api = RadlNaviApi(client: MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        expect(request.url.queryParameters['comfort'], isNull);
        expect(request.url.queryParameters['annotations'], 'nodes,distance');
        return _response(_routePayload([
          {
            'nodes': [1, 2, 3],
            'distance': [12.5, 20]
          },
          {
            'nodes': [3, 4],
            'distance': [30]
          },
          {
            'nodes': [4, 3, 5],
            'distance': [40, 50]
          },
        ]));
      }
      expect(request.url.path, '/tag_distribution');
      expect(
          request.headers['content-type'], 'application/json; charset=utf-8');
      final body = jsonDecode(request.body);
      expect(body['variant'], 'standard');
      expect(body['node_ids'], isNull);
      expect(body['legs'], [
        for (var i = 0; i < 3; i++)
          {
            'nodes': [
              [1, 2, 3],
              [3, 4],
              [4, 3, 5]
            ][i],
            'distance': [
              [12.5, 20],
              [30],
              [40, 50]
            ][i],
            'start': [_points[i].longitude, _points[i].latitude],
            'end': [_points[i + 1].longitude, _points[i + 1].latitude],
          }
      ]);
      return _response({
        'ok': true,
        'comfort': {
          'index': 77,
          'coverage': 83,
          'sufficientCoverage': true,
          'distribution': {
            'black': 1,
            'red': 8,
            'yellow': 43,
            'green': 31,
            'unrated': 17
          },
        }
      });
    }));
    final route = await api.route(_points);
    expect(requests, hasLength(1));
    expect(route.comfort, isNull);
    expect(route.maneuvers, hasLength(3));
    expect(route.analysisContext!.legNodeIds, [
      [1, 2, 3],
      [3, 4],
      [4, 3, 5]
    ]);
    final comfort = await api.analyzeComfort(route.analysisContext!);
    expect(requests, hasLength(2));
    expect(comfort.index, 77);
    expect(route.comfort, isNull); // Only the current ViewModel may apply it.
  });

  test('missing or malformed annotations never invalidate navigation',
      () async {
    for (final annotation in [
      null,
      {
        'nodes': ['bad']
      },
      {'nodes': []}
    ]) {
      final api = RadlNaviApi(
          client: MockClient((_) async =>
              _response(_routePayload([annotation, annotation, annotation]))));
      final route = await api.route(_points);
      expect(route.distance, 43193);
      expect(route.maneuvers, hasLength(3));
      expect(route.analysisContext, isNull);
    }
  });

  test('HTTP failure and invalid comfort are analysis errors', () async {
    for (final response in [
      _response({'ok': false}, 503),
      _response({'ok': true}),
      _response({
        'ok': true,
        'comfort': {'coverage': 'invalid'}
      }),
    ]) {
      final api = RadlNaviApi(client: MockClient((_) async => response));
      await expectLater(
          api.analyzeComfort(RouteAnalysisContext([
            [1, 2]
          ])),
          throwsA(isA<ApiException>()));
    }
  });

  test('insufficient coverage is successful analysis, not an error', () async {
    final api = RadlNaviApi(
        client: MockClient((_) async => _response({
              'ok': true,
              'comfort': {
                'index': null,
                'coverage': 40,
                'sufficientCoverage': false,
                'distribution': {
                  'black': 0,
                  'red': 0,
                  'yellow': 0,
                  'green': 40,
                  'unrated': 60
                }
              },
            })));
    final comfort = await api.analyzeComfort(RouteAnalysisContext([
      [1, 2]
    ]));
    expect(comfort.index, isNull);
    expect(comfort.coverage, 40);
  });
}
