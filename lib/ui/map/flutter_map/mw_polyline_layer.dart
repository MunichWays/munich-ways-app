/*
This file is a copy of C:\flutter\.pub-cache\hosted\pub.dartlang.org\flutter_map-0.13.1\lib\src\layer\polyline_layer.dart,
some names changed to have a prefix MW_, to be used by clickable_polylines.dart instead of the original module.
The linear search through all polylines is replaced by an r-tree search. Some optimizations in _fillOffsets.
*/
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/map/map.dart';
import 'package:latlong2/latlong.dart';
import 'package:r_tree/r_tree.dart';
// import 'package:munich_ways/common/logger_setup.dart';

Rectangle box2Rectangle(LatLngBounds b) {
  Rectangle r = Rectangle(b.west, b.south, b.east - b.west, b.north - b.south);
  return r;
}

class MW_PolylineLayerOptions extends LayerOptions {
  final List<MW_Polyline> polylines;
  final bool polylineCulling;
  List<MW_Polyline> visiblePolylines;
  RTree<MW_Polyline> rtree;

  MW_PolylineLayerOptions({
    Key key,
    this.polylines = const [],
    this.polylineCulling = false,
    Stream<Null> rebuild,
  }) : super(key: key, rebuild: rebuild) {
    rtree = RTree<MW_Polyline>();
    if (polylineCulling) {
      for (var polyline in polylines) {
        final bbox = LatLngBounds.fromPoints(polyline.points);
        polyline.boundingBox = bbox;
        final r = box2Rectangle(bbox);
        final rtd = RTreeDatum(r, polyline);
        rtree.insert(rtd);
      }
    }
    visiblePolylines = [];
  }
}

class MW_Polyline {
  final List<LatLng> points;
  final List<Offset> offsets = [];
  final double strokeWidth;
  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
  final List<Color> gradientColors;
  final List<double> colorsStop;
  final bool isDotted;
  LatLngBounds boundingBox;

  MW_Polyline({
    this.points,
    this.strokeWidth = 1.0,
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.gradientColors,
    this.colorsStop,
    this.isDotted = false,
  });
}

// class PolylineLayerWidget extends StatelessWidget {
//   final PolylineLayerOptions options;

//   PolylineLayerWidget({Key? key, required this.options}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final mapState = MapState.maybeOf(context)!;
//     return PolylineLayer(options, mapState, mapState.onMoved);
//   }
// }

class MW_PolylineLayer extends StatelessWidget {
  final MW_PolylineLayerOptions polylineOpts;
  final MapState map;
  final Stream<Null> stream;

  MW_PolylineLayer(this.polylineOpts, this.map, this.stream)
      : super(key: polylineOpts.key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return _build(context, size);
      },
    );
  }

  Widget _build(BuildContext context, Size size) {
    return StreamBuilder<void>(
      stream: stream, // a Stream<void> or null
      builder: (BuildContext context, _) {
        var polylineWidgets = <Widget>[];
        polylineOpts.visiblePolylines = [];
        final searchRect = box2Rectangle(map.bounds);
        for (var rtd in polylineOpts.rtree.search(searchRect)) {
          final polyline = rtd.value;
          polylineOpts.visiblePolylines.add(polyline);

          polyline.offsets.clear();
          _fillOffsets(polyline.offsets, polyline.points);

          polylineWidgets.add(CustomPaint(
            painter: MW_PolylinePainter(polyline),
            size: size,
          ));
        }

        return Container(
          child: Stack(
            children: polylineWidgets,
          ),
        );
      },
    );
  }

  void _fillOffsets(final List<Offset> offsets, final List<LatLng> points) {
    final zs = map.getZoomScale(map.zoom, map.zoom);
    final cp = map.getPixelOrigin();
    for (var i = 0, len = points.length; i < len; ++i) {
      var point = points[i];

      var pos = map.project(point);
      pos = pos.multiplyBy(zs) - cp;
      final off = Offset(pos.x.toDouble(), pos.y.toDouble());
      offsets.add(off);
      // if (i > 0) { // Why add each point except the first one twice?
      //   offsets.add(off);
      // }
    }
  }
}

class MW_PolylinePainter extends CustomPainter {
  final MW_Polyline polylineOpt;

  MW_PolylinePainter(this.polylineOpt);

