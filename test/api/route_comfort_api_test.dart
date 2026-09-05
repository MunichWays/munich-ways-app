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
  test('route is returned without analysis and preserves all three legs',
      () async {
    final requests = <Request>[];
    final api = RadlNaviApi(client: MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        expect(request.url.queryParameters['comfort'], isNull);
        expect(request.url.queryParameters['annotations'], 'nodes');
        return _response(_routePayload([
          {
            'nodes': [1, 2, 3]
          },
          {
            'nodes': [3, 4]
          },
          {
            'nodes': [4, 3, 5]
          },
        ]));
      }
      expect(request.url.path, '/tag_distribution');
      expect(
          request.headers['content-type'], 'application/json; charset=utf-8');
      expect(jsonDecode(request.body), {
        'node_ids': [1, 2, 3, 4, 3, 5]
      });
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
