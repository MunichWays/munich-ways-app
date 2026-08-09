import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';

/// Turns OSRM maneuvers and GPS positions into one-shot spoken instructions.
///
/// Distances are measured along the route, rather than directly to the
/// junction, so nearby parallel roads do not trigger an instruction early.
class VoiceGuidance {
  VoiceGuidance({
    this.approachDistanceMeters = 60,
    this.nowDistanceMeters = 15,
    this.maximumRouteDistanceMeters = 25,
    this.arrivalDistanceMeters = 20,
    this.lookAheadSeconds = 2,
    this.maximumLookAheadMeters = 15,
    this.speechLeadSeconds = 1,
    this.maximumSpeechLookAheadMeters = 30,
    this.closeManeuverDistanceMeters = 35,
    this.offRouteUpdatesBeforeWarning = 10,
    this.announceOffRouteWarning = true,
  });

  final double approachDistanceMeters;
  final double nowDistanceMeters;
  final double maximumRouteDistanceMeters;
  final double arrivalDistanceMeters;
  final double lookAheadSeconds;
  final double maximumLookAheadMeters;
  final double speechLeadSeconds;
  final double maximumSpeechLookAheadMeters;
  final double closeManeuverDistanceMeters;
  final int offRouteUpdatesBeforeWarning;
  final bool announceOffRouteWarning;

  bool isOffRoute(LatLng position) {
    final route = _route;
    if (route == null) return false;
    return _projectOntoRoute(
          route.points,
          position,
          minimumDistanceAlongRoute: _routeProgress,
        ).distanceFromRoute >
        maximumRouteDistanceMeters;
  }

  CycleRoute? _route;
  List<_GuidanceManeuver> _maneuvers = const [];
  int _index = 0;
  bool _approachSpoken = false;
  bool _nowSpoken = false;
  final Set<int> _spokenArrivals = {};
  int _offRouteUpdates = 0;
  bool _offRouteWarningSpoken = false;
  List<_GuidanceManeuver> _arrivals = const [];
  List<String?> _intermediateDestinationNames = const [];
  double _routeProgress = 0;
  bool _overlappingRouteUnsupported = false;
  bool _overlappingRouteWarningSpoken = false;

  void setRoute(
    CycleRoute? route, {
    List<String?> intermediateDestinationNames = const [],
  }) {
    final guidanceRoute = route?.supportsVoiceGuidance == true ? route : null;
    if (identical(guidanceRoute, _route)) return;
    _route = guidanceRoute;
    _index = 0;
    _approachSpoken = false;
    _nowSpoken = false;
    _spokenArrivals.clear();
    _offRouteUpdates = 0;
    _offRouteWarningSpoken = false;
    _arrivals = const [];
    _routeProgress = 0;
    _overlappingRouteUnsupported = false;
    _overlappingRouteWarningSpoken = false;
    _intermediateDestinationNames =
        List<String?>.of(intermediateDestinationNames);
    if (guidanceRoute == null || guidanceRoute.points.length < 2) {
      _maneuvers = const [];
      return;
    }
    _overlappingRouteUnsupported = intermediateDestinationNames.isNotEmpty &&
        _hasRepeatedRouteSegment(guidanceRoute.points);
    final projectedManeuvers = <_GuidanceManeuver>[];
    var previousManeuverDistance = 0.0;
    for (final maneuver in guidanceRoute.maneuvers) {
      final projection = _projectOntoRoute(
        guidanceRoute.points,
        maneuver.location,
        minimumDistanceAlongRoute: previousManeuverDistance,
      );
      previousManeuverDistance = projection.distanceAlongRoute;
      projectedManeuvers.add(
        _GuidanceManeuver(maneuver, projection.distanceAlongRoute),
      );
    }
    final routedManeuvers = projectedManeuvers
        .where((maneuver) => _isRelevant(maneuver.maneuver))
        .toList();
    final sortedManeuvers = [
      ...routedManeuvers,
      ..._geometryTurns(guidanceRoute, routedManeuvers),
    ]..sort((a, b) => a.routeDistance.compareTo(b.routeDistance));
    _maneuvers = _withoutStraightOffsetPairs(
      guidanceRoute.points,
      sortedManeuvers,
    );
    _arrivals = projectedManeuvers
        .where((maneuver) => maneuver.maneuver.type == 'arrive')
        .toList(growable: false);
  }

