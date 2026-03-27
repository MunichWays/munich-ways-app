import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vector_math;

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
