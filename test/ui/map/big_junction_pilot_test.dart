import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/model/big_junction.dart';
import 'package:munich_ways/ui/map/big_junction_guidance.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

Map<String, dynamic> fixture() => jsonDecode(
    File('test/fixtures/arnulf_big_junction_pilot.json').readAsStringSync());
CycleRoute parse({bool enabled = true, Map<String, dynamic>? value}) {
  final data = value ?? fixture();
  final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
  final endpoints = [coordinates.first, coordinates.last]
      .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
      .toList();
  return RadlNaviApi(bigJunctionGuidance: enabled)
      .parseResponse(data, endpoints);
}

LatLng at(CycleRoute route, double station) {
  final mx = 111320 * cos(route.bigJunctions.single.entry.latitude * pi / 180);
  for (var i = 0; i < route.points.length - 1; i++) {
    final a = route.points[i], b = route.points[i + 1];
    final dx = (b.longitude - a.longitude) * mx,
        dy = (b.latitude - a.latitude) * 111320;
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

String spokenJunction(RouteBigJunction junction, bool english) {
  final action = junction.action(english);
  return '${action[0].toUpperCase()}${action.substring(1)}.';
}

void main() {
  test('variant endpoint resolution preserves junction opt-in and opt-out',
      () async {
    const points = [LatLng(48.15, 11.51), LatLng(48.151, 11.52)];
    for (final enabled in [false, true]) {
      for (final variant in ['direct', 'discovery']) {
        for (final source in ['capability', 'headers', 'fallback']) {
          if (source == 'fallback' && variant != 'discovery') continue;
          var variantCalls = 0;
          final api = RadlNaviApi(
            bigJunctionGuidance: enabled,
            client: MockClient((request) async {
              if (request.url.path == '/routing_variants') {
                return Response(
                    source == 'fallback'
                        ? '{}'
                        : jsonEncode({
                            variant: {
                              'available': true,
                              'base_url': 'https://variant.example'
                            }
                          }),
                    source == 'fallback' ? 404 : 200,
                    headers: {'content-type': 'application/json'});
              }
              expect(request.url.queryParameters['junction_guidance'],
                  enabled ? 'true' : isNull);
              if (request.url.queryParameters['variant'] == variant)
                variantCalls++;
              return Response(jsonEncode(fixture()), 200, headers: {
                'content-type': 'application/json',
                if (source == 'headers')
                  'x-$variant-api-url': 'https://variant.example',
              });
            }),
          );
          if (source == 'headers') await api.route(points);
          final route = variant == 'direct'
              ? await api.routeDirect(points)
              : await api.routeDiscovery(points);
          expect(variantCalls, 1, reason: '$variant $source enabled=$enabled');
          expect(route.bigJunctions.isNotEmpty, enabled);
        }
      }
    }
  });

  for (final movement in ['left', 'straight']) {
    for (final english in [false, true]) {
      test('compact $movement junction display preserves speech ($english)',
          () {
        final data = fixture();
        data['routes'][0]['guidance']['junctions'][0]['movement'] = movement;
        final route = parse(value: data), j = route.bigJunctions.single;
        final voice = VoiceGuidance()..setRoute(route);
        final direction = movement == 'straight'
            ? (english ? 'straight' : 'geradeaus')
            : (english ? 'left' : 'links');
        final action = english
            ? 'large junction $direction'
            : 'gro\u00dfe Kreuzung $direction';
        final approach = at(route, j.entryDistance - 140);
        voice.display(approach, english: english);
        voice.update(approach, english: english);
        final position = at(route, j.entryDistance - 99.5);
        expect(
            voice.display(position, english: english)?.text, '100 m $action');
        expect(voice.update(position, english: english),
            spokenJunction(j, english));
      });
    }
  }

  for (final movement in ['left', 'straight']) {
    for (final english in [false, true]) {
      test('first $movement junction is spoken on start and reroute ($english)',
          () {
        final data = fixture();
        data['routes'][0]['guidance']['junctions'][0]['movement'] = movement;
        final route = parse(value: data), j = route.bigJunctions.single;
        final voice = VoiceGuidance()..setRoute(route);
        expect(
            voice.startPreview(english: english), contains(j.action(english)));
        final distant = at(route, j.entryDistance - 140);
        expect(voice.announceCurrentManeuver(distant, english: english),
            contains(j.action(english)));
        expect(
            voice.announceCurrentManeuver(distant, english: english), isNull);
        expect(
            voice.announceCurrentManeuver(distant,
                english: english, repeat: true),
            contains(j.action(english)));
        for (final distance in [119.5, 39.5]) {
          final point = at(route, j.entryDistance - distance);
          voice.display(point, english: english);
          expect(voice.update(point, english: english),
              spokenJunction(j, english));
          expect(voice.update(point, english: english), isNull);
        }
        // A recalculated route resets the initial announcement independently.
        final recalculated = parse(value: data);
        voice.setRoute(recalculated);
        expect(voice.announceCurrentManeuver(distant, english: english),
            contains(j.action(english)));
      });
    }
  }

  for (final sample in [
    (type: 'turn', modifier: 'slight left', entering: null, absorbed: true),
    (type: 'turn', modifier: 'slight right', entering: null, absorbed: true),
    (type: 'continue', modifier: 'straight', entering: null, absorbed: true),
    (type: 'turn', modifier: 'left', entering: null, absorbed: false),
    (type: 'fork', modifier: 'slight left', entering: null, absorbed: false),
    (
      type: 'continue',
      modifier: 'straight',
      entering: RouteWayType.cycleway,
      absorbed: false
    ),
  ]) {
    test(
        'approach ${sample.type} ${sample.modifier} ${sample.entering} preserves meaningful hints',
        () {
      final route = parse(), j = route.bigJunctions.single;
      route.maneuvers = [
        RouteManeuver(
            location: at(route, j.entryDistance - 20),
            type: sample.type,
            modifier: sample.modifier,
            enteringWayType: sample.entering),
        ...route.maneuvers,
      ];
      final voice = VoiceGuidance()..setRoute(route);
      voice.display(at(route, j.entryDistance - 140), english: false);
      voice.update(at(route, j.entryDistance - 140), english: false);
      voice.display(at(route, j.entryDistance - 99.5), english: false);
      expect(voice.update(at(route, j.entryDistance - 99.5), english: false),
          sample.absorbed ? spokenJunction(j, false) : isNull);
    });
  }

  test(
      'reviewed catalog guidance is enabled by default and accepts new ids and revisions',
      () {
    expect(RadlNaviApi().bigJunctionGuidance, isTrue);
    final data = fixture();
    data['routes'][0]['guidance']['catalogVersion'] =
        'munich-catalog-next-revision';
    data['routes'][0]['guidance']['junctions'][0]['id'] =
        'another-reviewed-junction';
    final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
    final route = RadlNaviApi().parseResponse(data, [
      LatLng(coordinates.first[1], coordinates.first[0]),
      LatLng(coordinates.last[1], coordinates.last[0]),
    ]);
    expect(route.bigJunctions.length, 1);
    expect(parse(enabled: false, value: data).bigJunctions, isEmpty);
  });

  test(
      'straight catalog movement uses straight speech and icon throughout the crossing',
      () {
    final data = fixture();
    data['routes'][0]['guidance']['junctions'][0]['movement'] = 'straight';
    final route = parse(value: data), j = route.bigJunctions.single;
    final voice = VoiceGuidance()..setRoute(route);
    voice.display(at(route, j.entryDistance - 140), english: false);
    voice.update(at(route, j.entryDistance - 140), english: false);
    voice.display(at(route, j.entryDistance - 99.5), english: false);
    expect(voice.update(at(route, j.entryDistance - 99.5), english: false),
        'An der gro\u00dfen Kreuzung geradeaus fahren.');
    var time = DateTime.utc(2026);
    for (final distance in [j.entryDistance - 20, j.entryDistance + 5]) {
      time = time.add(const Duration(seconds: 1));
      voice.updateBigJunctionPosition(at(route, distance),
          fixTime: time, horizontalAccuracyMeters: 5);
    }
    final display =
        voice.display(at(route, j.entryDistance + 5), english: false);
    expect(display?.modifier, 'straight');
    expect(display?.text, 'gro\u00dfe Kreuzung geradeaus');
    expect(
        voice.update(at(route, j.entryDistance + 20), english: false), isNull);
    expect(voice.startPreview(english: false), isNull);
  });

  test('multiple distinct catalog crossings parse with route-wide anchors', () {
    final data = fixture(), raw = data['routes'][0];
    final coordinates = raw['geometry']['coordinates'] as List;
    final count = coordinates.length;
    final secondCoordinates =
        coordinates.map((p) => [p[0] + .003, p[1]]).toList();
    final second = jsonDecode(jsonEncode(raw['guidance']['junctions'][0]));
    second['id'] = 'second-reviewed-junction';
    second['occurrenceId'] = 'second-visit';
    for (final key in ['entry', 'exit']) {
      second[key]['geometrySegmentIndex'] += count;
      second[key]['location'][0] += .003;
    }
    for (final p in second['polygon']['coordinates'][0]) {
      p[0] += .003;
    }
    coordinates.addAll(secondCoordinates);
    raw['guidance']['junctions'].add(second);
    final route = parse(value: data);
    expect(route.bigJunctions.length, 2);
    expect(route.bigJunctions.last.entryDistance,
        greaterThan(route.bigJunctions.first.exitDistance));
  });

  test('self intersecting polygon and absent catalog revision fall back safely',
      () {
    for (final kind in ['polygon', 'revision']) {
      final data = fixture(), guidance = data['routes'][0]['guidance'];
      if (kind == 'revision') {
        guidance['catalogVersion'] = '';
      } else {
        final ring = guidance['junctions'][0]['polygon']['coordinates'][0];
        final saved = ring[1];
        ring[1] = ring[5];
        ring[5] = saved;
      }
      expect(parse(value: data).bigJunctions, isEmpty);
    }
  });

  test('optional metadata adds one occurrence without removing raw maneuvers',
      () {
    final route = parse();
    expect(route.bigJunctions.length, 1);
    expect(route.maneuvers.length, parse(enabled: false).maneuvers.length);
    expect(parse(enabled: false).bigJunctions, isEmpty);
    expect(route.bigJunctions.single.entryDistance, greaterThan(180));
  });

  test(
      'all routing variants opt in and parse junction metadata only when enabled',
      () async {
    for (final enabled in [false, true]) {
      for (final variant in ['standard', 'direct', 'discovery']) {
        final api = RadlNaviApi(
            variant: variant,
            bigJunctionGuidance: enabled,
            client: MockClient((request) async {
              expect(request.url.queryParameters['junction_guidance'],
                  enabled ? 'true' : isNull);
              return Response(jsonEncode(fixture()), 200,
                  headers: {'content-type': 'application/json'});
            }));
        final route = await api
            .route([const LatLng(48.15, 11.51), const LatLng(48.151, 11.52)]);
        expect(route.bigJunctions.isNotEmpty, enabled);
      }
    }
  });

  test(
      'repeat visits are independent and wrong-exit recovery belongs to the current visit',
      () {
    final route = parse(), first = route.bigJunctions.single;
    final second = RouteBigJunction(
        occurrenceId: 'repeat-visit',
        movement: first.movement,
        entry: first.entry,
        exit: first.exit,
        polygon: first.polygon,
        entryDistance: first.entryDistance + 1000,
        exitDistance: first.exitDistance + 1000,
        outgoing: first.outgoing);
    final state = BigJunctionGuidance()..reset([first, second]);
    var time = DateTime.utc(2026);
    void fix(double station, double progress) {
      state.observe(at(route, station),
          fixTime: time = time.add(const Duration(seconds: 1)),
          accuracy: 5,
          progress: progress,
          distanceFromRoute: 0);
    }

    fix(first.entryDistance - 20, first.entryDistance - 20);
    fix(first.entryDistance + 5, first.entryDistance + 5);
    fix(first.exitDistance + 20, first.exitDistance + 20);
    fix(first.exitDistance + 25, first.exitDistance + 25);
    expect(state.quiet, isFalse);
    expect(state.wrongExit, isFalse);
    fix(first.entryDistance - 20, second.entryDistance - 20);
    fix(first.entryDistance + 5, second.entryDistance + 5);
    expect(state.quiet, isTrue);
    fix(first.entryDistance - 25, second.entryDistance - 25);
    fix(first.entryDistance - 30, second.entryDistance - 30);
    expect(state.wrongExit, isTrue);
    fix(first.exitDistance + 20, first.exitDistance + 20);
    expect(state.wrongExit, isTrue);
    fix(first.exitDistance + 20, second.exitDistance + 20);
    expect(state.wrongExit, isFalse);
    state.reset([first, second]);
    expect(state.quiet, isFalse);
    expect(state.wrongExit, isFalse);
  });

  test(
      'unknown, malformed and mismatched metadata falls back to existing maneuvers',
      () {
    for (final kind in [
      'version',
      'movement',
      'index',
      'location',
      'polygon',
      'duplicate'
    ]) {
      final data = fixture(), guidance = data['routes'][0]['guidance'];
      final item = guidance['junctions'][0];
      switch (kind) {
        case 'version':
          guidance['version'] = 'unknown';
        case 'movement':
          item['movement'] = 'right';
        case 'index':
          item['entry']['geometrySegmentIndex'] = 99999;
        case 'location':
          item['exit']['location'] = [11, 48];
        case 'polygon':
          item['polygon']['coordinates'] = [
            [
              [0, 0],
              [0, 80],
              [100, 80],
              [0, 0]
            ]
          ];
        case 'duplicate':
          guidance['junctions'].add(jsonDecode(jsonEncode(item)));
      }
      final route = parse(value: data);
      expect(route.bigJunctions, isEmpty, reason: kind);
      expect(route.maneuvers, isNotEmpty);
    }
  });

  test('120 and 40 metre announcements occur once, no here or catch-up pair',
      () {
    final j = parse().bigJunctions.single;
    final state = BigJunctionGuidance()..reset([j]);
    expect(state.announce(j, 130, english: false), isNull);
    expect(state.announce(j, 119.5, english: false),
        'An der großen Kreuzung links abbiegen.');
    expect(state.announce(j, 85, english: false), isNull);
    expect(state.announce(j, 59.5, english: false), isNull);
    expect(state.announce(j, 39.5, english: false),
        'An der großen Kreuzung links abbiegen.');
    expect(state.announce(j, 40, english: false), isNull);
    expect(state.announce(j, 10, english: false), isNull);
    state.reset([j]);
    expect(state.announce(j, 35, english: true), contains('large junction'));
    expect(state.announce(j, 30, english: true), isNull);
  });

  test(
      'inside state needs observed approach, ignores duplicate fixes and boundary jitter',
      () {
    final route = parse(), j = route.bigJunctions.single;
    final state = BigJunctionGuidance()..reset([j]);
    var time = DateTime.utc(2026);
    void fix(LatLng point, double progress,
        {double accuracy = 5, bool advance = true}) {
      if (advance) time = time.add(const Duration(seconds: 1));
      state.observe(point,
          fixTime: time,
          accuracy: accuracy,
          progress: progress,
          distanceFromRoute: 0);
    }

    fix(at(route, j.entryDistance + 5), j.entryDistance + 5);
    expect(state.quiet, isFalse);
    fix(at(route, j.entryDistance - 20), j.entryDistance - 20);
    fix(at(route, j.entryDistance + 5), j.entryDistance + 5);
    expect(state.quiet, isTrue);
    fix(j.exit, j.exitDistance);
    expect(state.quiet, isTrue);
    final outside = at(route, j.exitDistance + 20);
    fix(outside, j.exitDistance + 20);
    fix(outside, j.exitDistance + 20, advance: false);
    expect(state.quiet, isTrue);
    fix(at(route, j.exitDistance - 3), j.exitDistance - 3);
    fix(at(route, j.exitDistance + 20), j.exitDistance + 20);
    expect(state.quiet, isTrue);
    fix(at(route, j.exitDistance + 25), j.exitDistance + 25);
    expect(state.quiet, isFalse);
    expect(state.wrongExit, isFalse);
    fix(at(route, j.entryDistance + 5), j.entryDistance + 5);
    expect(state.quiet, isFalse);
  });

  test(
      'poor GPS does not end a crossing, wrong exit restores route-left until recovery',
      () {
    final route = parse(), j = route.bigJunctions.single;
    final state = BigJunctionGuidance()..reset([j]);
    var time = DateTime.utc(2026);
    void fix(LatLng point, double progress, {double accuracy = 5}) {
      state.observe(point,
          fixTime: time = time.add(const Duration(seconds: 1)),
          accuracy: accuracy,
          progress: progress,
          distanceFromRoute: 0);
    }

    fix(at(route, j.entryDistance - 20), j.entryDistance - 20);
    fix(at(route, j.entryDistance + 5), j.entryDistance + 5);
    fix(at(route, j.entryDistance - 30), j.entryDistance - 30, accuracy: 100);
    expect(state.quiet, isTrue);
    fix(at(route, j.entryDistance - 30), j.entryDistance - 30);
    fix(at(route, j.entryDistance - 35), j.entryDistance - 35);
    expect(state.quiet, isFalse);
    expect(state.wrongExit, isTrue);
    fix(at(route, j.exitDistance + 20), j.exitDistance + 20);
    expect(state.wrongExit, isFalse);
    state.reset([]);
    expect(state.quiet, isFalse);
  });

  test(
      'voice integration replaces three details, is quiet inside and resumes after correct exit',
      () {
    final route = parse(), j = route.bigJunctions.single;
    final voice = VoiceGuidance()..setRoute(route);
    var time = DateTime.utc(2026);
    String? tick(LatLng point) {
      voice.updateBigJunctionPosition(point,
          fixTime: time = time.add(const Duration(seconds: 1)),
          horizontalAccuracyMeters: 5);
      voice.display(point, english: false);
      return voice.update(point, english: false);
    }

    expect(voice.startPreview(english: false), contains(j.action(false)));
    expect(tick(at(route, j.entryDistance - 140)), isNull);
    expect(tick(at(route, j.entryDistance - 119.5)),
        contains('An der großen Kreuzung'));
    expect(tick(at(route, j.entryDistance - 39.5)),
        contains('An der großen Kreuzung'));
    expect(tick(at(route, j.entryDistance + 5)), isNull);
    expect(voice.inBigJunction, isTrue);
    final alternativeInside = const LatLng(48.15035, 11.52005);
    expect(tick(alternativeInside), isNull);
    expect(voice.isOffRouteForRerouting(alternativeInside), isFalse);
    expect(voice.hasHealthyMapProgress(alternativeInside), isTrue);
    expect(voice.display(alternativeInside, english: false)?.text,
        'gro\u00dfe Kreuzung links');
    expect(tick(at(route, j.exitDistance - 3)), isNull);
    expect(tick(at(route, j.exitDistance + 20)), isNull);
    tick(at(route, j.exitDistance + 25));
    expect(voice.inBigJunction, isFalse);
    expect(
        voice.isOffRouteForRerouting(at(route, j.exitDistance + 25)), isFalse);
  });

  test(
      'wrong exit triggers route-left even on the old approach; no suppression before entry',
      () {
    final route = parse(), j = route.bigJunctions.single;
    final voice = VoiceGuidance()..setRoute(route);
    var time = DateTime.utc(2026);
    void fix(LatLng point) {
      voice.updateBigJunctionPosition(point,
          fixTime: time = time.add(const Duration(seconds: 1)),
          horizontalAccuracyMeters: 5);
      voice.display(point, english: false);
    }

    expect(voice.isOffRouteForRerouting(const LatLng(48.15, 11.516)), isTrue);
    // Establish progress without exceeding the existing 120 m jump guard.
    fix(at(route, j.entryDistance - 140));
    fix(at(route, j.entryDistance - 100));
    fix(at(route, j.entryDistance - 20));
    fix(at(route, j.entryDistance + 5));
    expect(voice.inBigJunction, isTrue);
    fix(at(route, j.entryDistance - 30));
    fix(at(route, j.entryDistance - 35));
    expect(voice.inBigJunction, isFalse);
    expect(
        voice.isOffRouteForRerouting(at(route, j.entryDistance - 35)), isTrue);
    voice.setRoute(parse(enabled: false));
    expect(voice.inBigJunction, isFalse);
  });
}
