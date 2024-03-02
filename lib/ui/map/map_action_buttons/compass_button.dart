import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vector_math;

class CompassButton extends StatelessWidget {
  final double rotationInDegrees;
  final VoidCallback? onPressed;

  const CompassButton(
      {Key? key, required this.rotationInDegrees, required this.onPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isVisible = rotationInDegrees % 360 == 0;
    return AnimatedOpacity(
      opacity: isVisible ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: FloatingActionButton.small(
        heroTag: null,
        backgroundColor: Colors.white,
        child: Transform.rotate(
            angle: vector_math.radians(rotationInDegrees % 360),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image(image: AssetImage('images/compass.png')),
            )),
        onPressed: onPressed,
      ),
    );
  }
}
