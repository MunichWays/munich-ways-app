import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:munich_ways/model/route.dart';

/// Rounded presentation data, never a source of navigation progress.
class NavigationRemaining {
  const NavigationRemaining._(this.route, this.hundredsOfMeters, this.minutes);

  static NavigationRemaining? estimate(
    CycleRoute route,
    double remainingFraction, {
    bool destinationReached = false,
  }) {
    final distance = route.navigationDistance ?? route.distance;
    final duration = route.navigationDuration ?? route.duration;
    if (!remainingFraction.isFinite ||
        !distance.isFinite ||
        distance <= 0 ||
        !duration.isFinite ||
        duration <= 0) return null;
    final fraction = remainingFraction.clamp(0.0, 1.0);
    return NavigationRemaining._(
      route,
      destinationReached ? 0 : max(1, (distance * fraction / 100).round()),
      destinationReached ? 0 : max(1, (duration * fraction / 60).round()),
    );
  }

  final CycleRoute route;
  final int hundredsOfMeters;
  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is NavigationRemaining &&
      identical(route, other.route) &&
      hundredsOfMeters == other.hundredsOfMeters &&
      minutes == other.minutes;

  @override
  int get hashCode => Object.hash(route, hundredsOfMeters, minutes);
}

/// Expires only the displayed estimate. Owns no GPS, routing or speech work.
class NavigationRemainingController
    extends ValueNotifier<NavigationRemaining?> {
  NavigationRemainingController({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(null);

  static const maximumFixAge = Duration(seconds: 15);
  final DateTime Function() _now;
  Timer? _expiry;
  DateTime? _fixTime;
  bool _paused = false;

  /// Pausing freezes presentation only; navigation remains owned by the model.
  void setPaused(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    _cancelExpiry();
    if (!paused && value != null && value!.hundredsOfMeters != 0) {
      final age = _now().difference(_fixTime!);
      final remaining = maximumFixAge - age;
      _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, clear);
    }
  }

  void update(NavigationRemaining? estimate, {required DateTime fixTime}) {
    if (_paused) return;
    _cancelExpiry();
    final age = _now().difference(fixTime);
    if (estimate == null || age.isNegative || age >= maximumFixAge) {
      value = null;
      return;
    }
    _fixTime = fixTime;
    value = estimate;
    // Confirmed arrival is latched by navigation and needs no further GPS.
    if (estimate.hundredsOfMeters != 0) {
      _expiry = Timer(maximumFixAge - age, clear);
    }
  }

  void _cancelExpiry() {
    _expiry?.cancel();
    _expiry = null;
  }

  void clear() {
    _cancelExpiry();
    _fixTime = null;
    value = null;
  }

  @override
  void dispose() {
    _cancelExpiry();
    super.dispose();
  }
}
