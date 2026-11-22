import 'dart:math';
import 'package:latlong2/latlong.dart';

const bigJunctionGuidanceEnabled =
    bool.fromEnvironment('BIG_JUNCTION_GUIDANCE', defaultValue: true);

class JunctionCheckpoint {
  const JunctionCheckpoint(
      {required this.id,
      required this.location,
      required this.distance,
      required this.incomingBearing,
      required this.outgoingBearing,
      required this.modifier,
      required this.instruction,
      this.alignedInstruction});
  final String id, modifier;
  final LatLng location;
  final double distance, incomingBearing, outgoingBearing;
  final Map<String, String> instruction;
  final Map<String, String>? alignedInstruction;
}

class JunctionSequence {
  const JunctionSequence(
      {required this.advance,
      required this.display,
      required this.checkpoints});
  final Map<String, String> advance, display;
  final List<JunctionCheckpoint> checkpoints;
}

/// A backend-selected advance/display template without internal checkpoints.
class JunctionInstruction {
  const JunctionInstruction({required this.advance, required this.display});
  final Map<String, String> advance, display;
}

/// Backend-approved catalog occurrence; distances use the guidance projection.
class RouteBigJunction {
  const RouteBigJunction(
      {this.sequence,
      this.instruction,
      required this.occurrenceId,
      required this.movement,
      required this.entry,
      required this.exit,
      required this.polygon,
      required this.entryDistance,
      required this.exitDistance,
      required this.outgoing});
  final String occurrenceId, movement;
  final JunctionSequence? sequence;
  final JunctionInstruction? instruction;
  String get modifier => movement;
  String sentenceAction(bool english) {
    final text = action(english);
    return text[0].toUpperCase() + text.substring(1);
  }

  final LatLng entry, exit, outgoing;
  final List<LatLng> polygon;
  final double entryDistance, exitDistance;

