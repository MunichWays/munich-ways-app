import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/route_overlap.dart';

enum NavigationOrientationDecision { waiting, forward, reverse, offRoute }

enum NavigationStartDecision { waiting, onRoute, offRoute }

/// Defers all initial guidance until the rider has left the start area.
class NavigationStartGate {
  NavigationStartGate({
    this.minimumDistanceFromStartMeters = 25,
    this.routeCorridorMeters = 15,
    this.maximumAccuracyAllowanceMeters = 8,
  });

  final double minimumDistanceFromStartMeters;
  final double routeCorridorMeters;
  final double maximumAccuracyAllowanceMeters;

  LatLng? _start;
  NavigationStartDecision _decision = NavigationStartDecision.waiting;

  bool get offRoute => _decision == NavigationStartDecision.offRoute;

  void reset([LatLng? start]) {
    _start = start;
    _decision = NavigationStartDecision.waiting;
  }

  NavigationStartDecision evaluate(
    LatLng position, {
    required double horizontalAccuracyMeters,
    required List<LatLng> routePoints,
  }) {
    final start = _start;
    if (start == null) {
      _start = position;
      return _decision = NavigationStartDecision.waiting;
    }
    final distanceFromStart =
        const Distance().as(LengthUnit.Meter, start, position);
    if (distanceFromStart < minimumDistanceFromStartMeters) {
      return _decision = NavigationStartDecision.waiting;
    }
    final distanceFromRoute = _distanceFromRoute(routePoints, position);
    if (distanceFromRoute == null) {
      return _decision = NavigationStartDecision.waiting;
    }
    final accuracyAllowance = horizontalAccuracyMeters.isFinite
        ? horizontalAccuracyMeters.clamp(0, maximumAccuracyAllowanceMeters)
        : 0;
    return _decision =
        distanceFromRoute <= routeCorridorMeters + accuracyAllowance
            ? NavigationStartDecision.onRoute
            : NavigationStartDecision.offRoute;
  }
}

/// Holds turn guidance until movement establishes the initial travel direction.
///
/// Once forward movement has been confirmed, this gate stays open. It must not
/// monitor later route departures; those belong to the regular delayed
/// off-route and rerouting flow.
class NavigationOrientationGate {
  NavigationOrientationGate({
    this.minimumMovementMeters = 8,
    this.maximumAccuracyThresholdMeters = 15,
    this.maximumDirectionDifferenceDegrees = 60,
    this.maximumRouteDistanceMeters = 35,
  });

  final double minimumMovementMeters;
  final double maximumAccuracyThresholdMeters;
  final double maximumDirectionDifferenceDegrees;
  final double maximumRouteDistanceMeters;

  LatLng? _anchor;
  NavigationOrientationDecision? _establishedDirection;

  void reset([LatLng? anchor]) {
    _anchor = anchor;
    _establishedDirection = null;
  }

  NavigationOrientationDecision evaluate(
    LatLng position, {
    required double horizontalAccuracyMeters,
    required double speedMetersPerSecond,
    required List<LatLng> routePoints,
  }) {
    if (_establishedDirection == NavigationOrientationDecision.forward) {
      return NavigationOrientationDecision.forward;
    }
    final anchor = _anchor;
    if (anchor == null) {
      _anchor = position;
      return NavigationOrientationDecision.waiting;
    }

    final accuracy = horizontalAccuracyMeters.isFinite
        ? horizontalAccuracyMeters.clamp(
            minimumMovementMeters,
            maximumAccuracyThresholdMeters,
          )
        : minimumMovementMeters;
    final distance = const Distance().as(LengthUnit.Meter, anchor, position);
    final moving = speedMetersPerSecond.isFinite && speedMetersPerSecond >= 1;
    if (!((moving && distance >= accuracy) || distance >= accuracy * 2)) {
      return _establishedDirection ?? NavigationOrientationDecision.waiting;
    }
    if (routePoints.length < 2) {
      return _establishedDirection ?? NavigationOrientationDecision.waiting;
    }

    final travelBearing = const Distance().bearing(anchor, position);
    final routeDirection = _closestUnambiguousRouteDirection(
      routePoints,
      anchor,
    );
    _anchor = position;
    if (routeDirection == null) {
      return _establishedDirection ?? NavigationOrientationDecision.waiting;
    }
    final accuracyAllowance = horizontalAccuracyMeters.isFinite
        ? horizontalAccuracyMeters.clamp(0, maximumRouteDistanceMeters)
        : 0;
    if (routeDirection.distanceFromRoute >
        maximumRouteDistanceMeters + accuracyAllowance) {
      return _establishedDirection ?? NavigationOrientationDecision.offRoute;
    }

    final difference =
        ((travelBearing - routeDirection.bearing + 540) % 360 - 180).abs();
    if (difference <= maximumDirectionDifferenceDegrees) {
      final currentRoutePosition = _closestUnambiguousRouteDirection(
        routePoints,
        position,
      );
      if (currentRoutePosition == null) {
        return _establishedDirection ?? NavigationOrientationDecision.waiting;
      }
      if (currentRoutePosition.distanceFromRoute >
          maximumRouteDistanceMeters + accuracyAllowance) {
        return _establishedDirection ?? NavigationOrientationDecision.offRoute;
      }
      _establishedDirection = NavigationOrientationDecision.forward;
      return NavigationOrientationDecision.forward;
    }
    if (difference >= 180 - maximumDirectionDifferenceDegrees) {
      _establishedDirection = NavigationOrientationDecision.reverse;
      return NavigationOrientationDecision.reverse;
    }
    return _establishedDirection ?? NavigationOrientationDecision.waiting;
  }
}

