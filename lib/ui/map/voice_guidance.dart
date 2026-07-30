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

  CycleRoute? _route;
  List<_GuidanceManeuver> _maneuvers = const [];
  int _index = 0;
  bool _approachSpoken = false;
  bool _nowSpoken = false;
  final Set<int> _spokenArrivals = {};
  int _offRouteUpdates = 0;
  bool _offRouteWarningSpoken = false;
  List<RouteManeuver> _arrivals = const [];
  List<String?> _intermediateDestinationNames = const [];

  void setRoute(
    CycleRoute? route, {
    List<String?> intermediateDestinationNames = const [],
  }) {
    if (identical(route, _route)) return;
    _route = route;
    _index = 0;
    _approachSpoken = false;
    _nowSpoken = false;
    _spokenArrivals.clear();
    _offRouteUpdates = 0;
    _offRouteWarningSpoken = false;
    _arrivals = const [];
    _intermediateDestinationNames =
        List<String?>.of(intermediateDestinationNames);
    if (route == null || route.points.length < 2) {
      _maneuvers = const [];
      return;
    }
    _maneuvers = route.maneuvers
        .where(_isRelevant)
        .map((maneuver) => _GuidanceManeuver(
              maneuver,
              _projectOntoRoute(route.points, maneuver.location)
                  .distanceAlongRoute,
            ))
        .toList();
    _arrivals = route.maneuvers
        .where((maneuver) => maneuver.type == 'arrive')
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

    final projection = _projectOntoRoute(route.points, position);
    if (projection.distanceFromRoute > maximumRouteDistanceMeters) {
      return null;
    }

    final arrivalIndex = _arrivalIndexAt(position);
    if (arrivalIndex != null) {
      return VoiceGuidanceDisplay(
        text: _arrivalDisplay(arrivalIndex, english),
        type: 'arrive',
      );
    }

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

    final projection = _projectOntoRoute(route.points, position);
    if (projection.distanceFromRoute > maximumRouteDistanceMeters) {
      _offRouteUpdates++;
      if (!_offRouteWarningSpoken &&
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
      return _arrivalAnnouncement(arrivalIndex, english);
    }

    if (_index >= _maneuvers.length) return null;
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
      if (const Distance().as(
            LengthUnit.Meter,
            position,
            _arrivals[index].location,
          ) <=
          arrivalDistanceMeters) {
        return index;
      }
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
    LatLng point,
  ) {
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
      if (distanceSquared < bestDistanceSquared) {
        bestDistanceSquared = distanceSquared;
        bestAlong = cumulative + segmentLength * t;
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