  void reset() => setRoute(null);

  VoiceGuidanceDisplay? display(
    LatLng position, {
    required bool english,
    double speedMetersPerSecond = 0,
  }) {
    final route = _route;
    if (route == null) return null;
    if (_overlappingRouteUnsupported) {
      return VoiceGuidanceDisplay(
        text: english ? 'Follow map' : 'Karte beachten',
        type: 'map',
      );
    }

    final projection = _projectOntoRoute(
      route.points,
      position,
      minimumDistanceAlongRoute: _routeProgress,
    );
    if (projection.distanceFromRoute > maximumRouteDistanceMeters) {
      return null;
    }

    final arrivalIndex = _arrivalIndexAt(position);
    if (arrivalIndex != null) {
      _routeProgress =
          max(_routeProgress, _arrivals[arrivalIndex].routeDistance);
      return VoiceGuidanceDisplay(
        text: _arrivalDisplay(arrivalIndex, english),
        type: 'arrive',
      );
    }

    _routeProgress = max(_routeProgress, projection.distanceAlongRoute);
    final travelled = _predictedDistanceAlongRoute(
      projection.distanceAlongRoute,
      speedMetersPerSecond,
    );
    _advancePastManeuvers(travelled);
    if (_index >= _maneuvers.length) return null;

    final target = _maneuvers[_index];
    final remaining = target.routeDistance - travelled;
    if (remaining < -5) return null;
    return VoiceGuidanceDisplay(
      text: _formatDisplay(
        target.maneuver,
        english: english,
        remainingMeters: remaining,
      ),
      type: target.maneuver.type,
      modifier: target.maneuver.modifier,
    );
  }

  String? update(
    LatLng position, {
    required bool english,
    double speedMetersPerSecond = 0,
  }) {
    final route = _route;
    if (route == null) return null;
    if (_overlappingRouteUnsupported) {
      if (_overlappingRouteWarningSpoken) return null;
      _overlappingRouteWarningSpoken = true;
      return english
          ? 'Outbound and return routes overlap. No turn directions. '
              'Please follow the route on the map.'
          : 'Hin- und Rückweg überlappen. Keine Abbiegehinweise. '
              'Bitte der Route auf der Karte folgen.';
    }

    final projection = _projectOntoRoute(
      route.points,
      position,
      minimumDistanceAlongRoute: _routeProgress,
    );
    if (projection.distanceFromRoute > maximumRouteDistanceMeters) {
      _offRouteUpdates++;
      if (announceOffRouteWarning &&
          !_offRouteWarningSpoken &&
          _offRouteUpdates >= offRouteUpdatesBeforeWarning) {
        _offRouteWarningSpoken = true;
        return english
            ? 'No directions. Route may have been left or no GPS signal.'
            : 'Keine Ansage. Route möglicherweise verlassen oder kein GPS-Signal.';
      }
      return null;
    }
    _offRouteUpdates = 0;
    _offRouteWarningSpoken = false;

    final arrivalIndex = _arrivalIndexAt(position);
    if (arrivalIndex != null && _spokenArrivals.add(arrivalIndex)) {
      _routeProgress =
          max(_routeProgress, _arrivals[arrivalIndex].routeDistance);
      return _arrivalAnnouncement(arrivalIndex, english);
    }

    if (_index >= _maneuvers.length) return null;
    _routeProgress = max(_routeProgress, projection.distanceAlongRoute);
    final travelled = _predictedDistanceAlongRoute(
      projection.distanceAlongRoute,
      speedMetersPerSecond,
      additionalSeconds: speechLeadSeconds,
      maximumMeters: maximumSpeechLookAheadMeters,
    );
    _advancePastManeuvers(travelled);
    if (_index >= _maneuvers.length) return null;

    final target = _maneuvers[_index];
    final remaining = target.routeDistance - travelled;
    if (!_nowSpoken && remaining >= -5 && remaining <= nowDistanceMeters) {
      _nowSpoken = true;
      return _formatSpokenManeuver(
        target,
        english: english,
        now: true,
      );
    }
    if (!_approachSpoken &&
        target.maneuver.type != 'arrive' &&
        remaining > nowDistanceMeters &&
        remaining <= approachDistanceMeters) {
      _approachSpoken = true;
      return _formatSpokenManeuver(
        target,
        english: english,
        distanceMeters: _roundedDistance(remaining),
      );
    }
    return null;
  }

