import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:munich_ways/common/logger_setup.dart';

class ClickablePolyline extends Polyline {
  VoidCallback? onTap;

  ClickablePolyline(
      {required points,
      strokeWidth = 1.0,
      color = const Color(0xFF00FF00),
      borderStrokeWidth = 0.0,
      borderColor = const Color(0xFFFFFF00),
      gradientColors,
      colorsStop,
      isDotted = false,
      this.onTap})
      : super(
          points: points,
          strokeWidth: strokeWidth,
          color: color,
          borderStrokeWidth: borderStrokeWidth,
          borderColor: borderColor,
          gradientColors: gradientColors,
          colorsStop: colorsStop,
          isDotted: isDotted,
        );
}

class ClickablePolylineLayer extends StatelessWidget {
  final List<ClickablePolyline> polylines;
  final bool polylineCulling;
  final bool saveLayers;

  ClickablePolylineLayer(
      {Key? key,
      this.polylines = const [],
      this.polylineCulling = false,
      this.saveLayers = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final map = FlutterMapState.maybeOf(context)!;

    return GestureDetector(
        onDoubleTap: () {
          log.d("onDoubleTap");
          map.move(map.center, map.zoom + 1, source: MapEventSource.custom);
        },
        onTapUp: (TapUpDetails details) {
          //Detect nearest polyline to the tapped point
          polylines.forEach((polyline) {
            for (var i = 0; i < polyline.offsets.length - 1; i++) {
              Offset x = polyline.offsets[i];
              Offset y = polyline.offsets[i + 1];
              Offset tap = details.localPosition;

              double a = _dist(x, y);
              double b = _dist(x, tap);
              double c = _dist(y, tap);

              // Use Herons formula to calculate area of triangle and from there the height
              // https://www.khanacademy.org/math/in-in-grade-9-ncert/xfd53e0255cd302f8:surface-areas-and-volumes/xfd53e0255cd302f8:herons-formula/v/heron-s-formula
              double s = (a + b + c) / 2.0;
              double area = sqrt(s * (s - a) * (s - b) * (s - c));
              double height = (2 * area) / a;

              /*
                Ensure tap is between x and y or inside the threshold of one of the points
                Use Pythagoras: d = sqrt((c*c - h*h)) or d = sqrt((b*b - h*h))

                In following case b is used (because its the hypotenuse) for our triangle:

                x-------a--------y...d......z
                 ---              -         .
                    ---             -       .
                   b    ---         c -     .height
                          ---          -    .
                             ---         -  .
                                ------------tap
              */

              double aAndD = sqrt((_sqr(max(b, c))) - _sqr(height));
              double distanceToA = aAndD - a;
              double threshold = 20;

              if (height < threshold && distanceToA < threshold) {
                log.d("Click found");
                if (polyline.onTap != null) {
                  polyline.onTap!();
                }
                return;
              }
            }
          });
        },
        child: PolylineLayer(
                polylines: polylines,
                polylineCulling: polylineCulling,
                saveLayers: saveLayers)
            .build(context));
  }

  double _dist(Offset v, Offset w) {
    return sqrt(_dist2(v, w));
  }

  double _dist2(Offset v, Offset w) {
    return _sqr(v.dx - w.dx) + _sqr(v.dy - w.dy);
  }

  double _sqr(double x) {
    return x * x;
  }
}
