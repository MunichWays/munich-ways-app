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

/// Map reset control: needle rotates with [mapBearingDegrees] (camera bearing)
/// so it tracks two-finger map rotation, not device orientation.
class CompassButton extends StatelessWidget {
  final VoidCallback? onPressed;

  /// Clockwise degrees from north (same as [CameraPosition.bearing]).
  final double mapBearingDegrees;

  const CompassButton({
    Key? key,
    required this.onPressed,
    this.mapBearingDegrees = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double needleRadians = vector_math.radians(-mapBearingDegrees);

    return FloatingActionButton.small(
      heroTag: null,
      tooltip: 'Norden nach oben ausrichten',
      backgroundColor: Colors.white,
      onPressed: onPressed,
      child: SizedBox(
        width: 36,
        height: 36,
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
                  border: Border.all(color: Colors.black26, width: 1),
                ),
              ),
            ),
            Transform.rotate(
              angle: needleRadians,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Image(
                  image: AssetImage('images/compass.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns when the compass is shown or hidden; parent updates [mapBearingDegrees]
/// on camera move and bumps [mapIdleTick] on [MapLibreMap.onCameraIdle].
class MapCompassControl extends StatefulWidget {
  const MapCompassControl({
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
  State<MapCompassControl> createState() => _MapCompassControlState();
}

class _MapCompassControlState extends State<MapCompassControl> {
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
  void didUpdateWidget(MapCompassControl oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 6.0),
        child: CompassButton(
          mapBearingDegrees: widget.mapBearingDegrees.value,
          onPressed: () {
            unawaited(_onCompassPressed());
          },
        ),
      ),
    );
  }
}