  int? _arrivalIndexAt(LatLng position) {
    for (var index = 0; index < _arrivals.length; index++) {
      if (_spokenArrivals.contains(index)) continue;
      if (const Distance().as(
            LengthUnit.Meter,
            position,
            _arrivals[index].maneuver.location,
          ) <=
          arrivalDistanceMeters) {
        return index;
      }
      // Intermediate destinations must be reached in their planned order.
      // Otherwise a destination near an outbound section could be mistaken
      // for reached before a preceding stop on an overlapping return section.
      return null;
    }
    return null;
  }

  bool _isIntermediateArrival(int index) => index < _arrivals.length - 1;

  String? _intermediateName(int index) {
    if (index >= _intermediateDestinationNames.length) return null;
    final name = _intermediateDestinationNames[index]?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  String _arrivalDisplay(int index, bool english) {
    if (!_isIntermediateArrival(index)) {
      return english ? 'Destination reached' : 'Ziel erreicht';
    }
    final name = _intermediateName(index);
    if (english) {
      return name == null ? 'Intermediate destination reached' : name;
    }
    return name == null ? 'Zwischenziel erreicht' : name;
  }

  String _arrivalAnnouncement(int index, bool english) {
    if (!_isIntermediateArrival(index)) {
      return english
          ? 'You have reached your destination.'
          : 'Sie haben das Ziel erreicht.';
    }
    final name = _intermediateName(index);
    if (english) {
      return name == null
          ? 'You have reached the intermediate destination.'
          : 'You have reached the intermediate destination $name.';
    }
    return name == null
        ? 'Sie haben das Zwischenziel erreicht.'
        : 'Sie haben das Zwischenziel $name erreicht.';
  }

  String _formatSpokenManeuver(
    _GuidanceManeuver target, {
    required bool english,
    bool now = false,
    int? distanceMeters,
  }) {
    final first = formatManeuver(
      target.maneuver,
      english: english,
      now: now,
      distanceMeters: distanceMeters,
    );
    if (_index + 1 >= _maneuvers.length) return first;

    final next = _maneuvers[_index + 1];
    final gap = next.routeDistance - target.routeDistance;
    if (gap <= 0 || gap > closeManeuverDistanceMeters) return first;

    final nextAction = _action(next.maneuver, english);
    return english
        ? '${first.substring(0, first.length - 1)}, then immediately $nextAction.'
        : '${first.substring(0, first.length - 1)}, danach sofort $nextAction.';
  }

  void _next() {
    _index++;
    _approachSpoken = false;
    _nowSpoken = false;
  }

  void _advancePastManeuvers(double travelled) {
    while (_index < _maneuvers.length &&
        travelled > _maneuvers[_index].routeDistance + 25) {
      _next();
    }
  }

  double _predictedDistanceAlongRoute(
    double measuredDistance,
    double speedMetersPerSecond, {
    double additionalSeconds = 0,
    double? maximumMeters,
  }) {
    if (!speedMetersPerSecond.isFinite || speedMetersPerSecond <= 0) {
      return measuredDistance;
    }
    final lookAhead =
        (speedMetersPerSecond * (lookAheadSeconds + additionalSeconds)).clamp(
      0.0,
      maximumMeters ?? maximumLookAheadMeters,
    );
    return measuredDistance + lookAhead;
  }

  static bool _isRelevant(RouteManeuver maneuver) =>
      maneuver.type != 'depart' &&
      maneuver.type != 'arrive' &&
      maneuver.type != 'notification' &&
      !(maneuver.type == 'new name' &&
          (maneuver.modifier == null || maneuver.modifier == 'straight'));

  static bool _hasRepeatedRouteSegment(List<LatLng> points) {
    final segments = <String>{};
    for (var index = 0; index < points.length - 1; index++) {
      final start = _routePointKey(points[index]);
      final end = _routePointKey(points[index + 1]);
      if (start == end) continue;
      final key = start.compareTo(end) < 0 ? '$start|$end' : '$end|$start';
      if (!segments.add(key)) return true;
    }
    return false;
  }

  static String _routePointKey(LatLng point) =>
      '${(point.latitude * 100000).round()}:'
      '${(point.longitude * 100000).round()}';

  /// Removes short left/right chicanes where the route continues in nearly
  /// the same direction. Routing services can otherwise describe a slightly
  /// offset cycle crossing as two turns instead of simply going straight.
  static List<_GuidanceManeuver> _withoutStraightOffsetPairs(
    List<LatLng> route,
    List<_GuidanceManeuver> maneuvers,
  ) {
    const maximumGapMeters = 30.0;
    const sampleDistanceMeters = 12.0;
    const maximumHeadingChangeDegrees = 25.0;
    final result = <_GuidanceManeuver>[];

    for (var index = 0; index < maneuvers.length; index++) {
      final first = maneuvers[index];
      if (index + 1 >= maneuvers.length) {
        result.add(first);
        continue;
      }
      final second = maneuvers[index + 1];
      final gap = second.routeDistance - first.routeDistance;
      if (!_areOppositeTurns(first.maneuver, second.maneuver) ||
          gap <= 0 ||
          gap > maximumGapMeters) {
        result.add(first);
        continue;
      }

      final before = _pointAlongRoute(
        route,
        max(0, first.routeDistance - sampleDistanceMeters),
      );
      final atFirst = _pointAlongRoute(route, first.routeDistance);
      final atSecond = _pointAlongRoute(route, second.routeDistance);
      final after = _pointAlongRoute(
        route,
        second.routeDistance + sampleDistanceMeters,
      );
      final headingChange = _angleBetweenSegments(
        before,
        atFirst,
        atSecond,
        after,
      );
      if (headingChange <= maximumHeadingChangeDegrees) {
        index++;
        continue;
      }
      result.add(first);
    }
    return result;
  }

  static bool _areOppositeTurns(RouteManeuver first, RouteManeuver second) {
    final firstModifier = first.modifier ?? '';
    final secondModifier = second.modifier ?? '';
    return firstModifier.contains('left') && secondModifier.contains('right') ||
        firstModifier.contains('right') && secondModifier.contains('left');
  }

  static LatLng _pointAlongRoute(List<LatLng> route, double targetDistance) {
    var travelled = 0.0;
    const distance = Distance();
    for (var index = 0; index < route.length - 1; index++) {
      final start = route[index];
      final end = route[index + 1];
      final segmentLength =
          distance.as(LengthUnit.Meter, start, end).toDouble();
      if (travelled + segmentLength >= targetDistance && segmentLength > 0) {
        final fraction =
            ((targetDistance - travelled) / segmentLength).clamp(0.0, 1.0);
        return LatLng(
          start.latitude + (end.latitude - start.latitude) * fraction,
          start.longitude + (end.longitude - start.longitude) * fraction,
        );
      }
      travelled += segmentLength;
    }
    return route.last;
  }

  static double _angleBetweenSegments(
    LatLng before,
    LatLng atFirst,
    LatLng atSecond,
    LatLng after,
  ) {
    final latitudeRadians = atFirst.latitude * pi / 180;
    final metersPerLon = 111320.0 * cos(latitudeRadians);
    const metersPerLat = 111320.0;
    final incomingX = (atFirst.longitude - before.longitude) * metersPerLon;
    final incomingY = (atFirst.latitude - before.latitude) * metersPerLat;
    final outgoingX = (after.longitude - atSecond.longitude) * metersPerLon;
    final outgoingY = (after.latitude - atSecond.latitude) * metersPerLat;
    return (atan2(
              incomingX * outgoingY - incomingY * outgoingX,
              incomingX * outgoingX + incomingY * outgoingY,
            ) *
            180 /
            pi)
        .abs();
  }

  /// Adds clear corners that routing services sometimes omit when the route
  /// follows the same named foot/cycle way through a junction.
  static List<_GuidanceManeuver> _geometryTurns(
    CycleRoute route,
    List<_GuidanceManeuver> routedManeuvers,
  ) {
    const minimumLegMeters = 7.0;
    const minimumTurnDegrees = 60.0;
    const maximumTurnDegrees = 135.0;
    const duplicateDistanceMeters = 25.0;
    final result = <_GuidanceManeuver>[];
    final protectedDistances = route.maneuvers
        .map(
          (maneuver) => _projectOntoRoute(route.points, maneuver.location)
              .distanceAlongRoute,
        )
        .toList(growable: false);
    var routeDistance = 0.0;

    for (var index = 1; index < route.points.length - 1; index++) {
      final before = route.points[index - 1];
      final corner = route.points[index];
      final after = route.points[index + 1];
      final latitudeRadians = corner.latitude * pi / 180;
      final metersPerLon = 111320.0 * cos(latitudeRadians);
      const metersPerLat = 111320.0;
      final incomingX = (corner.longitude - before.longitude) * metersPerLon;
      final incomingY = (corner.latitude - before.latitude) * metersPerLat;
      final outgoingX = (after.longitude - corner.longitude) * metersPerLon;
      final outgoingY = (after.latitude - corner.latitude) * metersPerLat;
      final incomingLength =
          sqrt(incomingX * incomingX + incomingY * incomingY);
      final outgoingLength =
          sqrt(outgoingX * outgoingX + outgoingY * outgoingY);
      routeDistance += incomingLength;
      if (incomingLength < minimumLegMeters ||
          outgoingLength < minimumLegMeters) {
        continue;
      }

      final signedTurn = atan2(
            incomingX * outgoingY - incomingY * outgoingX,
            incomingX * outgoingX + incomingY * outgoingY,
          ) *
          180 /
          pi;
      final turnDegrees = signedTurn.abs();
      if (turnDegrees < minimumTurnDegrees ||
          turnDegrees > maximumTurnDegrees) {
        continue;
      }

      final isDuplicate = [...routedManeuvers, ...result].any(
            (maneuver) =>
                (maneuver.routeDistance - routeDistance).abs() <
                duplicateDistanceMeters,
          ) ||
          protectedDistances.any(
            (distance) =>
                (distance - routeDistance).abs() < duplicateDistanceMeters,
          );
      if (isDuplicate) continue;

      result.add(_GuidanceManeuver(
        RouteManeuver(
          location: corner,
          type: 'turn',
          modifier: signedTurn < 0 ? 'right' : 'left',
        ),
        routeDistance,
      ));
    }
    return result;
  }

  static int _roundedDistance(double meters) =>
      max(10, (meters / 10).round() * 10);

  static String formatManeuver(
    RouteManeuver maneuver, {
    required bool english,
    bool now = false,
    int? distanceMeters,
  }) {
    if (maneuver.type == 'arrive') {
      return english
          ? 'You have reached your destination.'
          : 'Sie haben das Ziel erreicht.';
    }

    final action = _action(maneuver, english);
    if (now) return english ? '$action now.' : 'Jetzt $action.';
    return english
        ? 'In $distanceMeters meters, $action.'
        : 'In $distanceMeters Metern $action.';
  }

  static String _formatDisplay(
    RouteManeuver maneuver, {
    required bool english,
    required double remainingMeters,
  }) {
    final action = _shortAction(maneuver, english);
    if (remainingMeters <= 15) {
      return english ? '$action now' : 'Jetzt $action';
    }
    final distance = _roundedDistance(remainingMeters);
    return english ? 'In $distance m $action' : 'In $distance m $action';
  }

  static String _shortAction(RouteManeuver maneuver, bool english) {
    if (maneuver.type == 'roundabout' ||
        maneuver.type == 'rotary' ||
        maneuver.type == 'roundabout turn') {
      final exit = maneuver.exit;
      if (exit != null) {
        return english ? 'take exit $exit' : '${_germanOrdinal(exit)} Ausfahrt';
      }
      return english ? 'enter roundabout' : 'in den Kreisverkehr';
    }
    return switch (maneuver.modifier) {
      'uturn' => english ? 'turn around' : 'wenden',
      'sharp right' => english ? 'sharp right' : 'scharf rechts',
      'slight right' => english ? 'keep right' : 'leicht rechts',
      'right' => english ? 'right' : 'rechts',
      'sharp left' => english ? 'sharp left' : 'scharf links',
      'slight left' => english ? 'keep left' : 'leicht links',
      'left' => english ? 'left' : 'links',
      _ => english ? 'continue straight' : 'geradeaus',
    };
  }

  static String _action(RouteManeuver maneuver, bool english) {
    if (maneuver.type == 'roundabout' ||
        maneuver.type == 'rotary' ||
        maneuver.type == 'roundabout turn') {
      final exit = maneuver.exit;
      if (exit != null) {
        return english
            ? 'take exit $exit at the roundabout'
            : 'im Kreisverkehr die ${_germanOrdinal(exit)} Ausfahrt nehmen';
      }
      return english ? 'enter the roundabout' : 'in den Kreisverkehr einfahren';
    }

    final direction = switch (maneuver.modifier) {
      'uturn' => english ? 'turn around' : 'wenden',
      'sharp right' =>
        english ? 'turn sharply right' : 'scharf rechts abbiegen',
      'slight right' => english ? 'bear right' : 'leicht rechts halten',
      'right' => english ? 'turn right' : 'rechts abbiegen',
      'sharp left' => english ? 'turn sharply left' : 'scharf links abbiegen',
      'slight left' => english ? 'bear left' : 'leicht links halten',
      'left' => english ? 'turn left' : 'links abbiegen',
      _ => english ? 'continue straight' : 'geradeaus weiterfahren',
    };
    return direction;
  }

  static String _germanOrdinal(int value) => switch (value) {
        1 => 'erste',
        2 => 'zweite',
        3 => 'dritte',
        4 => 'vierte',
        5 => 'fünfte',
        6 => 'sechste',
        _ => '$value.',
      };

  static _RouteProjection _projectOntoRoute(
    List<LatLng> route,
    LatLng point, {
    double minimumDistanceAlongRoute = 0,
  }) {
    var cumulative = 0.0;
    var bestDistanceSquared = double.infinity;
    var bestAlong = 0.0;
    final latitudeRadians = point.latitude * pi / 180;
    final metersPerLon = 111320.0 * cos(latitudeRadians);
    const metersPerLat = 111320.0;

    for (var i = 0; i < route.length - 1; i++) {
      final a = route[i];
      final b = route[i + 1];
      final ax = (a.longitude - point.longitude) * metersPerLon;
      final ay = (a.latitude - point.latitude) * metersPerLat;
      final bx = (b.longitude - point.longitude) * metersPerLon;
      final by = (b.latitude - point.latitude) * metersPerLat;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
      final px = ax + dx * t;
      final py = ay + dy * t;
      final distanceSquared = px * px + py * py;
      final segmentLength = sqrt(lengthSquared);
      final distanceAlong = cumulative + segmentLength * t;
      if (distanceAlong + 1 >= minimumDistanceAlongRoute &&
          distanceSquared < bestDistanceSquared) {
        bestDistanceSquared = distanceSquared;
        bestAlong = distanceAlong;
      }
      cumulative += segmentLength;
    }
    return _RouteProjection(bestAlong, sqrt(bestDistanceSquared));
  }
}

class _GuidanceManeuver {
  const _GuidanceManeuver(this.maneuver, this.routeDistance);

  final RouteManeuver maneuver;
  final double routeDistance;
}

class _RouteProjection {
  const _RouteProjection(
    this.distanceAlongRoute,
    this.distanceFromRoute,
  );

  final double distanceAlongRoute;
  final double distanceFromRoute;
}

class VoiceGuidanceDisplay {
  const VoiceGuidanceDisplay({
    required this.text,
    required this.type,
    this.modifier,
  });

  final String text;
  final String type;
  final String? modifier;

  @override
  bool operator ==(Object other) =>
      other is VoiceGuidanceDisplay &&
      text == other.text &&
      type == other.type &&
      modifier == other.modifier;

  @override
  int get hashCode => Object.hash(text, type, modifier);
}
