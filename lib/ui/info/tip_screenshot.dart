import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:munich_ways/ui/info/app_tip.dart';

/// Exact screenshots with scalable instructional overlays. No map or gestures
/// are initialized; the adjacent text describes the action accessibly.
class TipScreenshot extends StatelessWidget {
  const TipScreenshot({super.key, required this.tip});

  final AppTip tip;

  static bool hasScreenshot(AppTip tip) => switch (tip) {
        AppTip.resumeNavigation ||
        AppTip.savedPlaceMenu ||
        AppTip.exploreMap ||
        AppTip.reorderRoute ||
        AppTip.foldPanel ||
        AppTip.compareRoutes =>
          true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final (
      asset,
      width,
      height,
      target,
      highlight,
      arrowStart,
      arrowEnd,
      hold
    ) = switch (tip) {
      AppTip.resumeNavigation => (
          'images/tip-resume-navigation.jpg',
          1080.0,
          974.0,
          const Offset(.806, .894),
          const Size(.226, .194),
          const Offset(.95, .64),
          const Offset(.90, .785),
          false
        ),
      AppTip.savedPlaceMenu => (
          'images/tip-saved-place-menu.jpg',
          1080.0,
          890.0,
          const Offset(.923, .33),
          const Size(.075, .09),
          const Offset(.85, .1),
          const Offset(.917, .267),
          false
        ),
      AppTip.exploreMap => (
          'images/tip-explore-map.jpg',
          1080.0,
          705.0,
          const Offset(.57, .147),
          const Size(.095, .17),
          const Offset(.35, .13),
          const Offset(.51, .147),
          true
        ),
      AppTip.reorderRoute => (
          'images/tip-reorder-route.jpg',
          1080.0,
          993.0,
          const Offset(.125, .48),
          const Size(.12, .13),
          const Offset(.21, .47),
          const Offset(.21, .32),
          true
        ),
      AppTip.foldPanel => (
          'images/tip-fold-panel.jpg',
          1080.0,
          673.0,
          const Offset(.5, .457),
          const Size(.12, .055),
          const Offset(.35, .30),
          const Offset(.46, .425),
          false
        ),
      AppTip.compareRoutes => (
          'images/tip-compare-routes.jpg',
          1080.0,
          695.0,
          const Offset(.128, .655),
          const Size(.078, .12),
          const Offset(.035, .55),
          const Offset(.083, .625),
          false
        ),
      _ => throw ArgumentError.value(tip, 'tip', 'No screenshot available'),
    };
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: width / height,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(asset, fit: BoxFit.contain),
              CustomPaint(
                painter: _TipPointerPainter(
                  target: target,
                  highlight: highlight,
                  arrowStart: arrowStart,
                  arrowEnd: arrowEnd,
                ),
              ),
              if (hold)
                Align(
                  alignment: Alignment(target.dx * 2 - 1, target.dy * 2 - 1),
                  child: FractionallySizedBox(
                    widthFactor: .12,
                    heightFactor: .12 * width / height,
                    child: FittedBox(
                      child: Icon(Icons.touch_app,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4)
                          ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TipPointerPainter extends CustomPainter {
  const _TipPointerPainter(
      {required this.target,
      required this.highlight,
      required this.arrowStart,
      required this.arrowEnd});

  final Offset target;
  final Size highlight;
  final Offset arrowStart;
  final Offset arrowEnd;

  @override
  void paint(Canvas canvas, Size size) {
    Offset position(Offset point) =>
        Offset(point.dx * size.width, point.dy * size.height);
    final ring = Rect.fromCenter(
        center: position(target),
        width: highlight.width * size.width,
        height: highlight.height * size.height);
    final start = position(arrowStart);
    final end = position(arrowEnd);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final head = size.width * .035;
    final arrow = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy)
      ..moveTo(end.dx - head * math.cos(angle - .6),
          end.dy - head * math.sin(angle - .6))
      ..lineTo(end.dx, end.dy)
      ..lineTo(end.dx - head * math.cos(angle + .6),
          end.dy - head * math.sin(angle + .6));
    // Two strokes keep the annotation legible on both the blue panel and map.
    for (final (color, stroke) in [
      (Colors.white, 7.0),
      (const Color(0xFFE65100), 3.0)
    ]) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawRRect(
          RRect.fromRectAndRadius(ring, Radius.circular(size.width * .04)),
          paint);
      canvas.drawPath(arrow, paint);
    }
  }

  @override
  bool shouldRepaint(_TipPointerPainter oldDelegate) =>
      target != oldDelegate.target ||
      highlight != oldDelegate.highlight ||
      arrowStart != oldDelegate.arrowStart ||
      arrowEnd != oldDelegate.arrowEnd;
}
