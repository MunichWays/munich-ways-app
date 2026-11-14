import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../../model/big_junction.dart';
import '../../common/logger_setup.dart';

/// Optional crossing state. Route progress remains owned by VoiceGuidance.
class BigJunctionGuidance {
  static const firstAnnouncementDistanceMeters = 120.0;
  static const secondAnnouncementDistanceMeters = 40.0;
  List<RouteBigJunction> _junctions = const [];
  final Set<String> _armed = {},
      _completed = {},
      _firstAnnounced = {},
      _secondAnnounced = {};
  RouteBigJunction? _active;
  DateTime? _lastFix;
  LatLng? _lastInside;
  int _outsideFixes = 0;
  bool wrongExit = false;
  double? _wrongExitDistance;
  final Set<String> _checkpointSpoken = {};
  LatLng? _motionAnchor, _displayPoint;
  DateTime? _motionAnchorAt, _bearingAt;
  double _motionAccuracy = 0;
  double? _observedBearing;
  Map<String, String>? _pendingInstruction, _displayInstruction;
  String? checkpointModifier;
  bool get quiet => _active != null;

  String? checkpointDisplay(bool english) =>
      _displayInstruction?[english ? 'en' : 'de'];

  String? takeCheckpointInstruction(bool english) {
    final text =
        _active == null ? null : _pendingInstruction?[english ? 'en' : 'de'];
    _pendingInstruction = null;
    return text;
  }

  void _observeCheckpointMotion(
      LatLng position, DateTime time, double accuracy) {
    _pendingInstruction = null;
    if (_displayPoint != null &&
        const Distance().as(LengthUnit.Meter, position, _displayPoint!) > 15) {
      _displayInstruction = null;
      _displayPoint = null;
      checkpointModifier = null;
    }
    final anchor = _motionAnchor, at = _motionAnchorAt;
    final elapsed =
        at == null ? 0.0 : time.difference(at).inMilliseconds / 1000;
    if (accuracy > 15 || anchor == null || elapsed > 8) {
      _motionAnchor = accuracy <= 15 ? position : null;
      _motionAnchorAt = time;
      _motionAccuracy = accuracy;
      _observedBearing = null;
      _bearingAt = null;
      return;
    }
    final movement = const Distance().as(LengthUnit.Meter, anchor, position);
    if (movement > 12 * elapsed + max(accuracy, _motionAccuracy) * 2) {
      _motionAnchor = position;
      _motionAnchorAt = time;
      _motionAccuracy = accuracy;
      _observedBearing = null;
      _bearingAt = null;
      return;
    }
    if (movement >= (max(accuracy, _motionAccuracy) * 1.5).clamp(8.0, 25.0)) {
      _observedBearing = const Distance().bearing(anchor, position);
      _bearingAt = time;
      _motionAnchor = position;
      _motionAnchorAt = time;
      _motionAccuracy = accuracy;
    }
  }

  void _observeCheckpoints(RouteBigJunction junction, LatLng position,
      DateTime time, double accuracy) {
    final checkpoints = junction.sequence?.checkpoints;
    if (checkpoints == null ||
        accuracy > 15 ||
        _observedBearing == null ||
        _bearingAt == null ||
        time.difference(_bearingAt!) > const Duration(seconds: 3)) return;
    double angle(double a, double b) => ((a - b + 540) % 360 - 180).abs();
    for (var index = 0; index < checkpoints.length; index++) {
      final checkpoint = checkpoints[index];
      final key = '${junction.occurrenceId}:${checkpoint.id}';
      if (_checkpointSpoken.contains(key)) continue;
      final distance =
          const Distance().as(LengthUnit.Meter, position, checkpoint.location);
      if (distance > 12 ||
          (distance > 3 &&
              angle(_observedBearing!,
                      const Distance().bearing(position, checkpoint.location)) >
                  80)) continue;
      final aligned = checkpoint.alignedInstruction != null &&
          angle(_observedBearing!, checkpoint.outgoingBearing) <= 25;
      // At the exact corner a heading from before a recent turn is unsafe.
      // In particular it must not turn an already aligned rider back to right.
      if (checkpoint.alignedInstruction != null &&
          distance <= 3 &&
          _bearingAt != time) continue;
      if (checkpoint.alignedInstruction != null &&
          !aligned &&
          distance > .5 &&
          angle(checkpoint.incomingBearing,
                  const Distance().bearing(position, checkpoint.location)) >
              40) continue;
      if (!aligned && angle(_observedBearing!, checkpoint.incomingBearing) > 40)
        continue;
      for (final earlier in checkpoints.take(index + 1)) {
        _checkpointSpoken.add('${junction.occurrenceId}:${earlier.id}');
      }
      _pendingInstruction =
          aligned ? checkpoint.alignedInstruction : checkpoint.instruction;
      _displayInstruction = _pendingInstruction;
      _displayPoint = checkpoint.location;
      checkpointModifier = aligned ? 'straight' : checkpoint.modifier;
      log.i(
          'Big junction checkpoint: $key, ${aligned ? 'aligned' : 'planned'} approach');
      return;
    }
  }

