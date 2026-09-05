import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:vector_math/vector_math.dart' as vector_math;

import 'package:munich_ways/ui/map/map_screen_model.dart';

/// Show compass when map bearing differs from north by more than this (noise gate).
const double kMapCompassShowBearingThresholdDeg = 2.0;

/// Smallest angle (0–180°) between [bearing] and north.
double smallestBearingAngleToNorthDegrees(double bearing) {
  var b = bearing % 360.0;
  if (b < 0) b += 360.0;
  return math.min(b, 360.0 - b);
}

/// Owns when the compass is shown or hidden; parent updates [mapBearingDegrees]
/// on camera move and bumps [mapIdleTick] on map idle.
class MapCompassOverlayButton extends StatefulWidget {
  const MapCompassOverlayButton({
    super.key,
    required this.mapBearingDegrees,
    required this.mapIdleTick,
    required this.locationState,
    required this.onNorthUp,
    required this.queryMapBearingDegrees,
    this.alwaysVisible = false,
  });

  final ValueNotifier<double> mapBearingDegrees;
  final ValueNotifier<int> mapIdleTick;
  final LocationState locationState;
  final Future<void> Function() onNorthUp;
  final Future<double?> Function() queryMapBearingDegrees;
  final bool alwaysVisible;

  @override
  State<MapCompassOverlayButton> createState() =>
      _MapCompassOverlayButtonState();
}

class _MapCompassOverlayButtonState extends State<MapCompassOverlayButton> {
  bool _visible = false;
  bool _pendingHideAfterNorthUp = false;

  @override
  void initState() {
    super.initState();
    widget.mapBearingDegrees.addListener(_onBearingChanged);
    widget.mapIdleTick.addListener(_onMapIdleTick);
    if (widget.locationState == LocationState.FOLLOW_AND_ROTATE_MAP) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_visible) {
          setState(() => _visible = true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(MapCompassOverlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapBearingDegrees != widget.mapBearingDegrees) {
      oldWidget.mapBearingDegrees.removeListener(_onBearingChanged);
      widget.mapBearingDegrees.addListener(_onBearingChanged);
    }
    if (oldWidget.mapIdleTick != widget.mapIdleTick) {
      oldWidget.mapIdleTick.removeListener(_onMapIdleTick);
      widget.mapIdleTick.addListener(_onMapIdleTick);
    }
    if (oldWidget.locationState != widget.locationState) {
      final enteredFollowAndRotate =
          widget.locationState == LocationState.FOLLOW_AND_ROTATE_MAP &&
              oldWidget.locationState != LocationState.FOLLOW_AND_ROTATE_MAP;
      if (enteredFollowAndRotate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_visible) {
            setState(() => _visible = true);
          }
        });
      }
      // Ending navigation can change native tracking without emitting a
      // Flutter onCameraMove callback. Re-read the real bearing so a rotated
      // map never remains without orientation feedback.
      unawaited(_refreshVisibilityFromMap());
    }
  }

  @override
  void dispose() {
    widget.mapBearingDegrees.removeListener(_onBearingChanged);
    widget.mapIdleTick.removeListener(_onMapIdleTick);
    super.dispose();
  }

  void _onBearingChanged() {
    if (!mounted) return;
    final bearing = widget.mapBearingDegrees.value;
    final differsFromNorth = smallestBearingAngleToNorthDegrees(bearing) >
        kMapCompassShowBearingThresholdDeg;
    if (differsFromNorth && _pendingHideAfterNorthUp) {
      _pendingHideAfterNorthUp = false;
    }
    if (!_visible) {
      if (differsFromNorth) {
        setState(() => _visible = true);
      }
      return;
    }
    setState(() {});
  }

  void _onMapIdleTick() {
    unawaited(_refreshVisibilityFromMap());
  }

  Future<void> _refreshVisibilityFromMap() async {
    if (!mounted) return;
    final bearing = await widget.queryMapBearingDegrees();
    if (!mounted || bearing == null) return;
    final differsFromNorth = smallestBearingAngleToNorthDegrees(bearing) >
        kMapCompassShowBearingThresholdDeg;
    if (differsFromNorth) {
      if (!_visible || _pendingHideAfterNorthUp) {
        setState(() {
          _visible = true;
          _pendingHideAfterNorthUp = false;
        });
      }
      return;
    }
    await _tryFinishHideAfterNorthUp(knownBearing: bearing);
  }

  Future<void> _tryFinishHideAfterNorthUp({double? knownBearing}) async {
    if (!_pendingHideAfterNorthUp || !mounted) return;
    final bearing = knownBearing ?? await widget.queryMapBearingDegrees();
    if (!mounted || bearing == null) return;
    final delta = smallestBearingAngleToNorthDegrees(bearing);
    if (delta <= kMapCompassShowBearingThresholdDeg) {
      setState(() {
        _visible = false;
        _pendingHideAfterNorthUp = false;
      });
    }
  }

  Future<void> _onCompassPressed() async {
    _pendingHideAfterNorthUp = true;
    await widget.onNorthUp();
    if (mounted) {
      await _tryFinishHideAfterNorthUp();
    }
  }

  static const double _kTapTargetSize = 56;
  static const double _kVisualSize = 40;

  @override
  Widget build(BuildContext context) {
    final visible = widget.alwaysVisible || _visible;
    return SizedBox(
      width: _kTapTargetSize,
      height: _kTapTargetSize,
      child: IgnorePointer(
        ignoring: !visible,
        child:
            visible ? _buildVisibleCompass(context) : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildVisibleCompass(BuildContext context) {
    final needleRadians = vector_math.radians(-widget.mapBearingDegrees.value);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final label = context.l10n.isEnglish
        ? 'Orient map north up'
        : 'Norden nach oben ausrichten';
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: () => unawaited(_onCompassPressed()),
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(_onCompassPressed()),
          child: Center(
            child: IgnorePointer(
              child: SizedBox.square(
                dimension: _kVisualSize,
                child: Material(
                  color: dark
                      ? const Color(0xFF747C82).withValues(alpha: 0.82)
                      : Colors.black.withValues(alpha: 0.36),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  shadowColor: Colors.transparent,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 1),
                        ),
                      ),
                      Transform.rotate(
                        angle: needleRadians,
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: ExcludeSemantics(
                            child: Image.asset(
                              'images/compass.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