  static List<RouteBigJunction> parse(Object? value, List<LatLng> route) {
    try {
      if (value is! Map ||
          !const ['big-junctions-v1', 'big-junctions-v2', 'big-junctions-v3']
              .contains(value['version']) ||
          value['catalogVersion'] is! String ||
          (value['catalogVersion'] as String).isEmpty ||
          (value['catalogVersion'] as String).length > 128 ||
          route.length < 2) return const [];
      final raw = value['junctions'];
      if (raw is! List || raw.isEmpty || raw.length > 256) return const [];
      final result = <RouteBigJunction>[];
      LatLng coordinate(Object? item) {
        if (item is! List ||
            item.length != 2 ||
            item.any((v) => v is! num || !v.isFinite) ||
            (item[0] as num).abs() > 180 ||
            (item[1] as num).abs() > 85) throw const FormatException();
        return LatLng((item[1] as num).toDouble(), (item[0] as num).toDouble());
      }

      ({LatLng point, double distance, int index}) anchor(Object? item) {
        if (item is! Map) throw const FormatException();
        final index = item['geometrySegmentIndex'];
        final fraction = item['segmentFraction'];
        if (index is! int ||
            index < 0 ||
            index >= route.length - 1 ||
            fraction is! num ||
            !fraction.isFinite ||
            fraction < 0 ||
            fraction > 1) throw const FormatException();
        final point = coordinate(item['location']);
        final a = route[index], b = route[index + 1];
        final interpolated = LatLng(
            a.latitude + (b.latitude - a.latitude) * fraction,
            a.longitude + (b.longitude - a.longitude) * fraction);
        if (const Distance().as(LengthUnit.Meter, point, interpolated) > .75)
          throw const FormatException();
        final mx = 111320 * cos(point.latitude * pi / 180);
        var distance = 0.0;
        for (var i = 0; i <= index; i++) {
          final dx = (route[i + 1].longitude - route[i].longitude) * mx;
          final dy = (route[i + 1].latitude - route[i].latitude) * 111320;
          distance += sqrt(dx * dx + dy * dy) * (i == index ? fraction : 1);
        }
        return (point: point, distance: distance, index: index);
      }

      Map<String, String> localized(Object? raw, int limit) {
        if (raw is! Map ||
            raw.length != 2 ||
            !['de', 'en'].every((lang) =>
                raw[lang] is String &&
                (raw[lang] as String).trim().isNotEmpty &&
                (raw[lang] as String).length <= limit)) {
          throw const FormatException();
        }
        return Map.unmodifiable(
            {'de': raw['de'] as String, 'en': raw['en'] as String});
      }

      for (final item in raw) {
        if (item is! Map ||
            item['id'] is! String ||
            (item['id'] as String).isEmpty ||
            !const ['left', 'straight', 'uturn'].contains(item['movement']) ||
            item['entryArm'] is! String ||
            (item['entryArm'] as String).isEmpty ||
            item['exitArm'] is! String ||
            (item['exitArm'] as String).isEmpty ||
            (item['entryArm'] == item['exitArm'] && item['sequence'] == null) ||
            item['occurrenceId'] is! String ||
            (item['occurrenceId'] as String).isEmpty ||
            item['legIndex'] is! int ||
            item['legIndex'] < 0) return const [];
        final entry = anchor(item['entry']), exit = anchor(item['exit']);
        final shape = item['polygon'];
        if (shape is! Map ||
            shape['type'] != 'Polygon' ||
            shape['coordinates'] is! List ||
            (shape['coordinates'] as List).length != 1) return const [];
        final ring = (shape['coordinates'][0] as List).map(coordinate).toList();
        if (ring.length < 4 ||
            ring.length > 64 ||
            ring.first != ring.last ||
            !_simpleRing(ring) ||
            exit.distance <= entry.distance ||
            exit.distance - entry.distance > 600) return const [];
        final minLat = ring.map((p) => p.latitude).reduce(min),
            maxLat = ring.map((p) => p.latitude).reduce(max);
        final minLon = ring.map((p) => p.longitude).reduce(min),
            maxLon = ring.map((p) => p.longitude).reduce(max);
        if (const Distance().as(LengthUnit.Meter, LatLng(minLat, minLon),
                LatLng(maxLat, maxLon)) >
            300) return const [];
        final outgoing = route
            .skip(exit.index + 1)
            .where((point) =>
                const Distance().as(LengthUnit.Meter, exit.point, point) >= 2)
            .firstOrNull;
        if (outgoing == null) return const [];
        JunctionInstruction? instruction;
        if (item['instruction'] != null) {
          final prompt = item['instruction'];
          final expected = switch (item['movement']) {
            'left' => 'two-way-left-near',
            'straight' => 'two-way-straight-opposite',
            _ => null,
          };
          if (value['version'] != 'big-junctions-v3' ||
              item['sequence'] != null ||
              prompt is! Map ||
              prompt['version'] != 1 ||
              expected == null ||
              prompt['templateId'] != expected) return const [];
          instruction = JunctionInstruction(
              advance: localized(prompt['advance'], 240),
              display: localized(prompt['display'], 80));
        }
        var parsed = RouteBigJunction(
            instruction: instruction,
            occurrenceId: item['occurrenceId'],
            movement: item['movement'],
            entry: entry.point,
            exit: exit.point,
            polygon: List.unmodifiable(ring),
            entryDistance: entry.distance,
            exitDistance: exit.distance,
            outgoing: outgoing);
        if (item['sequence'] != null) {
          if (!const ['big-junctions-v2', 'big-junctions-v3']
              .contains(value['version'])) return const [];
          final seq = item['sequence'];
          if (seq is! Map ||
              seq['version'] != 1 ||
              seq['checkpoints'] is! List ||
              (seq['checkpoints'] as List).isEmpty ||
              (seq['checkpoints'] as List).length > 6) return const [];
          final advance = localized(seq['advance'], 240),
              display = localized(seq['display'], 80);
          final checkpoints = <JunctionCheckpoint>[];
          final ids = <String>{};
          for (final cp in seq['checkpoints'] as List) {
            if (cp is! Map ||
                cp['id'] is! String ||
                (cp['id'] as String).isEmpty ||
                (cp['id'] as String).length > 80 ||
                !ids.add(cp['id']) ||
                !const ['left', 'right', 'straight', 'uturn']
                    .contains(cp['modifier'])) return const [];
            final location = anchor(cp['anchor']);
            if (location.distance < entry.distance ||
                location.distance > exit.distance ||
                !parsed.contains(location.point) ||
                (checkpoints.isNotEmpty &&
                    location.distance < checkpoints.last.distance + 5))
              return const [];
            for (final key in ['incomingBearing', 'outgoingBearing']) {
              if (cp[key] is! num ||
                  !(cp[key] as num).isFinite ||
                  cp[key] < 0 ||
                  cp[key] >= 360) return const [];
            }
            checkpoints.add(JunctionCheckpoint(
                id: cp['id'],
                location: location.point,
                distance: location.distance,
                incomingBearing: (cp['incomingBearing'] as num).toDouble(),
                outgoingBearing: (cp['outgoingBearing'] as num).toDouble(),
                modifier: cp['modifier'],
                instruction: localized(cp['instruction'], 120),
                alignedInstruction: cp['alignedInstruction'] == null
                    ? null
                    : localized(cp['alignedInstruction'], 120)));
          }
          parsed = RouteBigJunction(
              occurrenceId: parsed.occurrenceId,
              movement: parsed.movement,
              entry: parsed.entry,
              exit: parsed.exit,
              polygon: parsed.polygon,
              entryDistance: parsed.entryDistance,
              exitDistance: parsed.exitDistance,
              outgoing: parsed.outgoing,
              sequence: JunctionSequence(
                  advance: advance,
                  display: display,
                  checkpoints: List.unmodifiable(checkpoints)));
        } else if (item['movement'] == 'uturn') {
          return const [];
        }
        if (parsed.boundaryDistance(entry.point) > 1 ||
            parsed.boundaryDistance(exit.point) > 1) return const [];
        if (result.any((other) =>
            other.occurrenceId == parsed.occurrenceId ||
            (parsed.entryDistance <= other.exitDistance &&
                parsed.exitDistance >= other.entryDistance))) return const [];
        result.add(parsed);
      }
      result.sort((a, b) => a.entryDistance.compareTo(b.entryDistance));
      return List.unmodifiable(result);
    } catch (_) {
      // Optional metadata must never invalidate an ordinary usable route.
      return const [];
    }
  }

