// Real catalog v2/v3 references; v3 from RadlNavi commit 31ba185.
// Only the approach is extended synthetically to exercise 100/60 m speech.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

LatLng at(CycleRoute route, double distance) {
  final mx = 111320 * cos(route.bigJunctions.single.entry.latitude * pi / 180);
  for (var i = 0; i < route.points.length - 1; i++) {
    final a = route.points[i], b = route.points[i + 1];
    final dx = (b.longitude - a.longitude) * mx,
        dy = (b.latitude - a.latitude) * 111320;
    final length = sqrt(dx * dx + dy * dy);
    if (distance <= length) {
      final t = distance / length;
      return LatLng(a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t);
    }
    distance -= length;
  }
  return route.points.last;
}

void main() {
  final values = [
    ...(jsonDecode(File('test/fixtures/big_junction_catalog_v2.json')
        .readAsStringSync()) as List),
    ...(jsonDecode(File('test/fixtures/big_junction_catalog_v3.json')
        .readAsStringSync()) as List),
  ];
  for (final sample in values) {
    test('${sample['id']} speech and crossing lifecycle', () {
      // Explicitly synthetic extension solely to replay both advance thresholds.
      final data = Map<String, dynamic>.from(sample['response']);
      final raw = data['routes'][0],
          points = raw['geometry']['coordinates'] as List;
      final a = points[0], b = points[1];
      final dx = (b[0] - a[0]) * 111320 * cos(a[1] * pi / 180),
          dy = (b[1] - a[1]) * 111320;
      final factor = 200 / sqrt(dx * dx + dy * dy);
      final before = [
        a[0] - (b[0] - a[0]) * factor,
        a[1] - (b[1] - a[1]) * factor
      ];
      points.insert(0, before);
      final firstStep = raw['legs'][0]['steps'][0];
      firstStep['geometry']['coordinates'].insert(0, before);
      firstStep['maneuver']['location'] = before;
      for (final j in raw['guidance']['junctions']) {
        j['entry']['geometrySegmentIndex']++;
        j['exit']['geometrySegmentIndex']++;
      }
      final route = RadlNaviApi().parseResponse(data, [
        LatLng(before[1], before[0]),
        LatLng(points.last[1], points.last[0])
      ]);
      expect(route.bigJunctions, hasLength(1));
      final j = route.bigJunctions.single,
          voice = VoiceGuidance()..setRoute(route);
      var time = DateTime.utc(2026, 11, 7);
      String? tick(double station) {
        final point = at(route, station);
        voice.updateBigJunctionPosition(point,
            fixTime: time = time.add(const Duration(seconds: 1)),
            horizontalAccuracyMeters: 5);
        voice.display(point, english: false);
        return voice.update(point, english: false);
      }

      for (var station = 0.0; station < j.entryDistance - 140; station += 40) {
        tick(station);
      }
      tick(j.entryDistance - 140);
      expect(tick(j.entryDistance - 99.5), 'In 100 Metern ${j.action(false)}.');
      expect(tick(j.entryDistance - 59.5), 'In 60 Metern ${j.action(false)}.');
      expect(tick(j.entryDistance + 5), isNull);
      expect(voice.inBigJunction, isTrue);
      expect(
          voice
              .display(at(route, j.entryDistance + 5), english: false)
              ?.modifier,
          j.modifier);
      expect(tick(j.exitDistance - 3), isNull);
      tick(j.exitDistance + 15);
      tick(j.exitDistance + 20);
      expect(voice.inBigJunction, isFalse);
      expect(voice.isOffRouteForRerouting(at(route, j.exitDistance + 20)),
          isFalse);
    });
  }
}
