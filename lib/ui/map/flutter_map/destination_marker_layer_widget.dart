import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';

class DestinationMarkerLayerWidget extends StatelessWidget {
  final Place? destination;

  const DestinationMarkerLayerWidget({Key? key, this.destination})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return destination != null
        ? MarkerLayer(markers: [
            Marker(
                width: 35.0,
                height: 48.0,
                point: destination!.latLng,
                builder: (ctx) => Container(
                      child: Image(image: AssetImage('images/pin.png')),
                    ),
                rotate: true),
          ])
        : Container();
  }
}

//FIXME does not work with rotated map yet
class DestinationOffScreenWidget extends StatelessWidget {
  final Place? destination;
  final Offset? offset;

  const DestinationOffScreenWidget({Key? key, this.destination, this.offset})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        foregroundPainter: DestinationPainter(destination, offset),
        child: Container());
  }
}

class DestinationPainter extends CustomPainter {
  final Place? destination;
  final Offset? offset;

  DestinationPainter(this.destination, this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    if (destination == null) {
      return;
    }

    var paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    Offset screenCenterPoint = Offset(size.width / 2, size.height / 2);
    Offset destinationPoint = Offset(size.width / 2, size.height / 2);

    bool outoffScreen = false;

    if (offset != null) {
      destinationPoint = offset!;
      if (offset!.dx < 0 ||
          offset!.dx > size.width ||
          offset!.dy < 0 ||
          offset!.dy > size.height) {
        outoffScreen = true;
        log.d("HEY Out of screen");
      } else {
        outoffScreen = false;
      }
    }

    canvas.drawCircle(destinationPoint, 5, paint);
    canvas.drawLine(screenCenterPoint, destinationPoint, paint);

    if (offset != null) {
      Offset center = Offset(size.width / 2, size.height / 2);
      double slope = (center.dy - offset!.dy) / (center.dx - offset!.dx);

      Offset pointOnScreenBorder = Offset(0, 0);

      //vertical checks
      double ay = slope * size.width / 2;
      if (-size.height / 2 <= ay && ay <= size.height / 2) {
        if (center.dx < offset!.dx) {
          log.d("right edge");
          pointOnScreenBorder = Offset(
              center.dx + size.width / 2, center.dy + slope * (size.width / 2));
        } else {
          log.d("left edge");
          pointOnScreenBorder = Offset(
              center.dx - size.width / 2, center.dy - slope * (size.width / 2));
        }
      }

      //horizontal checks
      double ax = (size.height / 2) / slope;
      if (-size.width / 2 <= ax && ax <= size.width / 2) {
        if (center.dy > offset!.dy) {
          log.d("top edge");
          pointOnScreenBorder = Offset(center!.dx - (size.height / 2) / slope,
              center.dy - size.height / 2);
        } else {
          log.d("bottom edge");
          pointOnScreenBorder = Offset(center!.dx + (size.height / 2) / slope,
              center.dy + size.height / 2);
        }
      }

      if (outoffScreen) {
        canvas.drawCircle(pointOnScreenBorder, 10, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