_RouteDirection? _closestUnambiguousRouteDirection(
  List<LatLng> route,
  LatLng point,
) {
  final candidates = <_RouteDirection>[];
  final latitudeRadians = point.latitude * pi / 180;
  final metersPerLon = 111320.0 * cos(latitudeRadians);
  const metersPerLat = 111320.0;
  for (var index = 0; index < route.length - 1; index++) {
    final a = route[index];
    final b = route[index + 1];
    final ax = (a.longitude - point.longitude) * metersPerLon;
    final ay = (a.latitude - point.latitude) * metersPerLat;
    final bx = (b.longitude - point.longitude) * metersPerLon;
    final by = (b.latitude - point.latitude) * metersPerLat;
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) continue;
    final t = (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
    final px = ax + dx * t;
    final py = ay + dy * t;
    candidates.add(
      _RouteDirection(
        const Distance().bearing(a, b),
        sqrt(px * px + py * py),
      ),
    );
  }
  if (candidates.isEmpty) return null;
  candidates.sort(
    (first, second) =>
        first.distanceFromRoute.compareTo(second.distanceFromRoute),
  );
  final closest = candidates.first;
  for (final candidate in candidates.skip(1)) {
    if (candidate.distanceFromRoute > closest.distanceFromRoute + 6) break;
    final difference =
        ((candidate.bearing - closest.bearing + 540) % 360 - 180).abs();
    if (difference > 60) return null;
  }
  return closest;
}

class _RouteDirection {
  const _RouteDirection(this.bearing, this.distanceFromRoute);

  final double bearing;
  final double distanceFromRoute;
}

double? _distanceFromRoute(List<LatLng> route, LatLng point) {
  if (route.length < 2) return null;
  final latitudeRadians = point.latitude * pi / 180;
  final metersPerLon = 111320.0 * cos(latitudeRadians);
  const metersPerLat = 111320.0;
  var closest = double.infinity;
  for (var index = 0; index < route.length - 1; index++) {
    final a = route[index];
    final b = route[index + 1];
    final ax = (a.longitude - point.longitude) * metersPerLon;
    final ay = (a.latitude - point.latitude) * metersPerLat;
    final bx = (b.longitude - point.longitude) * metersPerLon;
    final by = (b.latitude - point.latitude) * metersPerLat;
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) continue;
    final t = (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
    final px = ax + dx * t;
    final py = ay + dy * t;
    closest = min(closest, sqrt(px * px + py * py));
  }
  return closest.isFinite ? closest : null;
}

/// Turns OSRM maneuvers and GPS positions into one-shot spoken instructions.
///
/// Distances are measured along the route, rather than directly to the
/// junction, so nearby parallel roads do not trigger an instruction early.
class VoiceGuidance {
  // GPS positions have no OSM layer/level information. On ramps, bridges and
  // spirals a later route section can therefore be only a few metres away in
  // 2D. Keep matching local to the established progress so navigation does
  // not jump from the lower section to the section above it.
  static const double _maximumProgressJumpMeters = 120;
  static const double _projectionContinuityToleranceMeters = 6;
  static const double _ambiguousRouteSeparationMeters = 30;

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

