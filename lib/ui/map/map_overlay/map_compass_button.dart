import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
  });

  final ValueNotifier<double> mapBearingDegrees;
  final ValueNotifier<int> mapIdleTick;
  final LocationState locationState;
  final Future<void> Function() onNorthUp;
  final Future<double?> Function() queryMapBearingDegrees;

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
    if (!_visible) {
      if (!_pendingHideAfterNorthUp &&
          smallestBearingAngleToNorthDegrees(bearing) >
              kMapCompassShowBearingThresholdDeg) {
        setState(() => _visible = true);
      }
      return;
    }
    setState(() {});
  }

  void _onMapIdleTick() {
    unawaited(_tryFinishHideAfterNorthUp());
  }

  Future<void> _tryFinishHideAfterNorthUp() async {
    if (!_pendingHideAfterNorthUp || !mounted) return;
    final bearing = await widget.queryMapBearingDegrees();
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

  static const double _kSlotSize = 48;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kSlotSize,
      height: _kSlotSize,
      child: IgnorePointer(
        ignoring: !_visible,
        child: _visible ? _buildVisibleCompass() : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildVisibleCompass() {
    final needleRadians = vector_math.radians(-widget.mapBearingDegrees.value);
    return Tooltip(
      message: 'Norden nach oben ausrichten',
      child: Material(
        color: Colors.black.withValues(alpha: 0.36),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        shadowColor: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => unawaited(_onCompassPressed()),
          child: SizedBox(
            width: _kSlotSize,
            height: _kSlotSize,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                IgnorePointer(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: needleRadians,
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
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
    );
  }
}
