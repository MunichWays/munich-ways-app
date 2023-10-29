import 'dart:async';
import 'dart:math' as math;
import 'dart:math';
import 'dart:ui' as ui show Image;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';
import 'package:vector_math/vector_math.dart' as vector_math;

class DestinationOffScreenWidget extends StatefulWidget {
  final Place destination;
  final String imageAssetPath;

  const DestinationOffScreenWidget(
      {Key? key,
      required this.destination,
      this.imageAssetPath = "images/bearing_arrow.png"})
      : super(key: key);

  @override
  State<DestinationOffScreenWidget> createState() =>
      _DestinationOffScreenWidgetState();
}

class _DestinationOffScreenWidgetState
    extends State<DestinationOffScreenWidget> {
  ui.Image? image;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<Null> init() async {
    final ByteData data = await rootBundle.load(widget.imageAssetPath);
    image = await decodeImageFromList(new Uint8List.view(data.buffer));
  }

  @override
  Widget build(BuildContext context) {
    MapCamera map = MapCamera.of(context);

    Point destinationPoint = map.latLngToScreenPoint(widget.destination.latLng);
    Offset destinationOffset =
        Offset(destinationPoint.x.toDouble(), destinationPoint.y.toDouble());

    if (image != null) {
      double statusBarHeight = MediaQuery.of(context).padding.top;
      return CustomPaint(
          foregroundPainter: PositionOutsideScreenPainter(
              destinationOffset, map, image!, statusBarHeight),
          child: Container());
    } else {
      log.d("image is null");
      return Container();
    }
  }
}

class PositionOutsideScreenPainter extends CustomPainter {
  final Offset offset;
  final MapCamera map;
  final ui.Image image;
  final double statusBarHeight;

  PositionOutsideScreenPainter(
      this.offset, this.map, this.image, this.statusBarHeight);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    map.latLngToScreenPoint(map.center);

    bool isOffScreen = offset.dx < 0 ||
        offset.dx > size.width ||
        offset.dy < 0 ||
        offset.dy > size.height;

    //canvas.drawCircle(offset, 5, paint);
    //canvas.drawLine(screenCenterPoint, offset, paint);

    Offset center = Offset(size.width / 2, size.height / 2);
    double slope = (center.dy - offset.dy) / (center.dx - offset.dx);

    Offset pointOnScreenBorder = Offset(0, 0);

    //vertical checks
    double ay = slope * size.width / 2;
    if (-size.height / 2 <= ay && ay <= size.height / 2) {
      if (center.dx < offset.dx) {
        //"right edge"
        pointOnScreenBorder = Offset(
            center.dx + size.width / 2, center.dy + slope * (size.width / 2));
      } else {
        //"left edge"
        pointOnScreenBorder = Offset(
            center.dx - size.width / 2, center.dy - slope * (size.width / 2));
      }
    }

    //horizontal checks
    double ax = (size.height / 2) / slope;
    if (-size.width / 2 <= ax && ax <= size.width / 2) {
      if (center.dy > offset.dy) {
        //top edge
        pointOnScreenBorder = Offset(
            center.dx - (size.height / 2) / slope, center.dy - size.height / 2);
      } else {
        //bottom edge
        pointOnScreenBorder = Offset(
            center.dx + (size.height / 2) / slope, center.dy + size.height / 2);
      }
    }

    double topPadding = statusBarHeight + 66;
    const double bottomPadding = 54;
    double y = math.min(math.max(topPadding, pointOnScreenBorder.dy),
        size.height - bottomPadding);

    pointOnScreenBorder = Offset(pointOnScreenBorder.dx, y);

    if (isOffScreen) {
      canvas.save();
      canvas.translate(pointOnScreenBorder.dx, pointOnScreenBorder.dy);

      double angle = math.atan2(pointOnScreenBorder.dy - center.dy,
          pointOnScreenBorder.dx - center.dx);
      if (angle < 0) {
        angle += 2 * math.pi;
      }

      //log.d("angle rad: $angle");
      //log.d("angle deg: ${vector_math.degrees(angle)}");
      canvas.rotate(angle + vector_math.radians(90));
      canvas.drawImage(image, Offset(-(image.width / 2).toDouble(), 0), paint);

      canvas.translate(-pointOnScreenBorder.dx, -pointOnScreenBorder.dy);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