  bool isOffRoute(
    LatLng position, {
    double horizontalAccuracyMeters = 0,
  }) {
    if (_finalDestinationReached) return false;
    final route = _route;
    if (route == null) return false;
    final accuracyAllowance = horizontalAccuracyMeters.isFinite
        ? horizontalAccuracyMeters.clamp(0, maximumRouteDistanceMeters)
        : 0;
    return _projectOntoRoute(
          route.points,
          position,
          minimumDistanceAlongRoute: _routeProgress,
          maximumDistanceAlongRoute:
              _routeProgress + _maximumProgressJumpMeters,
        ).distanceFromRoute >
        maximumRouteDistanceMeters + accuracyAllowance;
  }

  /// Whether the rider is spatially outside the complete route.
  ///
  /// Unlike [isOffRoute], this ignores monotonic guidance progress. It is the
  /// appropriate signal for user-visible route-left and rerouting states: a
  /// corrected GPS fix on an earlier route section must not cause an alert.
  bool isOffRouteForRerouting(
    LatLng position, {
    double horizontalAccuracyMeters = 0,
  }) =>
      isOffRoute(
        position,
        horizontalAccuracyMeters: horizontalAccuracyMeters,
      ) &&
      !isOnRouteAnywhere(
        position,
        horizontalAccuracyMeters: horizontalAccuracyMeters,
      );

  /// Whether [position] is close to any part of the route. This deliberately
  /// ignores the current guidance progress and is used only to recover after
  /// an off-route episode, where the rider may rejoin slightly behind the
  /// previous progress window.
  bool isOnRouteAnywhere(
    LatLng position, {
    double horizontalAccuracyMeters = 0,
  }) {
    final route = _route;
    if (route == null) return false;
    final accuracyAllowance = horizontalAccuracyMeters.isFinite
        ? horizontalAccuracyMeters.clamp(0, maximumRouteDistanceMeters)
        : 0;
    return _projectOntoRoute(route.points, position).distanceFromRoute <=
        maximumRouteDistanceMeters + accuracyAllowance;
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
  int _intermediateArrivalCount = 0;
  double _routeProgress = 0;
  List<_RouteInterval> _overlappingRouteIntervals = const [];
  bool _overlappingRouteWarningSpoken = false;
  bool _finalDestinationReached = false;
  bool _routeRecoveryPending = false;

  bool get finalDestinationReached => _finalDestinationReached;

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
    _intermediateArrivalCount = 0;
    _routeProgress = 0;
    _overlappingRouteIntervals = const [];
    _overlappingRouteWarningSpoken = false;
    _finalDestinationReached = false;
    _routeRecoveryPending = false;
    _intermediateDestinationNames =
        List<String?>.of(intermediateDestinationNames);
    if (guidanceRoute == null || guidanceRoute.points.length < 2) {
      _maneuvers = const [];
      return;
    }
    if (intermediateDestinationNames.isNotEmpty) {
      _overlappingRouteIntervals =
          _repeatedRouteIntervals(guidanceRoute.points);
    }
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
        _GuidanceManeuver(
          _adjustTurnModifierFromGeometry(
            guidanceRoute.points,
            maneuver,
            projection.distanceAlongRoute,
          ),
          projection.distanceAlongRoute,
        ),
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
    final arrivals = projectedManeuvers
        .where((maneuver) => maneuver.maneuver.type == 'arrive')
        .toList();
    _intermediateArrivalCount = max(
      _intermediateDestinationNames.length,
      arrivals.length - 1,
    );
    final expectedArrivalCount = _intermediateArrivalCount + 1;
    if (arrivals.length < expectedArrivalCount) {
      // RadlNavi removes the final walking access from spoken maneuvers. In
      // that case its final `arrive` maneuver is missing and the old logic
      // mistook the last intermediate stop for the destination.
      final destination = guidanceRoute.destinationConnector.isNotEmpty
          ? guidanceRoute.destinationConnector.last
          : guidanceRoute.points.last;
      final projection = _projectOntoRoute(
        guidanceRoute.points,
        destination,
        minimumDistanceAlongRoute:
            arrivals.isEmpty ? 0 : arrivals.last.routeDistance,
      );
      arrivals.add(
        _GuidanceManeuver(
          RouteManeuver(location: destination, type: 'arrive'),
          projection.distanceAlongRoute,
        ),
      );
    }
    _arrivals = arrivals.take(expectedArrivalCount).toList(growable: false);
  }

  void reset() => setRoute(null);

