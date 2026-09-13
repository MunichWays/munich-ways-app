import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/route_display.dart';

List<List<dynamic>> lines(CycleRoute route, bool dashed) =>
    (buildRouteDisplayGeoJson(route, dashed: dashed)['features'] as List)
        .map((f) => f['geometry']['coordinates'] as List<dynamic>)
        .toList();

List<LatLng> flattened(CycleRoute route) {
  final points = <LatLng>[];
  for (final section in route.displaySections) {
    for (final point in section.points) {
      if (points.isEmpty || points.last != point) points.add(point);
    }
  }
  return points;
}

void main() {
  for (final trip in ['underpass', 'commute']) {
    for (final variant in ['standard', 'direct']) {
      test('$trip $variant preserves navigation and renders every pushing step',
          () async {
        final body = File('test/fixtures/radlnavi_pushing/$trip-$variant.json')
            .readAsStringSync();
        final payload = jsonDecode(body)['routes'][0];
        final coordinates = payload['geometry']['coordinates'] as List;
        final expectedPoints = [
          for (final p in coordinates)
            LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())
        ];
        final api = RadlNaviApi(
            variant: variant,
            client: MockClient((_) async => Response(body, 200)));
        final route =
            await api.route([expectedPoints.first, expectedPoints.last]);
        expect(route.displaySections, isNotEmpty);
        expect(flattened(route), route.points);
        expect(route.distance, payload['distance']);
        expect(route.duration, payload['duration']);
        expect(route.supportsVoiceGuidance, isTrue);
        final dashed = lines(route, true);
        final solid = lines(route, false);
        expect(dashed, isNotEmpty);
        expect(solid, isNotEmpty);
        // All pushing edges must occur in the dashed source, including legs
        // ending at an intermediate stop and consecutive mode changes.
        for (final leg in payload['legs']) {
          for (final step in leg['steps']) {
            if (step['mode'] != 'pushing bike') continue;
            final geometry = step['geometry']['coordinates'] as List;
            for (var i = 0; i < geometry.length - 1; i++) {
              if (jsonEncode(geometry[i]) == jsonEncode(geometry[i + 1]))
                continue;
              final edge = jsonEncode([geometry[i], geometry[i + 1]]);
              expect(dashed.any((line) {
                for (var j = 0; j < line.length - 1; j++) {
                  if (jsonEncode([line[j], line[j + 1]]) == edge) return true;
                }
                return false;
              }), isTrue, reason: 'Missing pushing edge: $edge');
            }
          }
        }
        // Parsing geometry adds no maneuver, notification or voice instruction.
        final steps = [for (final leg in payload['legs']) ...leg['steps']];
        expect(route.maneuvers.length, steps.length);
      });
    }
  }

  test('repeated points keep occurrence modes and dash gaps have no solid line',
      () async {
    final a = [11.0, 48.0], b = [11.001, 48.0], c = [11.002, 48.0];
    Map<String, dynamic> geometry(List<List<double>> points) =>
        {'type': 'LineString', 'coordinates': points};
    Map<String, dynamic> step(List<List<double>> points, String mode) => {
          'geometry': geometry(points),
          'mode': mode,
          'maneuver': {'type': 'turn', 'location': points.first},
        };
    final body = jsonEncode({
      'routes': [
        {
          'geometry': geometry([a, b, a, b, c]),
          'distance': 400,
          'duration': 300,
          'legs': [
            {
              'steps': [
                step([a, b], 'cycling'),
                step([b, a], 'pushing bike')
              ]
            },
            {
              'steps': [
                step([a, b], 'pushing bike'),
                step([b, c], 'cycling')
              ]
            },
          ]
        }
      ]
    });
    final api =
        RadlNaviApi(client: MockClient((_) async => Response(body, 200)));
    final route =
        await api.route([const LatLng(48, 11), const LatLng(48, 11.002)]);
    expect(flattened(route), route.points);
    expect(lines(route, false), [
      [a, b],
      [b, c]
    ]);
    expect(lines(route, true), [
      [b, a, b]
    ]);
    expect(route.maneuvers, hasLength(4));
  });

  test('incomplete step geometry preserves the route and final connector',
      () async {
    final body = jsonDecode(
        File('test/fixtures/radlnavi_pushing/underpass-standard.json')
            .readAsStringSync());
    body['routes'][0]['legs'][0]['steps'][0].remove('geometry');
    final api = RadlNaviApi(
        client: MockClient((_) async => Response(jsonEncode(body), 200)));
    final route = await api.route(
        [const LatLng(48.1064, 11.592893), const LatLng(48.105, 11.594)]);
    expect(route.displaySections, isEmpty);
    expect(lines(route, false), hasLength(1));
    expect(lines(route, true), hasLength(1));
    expect(route.destinationConnector.last, const LatLng(48.105, 11.594));
  });
}
