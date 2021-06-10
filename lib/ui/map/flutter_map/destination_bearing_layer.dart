import 'package:flutter/material.dart';

class DestinationBearingLayerWidget extends StatelessWidget {
  final bool visible;
  final double bearing;
  final GestureTapCallback onTap;

  const DestinationBearingLayerWidget(
      {Key key, this.visible, this.bearing, this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!visible || bearing == null) {
      return Container();
    }
    return Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: RotationTransition(
              turns: AlwaysStoppedAnimation(bearing / 360),
              child: GestureDetector(
                child: Image(image: AssetImage('images/bearing_arrow.png')),
                onTap: onTap,
              )),
        ));
  }
}