  /// Restarts maneuver guidance at the rider's current place on the route.
  ///
  /// This is used after an off-route episode. A freshly reset guidance session
  /// normally only searches a short distance ahead of the route start, which
  /// cannot locate a rider who rejoins farther along a long route.
  bool resumeAt(
    LatLng position, {
    double horizontalAccuracyMeters = 0,
  }) {
    final route = _route;
    if (route == null) return false;
    final projection = _projectOntoRoute(route.points, position);
    final accuracyAllowance = horizontalAccuracyMeters.isFinite
        ? horizontalAccuracyMeters.clamp(0, maximumRouteDistanceMeters)
        : 0;
    if (projection.distanceFromRoute >
        maximumRouteDistanceMeters + accuracyAllowance) {
      return false;
    }

    _routeProgress = projection.distanceAlongRoute;
    _index = 0;
    _approachSpoken = false;
    _nowSpoken = false;
    _offRouteUpdates = 0;
    _offRouteWarningSpoken = false;
    _routeRecoveryPending = false;
    _advancePastManeuvers(_routeProgress);
    return true;
  }

  VoiceGuidanceDisplay? display(
    LatLng position, {
    required bool english,
    double speedMetersPerSecond = 0,
  }) {
    final route = _route;
    if (route == null) return null;
    if (_finalDestinationReached) {
      return VoiceGuidanceDisplay(
        text: english ? 'Destination reached' : 'Ziel erreicht',
        type: 'arrive',
        isFinalDestination: true,
      );
    }
    final projection = _projectionAtCurrentProgress(position);
    if (projection.isAmbiguous &&
        !_isOverlappingProgress(projection.distanceAlongRoute)) {
      return VoiceGuidanceDisplay(
        text: english ? 'Watch the map' : 'Auf Karte achten',
        type: 'map',
      );
    }
    final arrivalIndex = _arrivalIndexAt(position);
    if (arrivalIndex != null) {
      final isFinalDestination = !_isIntermediateArrival(arrivalIndex);
      if (isFinalDestination) _finalDestinationReached = true;
      _routeProgress =
          max(_routeProgress, _arrivals[arrivalIndex].routeDistance);
      _routeRecoveryPending = false;
      return VoiceGuidanceDisplay(
        text: _arrivalDisplay(arrivalIndex, english),
        type: 'arrive',
        isFinalDestination: isFinalDestination,
      );
    }
    if (projection.distanceFromRoute > maximumRouteDistanceMeters) {
      return null;
    }

    _routeProgress = max(_routeProgress, projection.distanceAlongRoute);
    if (_isOverlappingProgress(projection.distanceAlongRoute)) {
      _advancePastManeuvers(_routeProgress);
      return VoiceGuidanceDisplay(
        text: english ? 'Watch the map' : 'Auf Karte achten',
        type: 'map',
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

  /// Announces the currently displayed first maneuver regardless of distance.
  ///
  /// This is only for a newly started or refreshed route after its initial
  /// travel direction has been confirmed. Normal updates retain their regular
  /// distance thresholds.
  String? announceInitialManeuver(
    LatLng position, {
    required bool english,
    double speedMetersPerSecond = 0,
  }) {
    final route = _route;
    if (route == null || _finalDestinationReached) return null;
    final projection = _projectionAtCurrentProgress(position);
    if (projection.isAmbiguous ||
        projection.distanceFromRoute > maximumRouteDistanceMeters ||
        _isOverlappingProgress(projection.distanceAlongRoute)) {
      return null;
    }

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
    if (remaining < -5 || target.maneuver.type == 'arrive') return null;
    if (remaining <= nowDistanceMeters) {
      _nowSpoken = true;
      return _formatSpokenManeuver(target, english: english, now: true);
    }
    _approachSpoken = true;
    return _formatSpokenManeuver(
      target,
      english: english,
      distanceMeters: _roundedDistance(remaining),
    );
  }

  String? update(
    LatLng position, {
    required bool english,
    double speedMetersPerSecond = 0,
  }) {
    final route = _route;
    if (route == null) return null;
    if (_finalDestinationReached) {
      final finalIndex = _arrivals.length - 1;
      if (finalIndex >= 0 && _spokenArrivals.add(finalIndex)) {
        return _arrivalAnnouncement(finalIndex, english);
      }
      return null;
    }
    final projection = _projectionAtCurrentProgress(position);
    if (projection.isAmbiguous &&
        !_isOverlappingProgress(projection.distanceAlongRoute)) {
      return null;
    }
    final arrivalIndex = _arrivalIndexAt(position);
    if (arrivalIndex != null && _spokenArrivals.add(arrivalIndex)) {
      if (!_isIntermediateArrival(arrivalIndex)) {
        _finalDestinationReached = true;
      }
      _routeProgress =
          max(_routeProgress, _arrivals[arrivalIndex].routeDistance);
      _routeRecoveryPending = false;
      return _arrivalAnnouncement(arrivalIndex, english);
    }
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

    _routeProgress = max(_routeProgress, projection.distanceAlongRoute);
    if (_isOverlappingProgress(projection.distanceAlongRoute)) {
      _advancePastManeuvers(_routeProgress);
      if (_overlappingRouteWarningSpoken) return null;
      _overlappingRouteWarningSpoken = true;
      return english
          ? 'Outbound and return routes are the same here. Watch the map.'
          : 'Hin- und Rückweg sind hier gleich. Auf Karte achten.';
    }
    _overlappingRouteWarningSpoken = false;

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

  _RouteProjection _projectionAtCurrentProgress(LatLng position) {
    final route = _route;
    if (route == null) {
      return const _RouteProjection(0, double.infinity);
    }
    var projection = _projectOntoRoute(
      route.points,
      position,
      minimumDistanceAlongRoute: _routeProgress,
      maximumDistanceAlongRoute: _routeProgress + _maximumProgressJumpMeters,
      preferEarlierWithinMeters: _projectionContinuityToleranceMeters,
    );
    if (projection.distanceFromRoute > maximumRouteDistanceMeters) {
      _routeRecoveryPending = true;
      return projection;
    }
    if (!_routeRecoveryPending) return projection;

    // A short route departure can end before the rerouting timers have fired.
    // Re-anchor guidance here as part of every regular position update, so a
    // stale progress window cannot leave "Watch the map" active indefinitely.
    final recovered = _projectOntoRoute(route.points, position);
    if (recovered.distanceFromRoute > maximumRouteDistanceMeters) {
      return projection;
    }
    _routeRecoveryPending = false;
    _routeProgress = recovered.distanceAlongRoute;
    _index = 0;
    _approachSpoken = false;
    _nowSpoken = false;
    _offRouteUpdates = 0;
    _offRouteWarningSpoken = false;
    _advancePastManeuvers(_routeProgress);
    projection = _projectOntoRoute(
      route.points,
      position,
      minimumDistanceAlongRoute: _routeProgress,
      maximumDistanceAlongRoute: _routeProgress + _maximumProgressJumpMeters,
      preferEarlierWithinMeters: _projectionContinuityToleranceMeters,
    );
    return projection;
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

  bool _isIntermediateArrival(int index) => index < _intermediateArrivalCount;

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
          : 'Du hast das Ziel erreicht.';
    }
    final name = _intermediateName(index);
    final number = index + 1;
    if (english) {
      return name == null
          ? 'You have reached intermediate destination $number.'
          : 'You have reached intermediate destination $number, $name.';
    }
    return name == null
        ? 'Du hast das Zwischenziel $number erreicht.'
        : 'Du hast das Zwischenziel $number, $name, erreicht.';
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

  bool _isOverlappingProgress(double progress) =>
      _overlappingRouteIntervals.any((interval) => interval.contains(progress));

  static List<_RouteInterval> _repeatedRouteIntervals(List<LatLng> points) {
    final repeatedKeys = repeatedRouteSegmentKeys(points);
    final intervals = <_RouteInterval>[];
    var distanceAlongRoute = 0.0;
    for (var index = 0; index < points.length - 1; index++) {
      final segmentLength = const Distance().as(
        LengthUnit.Meter,
        points[index],
        points[index + 1],
      );
      final key = routeSegmentKey(points[index], points[index + 1]);
      if (key != null && repeatedKeys.contains(key)) {
        intervals.add(
          _RouteInterval(
            distanceAlongRoute,
            distanceAlongRoute + segmentLength,
          ),
        );
      }
      distanceAlongRoute += segmentLength;
    }
    return intervals;
  }

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

  /// OSRM occasionally labels a shallow transition onto an offset cycle path
  /// as a normal turn. Use the actual route geometry to avoid directing riders
  /// into a nearby cross street.
  static RouteManeuver _adjustTurnModifierFromGeometry(
    List<LatLng> route,
    RouteManeuver maneuver,
    double routeDistance,
  ) {
    if (maneuver.type != 'turn' ||
        (maneuver.modifier != 'right' && maneuver.modifier != 'left') ||
        routeDistance < 8) {
      return maneuver;
    }
    final totalDistance = _routeLength(route);
    if (totalDistance - routeDistance < 8) return maneuver;

    const sampleDistance = 12.0;
    final before = _pointAlongRoute(
      route,
      max(0, routeDistance - sampleDistance),
    );
    final at = _pointAlongRoute(route, routeDistance);
    final after = _pointAlongRoute(
      route,
      min(totalDistance, routeDistance + sampleDistance),
    );
    final turnDegrees = _angleBetweenSegments(before, at, at, after);
    // Do not reinterpret tests/routes whose maneuver is not represented in the
    // overview geometry (near 0 degrees), or genuine turns above 50 degrees.
    if (turnDegrees < 15 || turnDegrees > 50) return maneuver;

    return RouteManeuver(
      location: maneuver.location,
      type: maneuver.type,
      modifier: maneuver.modifier == 'right' ? 'slight right' : 'slight left',
      roadName: maneuver.roadName,
      exit: maneuver.exit,
    );
  }

  static double _routeLength(List<LatLng> route) {
    const distance = Distance();
    var result = 0.0;
    for (var index = 0; index < route.length - 1; index++) {
      result += distance
          .as(LengthUnit.Meter, route[index], route[index + 1])
          .toDouble();
    }
    return result;
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
          : 'Du hast das Ziel erreicht.';
    }

    final action = _action(maneuver, english);
    if (now) {
      return english ? '${_sentenceCase(action)} here.' : 'Hier $action.';
    }
    return english
        ? 'In $distanceMeters meters, $action.'
        : 'In $distanceMeters Metern $action.';
  }

  static String _formatDisplay(
    RouteManeuver maneuver, {
    required bool english,
    required double remainingMeters,
  }) {
    if (remainingMeters <= 15) {
      final action = _action(maneuver, english);
      return english ? '${_sentenceCase(action)} here' : 'Hier $action';
    }
    final action = _shortAction(maneuver, english);
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

  static String _sentenceCase(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';

  static _RouteProjection _projectOntoRoute(
    List<LatLng> route,
    LatLng point, {
    double minimumDistanceAlongRoute = 0,
    double maximumDistanceAlongRoute = double.infinity,
    double preferEarlierWithinMeters = 0,
  }) {
    var cumulative = 0.0;
    final candidates = <_RouteProjection>[];
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
          distanceAlong - 1 <= maximumDistanceAlongRoute) {
        candidates.add(
          _RouteProjection(distanceAlong, sqrt(distanceSquared)),
        );
      }
      cumulative += segmentLength;
    }
    if (candidates.isEmpty) {
      return const _RouteProjection(0, double.infinity);
    }
    final closestDistance =
        candidates.map((candidate) => candidate.distanceFromRoute).reduce(min);
    final plausible = candidates
        .where(
          (candidate) =>
              candidate.distanceFromRoute <=
              closestDistance + preferEarlierWithinMeters,
        )
        .toList();
    final selected = plausible.reduce(
      (earlier, candidate) =>
          candidate.distanceAlongRoute < earlier.distanceAlongRoute
              ? candidate
              : earlier,
    );
    final isAmbiguous = preferEarlierWithinMeters > 0 &&
        plausible.any(
          (candidate) =>
              (candidate.distanceAlongRoute - selected.distanceAlongRoute)
                  .abs() >=
              _ambiguousRouteSeparationMeters,
        );
    return _RouteProjection(
      selected.distanceAlongRoute,
      selected.distanceFromRoute,
      isAmbiguous: isAmbiguous,
    );
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
    this.distanceFromRoute, {
    this.isAmbiguous = false,
  });

  final double distanceAlongRoute;
  final double distanceFromRoute;
  final bool isAmbiguous;
}

class _RouteInterval {
  const _RouteInterval(this.start, this.end);

  final double start;
  final double end;

  bool contains(double value) => value >= start - 1 && value <= end + 1;
}

class VoiceGuidanceDisplay {
  const VoiceGuidanceDisplay({
    required this.text,
    required this.type,
    this.modifier,
    this.isFinalDestination = false,
  });

  final String text;
  final String type;
  final String? modifier;
  final bool isFinalDestination;

  @override
  bool operator ==(Object other) =>
      other is VoiceGuidanceDisplay &&
      text == other.text &&
      type == other.type &&
      modifier == other.modifier &&
      isFinalDestination == other.isFinalDestination;

  @override
  int get hashCode => Object.hash(text, type, modifier, isFinalDestination);
}