  @override
  void paint(Canvas canvas, Size size) {
    if (polylineOpt.offsets.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final paint = Paint()
      ..strokeWidth = polylineOpt.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.srcOver;

    if (polylineOpt.gradientColors == null) {
      paint.color = polylineOpt.color;
    } else {
      polylineOpt.gradientColors.isNotEmpty
          ? paint.shader = _paintGradient()
          : paint.color = polylineOpt.color;
    }

    Paint filterPaint;
    if (polylineOpt.borderColor != null) {
      filterPaint = Paint()
        ..color = polylineOpt.borderColor.withAlpha(255)
        ..strokeWidth = polylineOpt.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.dstOut;
    }

    final borderPaint = polylineOpt.borderStrokeWidth > 0.0
        ? (Paint()
          ..color = polylineOpt.borderColor ?? Color(0x00000000)
          ..strokeWidth =
              polylineOpt.strokeWidth + polylineOpt.borderStrokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..blendMode = BlendMode.srcOver)
        : null;
    var radius = paint.strokeWidth / 2;
    var borderRadius = (borderPaint?.strokeWidth ?? 0) / 2;
    if (polylineOpt.isDotted) {
      var spacing = polylineOpt.strokeWidth * 1.5;
      canvas.saveLayer(rect, Paint());
      if (borderPaint != null && filterPaint != null) {
        _paintDottedLine(
            canvas, polylineOpt.offsets, borderRadius, spacing, borderPaint);
        _paintDottedLine(
            canvas, polylineOpt.offsets, radius, spacing, filterPaint);
      }
      _paintDottedLine(canvas, polylineOpt.offsets, radius, spacing, paint);
      canvas.restore();
    } else {
      paint.style = PaintingStyle.stroke;
      canvas.saveLayer(rect, Paint());
      if (borderPaint != null && filterPaint != null) {
        borderPaint.style = PaintingStyle.stroke;
        _paintLine(canvas, polylineOpt.offsets, borderPaint);
        filterPaint.style = PaintingStyle.stroke;
        _paintLine(canvas, polylineOpt.offsets, filterPaint);
      }
      _paintLine(canvas, polylineOpt.offsets, paint);
      canvas.restore();
    }
  }

  void _paintDottedLine(Canvas canvas, List<Offset> offsets, double radius,
      double stepLength, Paint paint) {
    final path = ui.Path();
    var startDistance = 0.0;
    for (var i = 0; i < offsets.length - 1; i++) {
      var o0 = offsets[i];
      var o1 = offsets[i + 1];
      var totalDistance = _dist(o0, o1);
      var distance = startDistance;
      while (distance < totalDistance) {
        var f1 = distance / totalDistance;
        var f0 = 1.0 - f1;
        var offset = Offset(o0.dx * f0 + o1.dx * f1, o0.dy * f0 + o1.dy * f1);
        path.addOval(Rect.fromCircle(center: offset, radius: radius));
        distance += stepLength;
      }
      startDistance = distance < totalDistance
          ? stepLength - (totalDistance - distance)
          : distance - totalDistance;
    }
    path.addOval(
        Rect.fromCircle(center: polylineOpt.offsets.last, radius: radius));
    canvas.drawPath(path, paint);
  }

  void _paintLine(Canvas canvas, List<Offset> offsets, Paint paint) {
    if (offsets.isNotEmpty) {
      final path = ui.Path()..moveTo(offsets[0].dx, offsets[0].dy);
      for (var offset in offsets) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  ui.Gradient _paintGradient() => ui.Gradient.linear(polylineOpt.offsets.first,
      polylineOpt.offsets.last, polylineOpt.gradientColors, _getColorsStop());

  List<double> _getColorsStop() => (polylineOpt.colorsStop != null &&
          polylineOpt.colorsStop.length == polylineOpt.gradientColors.length)
      ? polylineOpt.colorsStop
      : _calculateColorsStop();

  List<double> _calculateColorsStop() {
    final colorsStopInterval = 1.0 / polylineOpt.gradientColors.length;
    return polylineOpt.gradientColors
        .map((gradientColor) =>
            polylineOpt.gradientColors.indexOf(gradientColor) *
            colorsStopInterval)
        .toList();
  }

  @override
  bool shouldRepaint(MW_PolylinePainter other) => false;
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
