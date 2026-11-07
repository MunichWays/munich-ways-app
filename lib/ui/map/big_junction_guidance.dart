import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../../model/big_junction.dart';
import '../../common/logger_setup.dart';

/// Optional crossing state. Route progress remains owned by VoiceGuidance.
class BigJunctionGuidance {
  List<RouteBigJunction> _junctions = const [];
  final Set<String> _armed = {}, _completed = {}, _hundred = {}, _sixty = {};
  RouteBigJunction? _active;
  DateTime? _lastFix;
  LatLng? _lastInside;
  int _outsideFixes = 0;
  bool wrongExit = false;
  double? _wrongExitDistance;
  bool get quiet => _active != null;
  RouteBigJunction? get active => _active;

  void reset(List<RouteBigJunction> junctions) {
    _junctions = junctions;
    _armed.clear();
    _completed.clear();
    _hundred.clear();
    _sixty.clear();
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
    if (!accuracy.isFinite || accuracy < 0 || accuracy > 50) return null;
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
          break;
        }
      }
      return null;
    }
    if (current.contains(position)) {
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
        remaining > 100) return null;
    final id = junction.occurrenceId;
    if (!repeat) {
      if (remaining <= 60) {
        if (!_sixty.add(id)) return null;
        _hundred.add(id);
      } else if (!_hundred.add(id)) {
        return null;
      }
    }
    final rounded = max(10, (remaining / 10).round() * 10);
    log.i('Big junction: advance ${rounded}m $id');
    return english
        ? 'In $rounded meters, ${junction.action(true)}.'
        : 'In $rounded Metern ${junction.action(false)}.';
  }
}