  RouteBigJunction? get active => _active;

  void reset(List<RouteBigJunction> junctions) {
    _junctions = junctions;
    _checkpointSpoken.clear();
    _motionAnchor = null;
    _motionAnchorAt = null;
    _observedBearing = null;
    _bearingAt = null;
    _pendingInstruction = null;
    _displayInstruction = null;
    _displayPoint = null;
    checkpointModifier = null;
    _armed.clear();
    _completed.clear();
    _firstAnnounced.clear();
    _secondAnnounced.clear();
    _active = null;
    _lastFix = null;
    _lastInside = null;
    _outsideFixes = 0;
    wrongExit = false;
    _wrongExitDistance = null;
  }

  /// Called once per actual GPS fix, never by display/off-route query methods.
  double? observe(LatLng position,
      {required DateTime fixTime,
      required double accuracy,
      required double progress,
      required double distanceFromRoute}) {
    if (_lastFix != null && !fixTime.isAfter(_lastFix!)) return null;
    _lastFix = fixTime;
    if (!accuracy.isFinite || accuracy < 0 || accuracy > 50) {
      _motionAnchor = null;
      _observedBearing = null;
      _pendingInstruction = null;
      return null;
    }
    _observeCheckpointMotion(position, fixTime, accuracy);
    if (wrongExit) {
      if (distanceFromRoute <= 15 &&
          _wrongExitDistance != null &&
          progress >= _wrongExitDistance! + 10) {
        wrongExit = false;
        _wrongExitDistance = null;
      }
      return null;
    }
    final current = _active;
    if (current == null) {
      for (final junction in _junctions) {
        if (_completed.contains(junction.occurrenceId)) continue;
        if (!junction.contains(position)) {
          if (distanceFromRoute <= 15 &&
              progress >= junction.entryDistance - 120 &&
              progress < junction.entryDistance &&
              accuracy <= 20) _armed.add(junction.occurrenceId);
        } else if (_armed.contains(junction.occurrenceId) &&
            progress >= junction.entryDistance - 30 &&
            progress <= junction.entryDistance + 40 &&
            accuracy <= 20 &&
            const Distance().as(LengthUnit.Meter, position, junction.entry) <=
                25) {
          _active = junction;
          log.i('Big junction: entered ${junction.occurrenceId}');
          _lastInside = position;
          _outsideFixes = 0;
          _observeCheckpoints(junction, position, fixTime, accuracy);
          break;
        }
      }
      return null;
    }
    if (current.contains(position)) {
      _observeCheckpoints(current, position, fixTime, accuracy);
      _lastInside = position;
      _outsideFixes = 0;
      return null;
    }
    if (current.boundaryDistance(position) < max(8, accuracy)) {
      _outsideFixes = 0;
      return null;
    }
    if (++_outsideFixes < 2) return null;
    final from = _lastInside ?? current.exit;
    final mx = cos(position.latitude * pi / 180);
    final dx = (position.longitude - from.longitude) * mx,
        dy = position.latitude - from.latitude;
    final rx = (current.outgoing.longitude - current.exit.longitude) * mx;
    final ry = current.outgoing.latitude - current.exit.latitude;
    final scale = sqrt(dx * dx + dy * dy) * sqrt(rx * rx + ry * ry);
    final forward = scale > 0 && (dx * rx + dy * ry) / scale >= .5;
    final correct =
        const Distance().as(LengthUnit.Meter, position, current.exit) <= 40 &&
            progress >= current.exitDistance - 10 &&
            progress <= current.exitDistance + 60 &&
            distanceFromRoute <= 20 &&
            forward;
    _completed.add(current.occurrenceId);
    _active = null;
    _pendingInstruction = null;
    _displayInstruction = null;
    checkpointModifier = null;
    _lastInside = null;
    _outsideFixes = 0;
    wrongExit = !correct;
    _wrongExitDistance = correct ? null : current.exitDistance;
    log.i(
        'Big junction: exit ${correct ? 'correct' : 'wrong'} ${current.occurrenceId}');
    return correct ? current.exitDistance : null;
  }

  String? announce(RouteBigJunction junction, double remaining,
      {required bool english, bool repeat = false}) {
    if (quiet ||
        wrongExit ||
        _completed.contains(junction.occurrenceId) ||
        remaining < 0 ||
        remaining > firstAnnouncementDistanceMeters) return null;
    final id = junction.occurrenceId;
    if (!repeat) {
      if (remaining <= secondAnnouncementDistanceMeters) {
        if (!_secondAnnounced.add(id)) return null;
        _firstAnnounced.add(id);
      } else if (!_firstAnnounced.add(id)) {
        return null;
      }
    }
    final rounded = max(10, (remaining / 10).round() * 10);
    log.i('Big junction: advance ${rounded}m $id');
    final action = junction.action(english);
    return '${action[0].toUpperCase()}${action.substring(1)}.';
  }
}
