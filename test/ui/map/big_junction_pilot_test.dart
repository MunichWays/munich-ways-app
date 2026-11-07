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

void main() {
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
          sample.absorbed ? 'In 100 Metern ${j.action(false)}.' : isNull);
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
        'In 100 Metern an der gro\u00dfen Kreuzung geradeaus fahren.');
    var time = DateTime.utc(2026);
    for (final distance in [j.entryDistance - 20, j.entryDistance + 5]) {
      time = time.add(const Duration(seconds: 1));
      voice.updateBigJunctionPosition(at(route, distance),
          fixTime: time, horizontalAccuracyMeters: 5);
    }
    final display =
        voice.display(at(route, j.entryDistance + 5), english: false);
    expect(display?.modifier, 'straight');
    expect(display?.text, 'An der gro\u00dfen Kreuzung geradeaus fahren');
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
      'only pilot standard requests opt in; normal and direct requests remain unchanged',
      () async {
    for (final enabled in [false, true]) {
      for (final variant in ['standard', 'direct']) {
        final api = RadlNaviApi(
            variant: variant,
            bigJunctionGuidance: enabled,
            client: MockClient((request) async {
              expect(request.url.queryParameters['junction_guidance'],
                  enabled && variant == 'standard' ? 'true' : isNull);
              return Response(jsonEncode(fixture()), 200,
                  headers: {'content-type': 'application/json'});
            }));
        final route = await api
            .route([const LatLng(48.15, 11.51), const LatLng(48.151, 11.52)]);
        expect(route.bigJunctions.isNotEmpty, enabled && variant == 'standard');
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

  test('100 and 60 metre announcements occur once, no here or catch-up pair',
      () {
    final j = parse().bigJunctions.single;
    final state = BigJunctionGuidance()..reset([j]);
    expect(state.announce(j, 110, english: false), isNull);
    expect(state.announce(j, 99.5, english: false),
        'In 100 Metern an der großen Kreuzung links abbiegen.');
    expect(state.announce(j, 85, english: false), isNull);
    expect(state.announce(j, 59.5, english: false),
        'In 60 Metern an der großen Kreuzung links abbiegen.');
    expect(state.announce(j, 60, english: false), isNull);
    expect(state.announce(j, 10, english: false), isNull);
    state.reset([j]);
    expect(state.announce(j, 55, english: true), contains('large junction'));
    expect(state.announce(j, 50, english: true), isNull);
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

    expect(voice.startPreview(english: false), isNull);
    expect(tick(at(route, j.entryDistance - 140)), isNull);
    expect(tick(at(route, j.entryDistance - 99.5)),
        contains('In 100 Metern an der großen Kreuzung'));
    expect(tick(at(route, j.entryDistance - 59.5)),
        contains('In 60 Metern an der großen Kreuzung'));
    expect(tick(at(route, j.entryDistance + 5)), isNull);
    expect(voice.inBigJunction, isTrue);
    final alternativeInside = const LatLng(48.15035, 11.52005);
    expect(tick(alternativeInside), isNull);
    expect(voice.isOffRouteForRerouting(alternativeInside), isFalse);
    expect(voice.hasHealthyMapProgress(alternativeInside), isTrue);
    expect(voice.display(alternativeInside, english: false)?.text,
        'An der großen Kreuzung links abbiegen');
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