  bool contains(LatLng p) {
    var inside = false;
    for (var i = 0; i < polygon.length - 1; i++) {
      final a = polygon[i], b = polygon[i + 1];
      if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude <
              (b.longitude - a.longitude) *
                      (p.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) inside = !inside;
    }
    return inside;
  }

  double boundaryDistance(LatLng p) {
    final mx = 111320 * cos(p.latitude * pi / 180);
    var best = double.infinity;
    for (var i = 0; i < polygon.length - 1; i++) {
      final a = polygon[i], b = polygon[i + 1];
      final ax = (a.longitude - p.longitude) * mx,
          ay = (a.latitude - p.latitude) * 111320;
      final dx = (b.longitude - a.longitude) * mx,
          dy = (b.latitude - a.latitude) * 111320;
      final length = dx * dx + dy * dy;
      final t =
          length == 0 ? 0.0 : (-(ax * dx + ay * dy) / length).clamp(0.0, 1.0);
      best = min(best, sqrt(pow(ax + t * dx, 2) + pow(ay + t * dy, 2)));
    }
    return best;
  }

  static bool _simpleRing(List<LatLng> ring) {
    double cross(LatLng a, LatLng b, LatLng c) =>
        (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
    bool on(LatLng a, LatLng b, LatLng c) =>
        cross(a, b, c).abs() < 1e-16 &&
        c.longitude >= min(a.longitude, b.longitude) &&
        c.longitude <= max(a.longitude, b.longitude) &&
        c.latitude >= min(a.latitude, b.latitude) &&
        c.latitude <= max(a.latitude, b.latitude);
    if (ring.take(ring.length - 1).toSet().length != ring.length - 1)
      return false;
    var area = 0.0;
    for (var i = 0; i < ring.length - 1; i++) {
      final a = ring[i], b = ring[i + 1];
      area += (b.longitude - a.longitude) * (b.latitude + a.latitude);
      for (var j = i + 2; j < ring.length - 1; j++) {
        if (i == 0 && j == ring.length - 2) continue;
        final c = ring[j], d = ring[j + 1];
        if ((cross(a, b, c) * cross(a, b, d) < 0 &&
                cross(c, d, a) * cross(c, d, b) < 0) ||
            on(a, b, c) ||
            on(a, b, d) ||
            on(c, d, a) ||
            on(c, d, b)) return false;
      }
    }
    return area.abs() >= 1e-12;
  }

  String displayAction(bool english) {
    if (instruction != null)
      return instruction!.display[english ? 'en' : 'de']!;
    if (sequence != null) return sequence!.display[english ? 'en' : 'de']!;
    final direction = switch (movement) {
      'straight' => english ? 'straight' : 'geradeaus',
      'right' => english ? 'right' : 'rechts',
      'uturn' => english ? 'U-turn' : 'wenden',
      _ => english ? 'left' : 'links',
    };
    return english
        ? 'large junction $direction'
        : 'gro\u00dfe Kreuzung $direction';
  }

  String action(bool english) =>
      instruction?.advance[english ? 'en' : 'de']
          ?.replaceFirst(RegExp(r'[.!?]+$'), '') ??
      sequence?.advance[english ? 'en' : 'de'] ??
      (movement == 'straight'
          ? (english
              ? 'continue straight at the large junction'
              : 'an der gro\u00dfen Kreuzung geradeaus fahren')
          : (english
              ? 'turn left at the large junction'
              : 'an der gro\u00dfen Kreuzung links abbiegen'));
}
