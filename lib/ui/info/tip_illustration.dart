import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/info/app_tip.dart';
import 'package:munich_ways/ui/info/tip_screenshot.dart';
import 'package:munich_ways/ui/map/route_point_badge.dart';
import 'package:munich_ways/ui/theme.dart';

/// Local screenshots and illustrations: no map/network/plugin initialization.
/// The adjacent tip text provides the accessible description.
class TipIllustration extends StatelessWidget {
  const TipIllustration({super.key, required this.tip});

  final AppTip tip;

  @override
  Widget build(BuildContext context) {
    if (TipScreenshot.hasScreenshot(tip)) return TipScreenshot(tip: tip);
    final english = context.l10n.isEnglish;
    final colors = Theme.of(context).colorScheme;
    final destination = english ? 'Destination' : 'Ziel';
    Widget row(Widget leading, String text, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ]),
        );
    Widget point(int index, String text) =>
        row(RoutePointBadge(index: index, count: 3), text);

    final content = switch (tip) {
      AppTip.resumeNavigation ||
      AppTip.savedPlaceMenu ||
      AppTip.exploreMap ||
      AppTip.reorderRoute =>
        throw StateError('Screenshot tips are handled above'),
      AppTip.foldPanel => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MapSketch(),
            const SizedBox(height: 12),
            _Highlight(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Icon(Icons.unfold_more),
              ]),
            ),
            const SizedBox(height: 8),
            Text(english ? 'Route information' : 'Routeninformationen'),
          ],
        ),
      AppTip.intermediateStops => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            point(0, 'Start'),
            _Highlight(
              child: row(
                  const Icon(Icons.add_location_alt_outlined),
                  english
                      ? 'Add intermediate stop'
                      : 'Zwischenziel hinzufügen'),
            ),
            point(2, destination),
          ],
        ),
      AppTip.saveRoute => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(const Icon(Icons.route),
                english ? 'Plan route' : 'Route planen',
                trailing: const _Highlight(child: Icon(Icons.save_outlined))),
            const Divider(),
            row(const Icon(Icons.edit_outlined),
                english ? 'Route name: Isar loop' : 'Routenname: Isarrunde'),
          ],
        ),
      AppTip.favorites => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(english ? 'Destination?' : 'Wohin?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _Highlight(
              child: row(const Icon(Icons.star), 'Green City e.V.'),
            ),
            row(const Icon(Icons.star_border), 'Unlock Escape'),
          ],
        ),
      AppTip.compareRoutes => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Highlight(
              child: row(const Icon(Icons.radio_button_checked),
                  english ? 'Recommended' : 'Empfehlung'),
            ),
            row(const Icon(Icons.radio_button_off),
                english ? 'Direct' : 'Direkt'),
            const _MapSketch(),
          ],
        ),
    };

    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border:
            Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _MapSketch extends StatelessWidget {
  const _MapSketch();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _MapSketchPainter(
              streetColor: colors.outlineVariant,
              routeColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.mapRouteColorDark
                  : AppColors.mapRouteColor,
            ),
          ),
        ),
        Icon(Icons.navigation, color: colors.primary, size: 32),
      ]),
    );
  }
}

class _MapSketchPainter extends CustomPainter {
  const _MapSketchPainter(
      {required this.streetColor, required this.routeColor});

  final Color streetColor;
  final Color routeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final street = Paint()
      ..color = streetColor
      ..strokeWidth = 3;
    for (final factor in [0.2, 0.5, 0.8]) {
      canvas.drawLine(Offset(0, size.height * factor),
          Offset(size.width, size.height * factor), street);
      canvas.drawLine(Offset(size.width * factor, 0),
          Offset(size.width * factor, size.height), street);
    }
    final path = Path()
      ..moveTo(size.width * 0.2, size.height)
      ..lineTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.8, size.height * 0.5)
      ..lineTo(size.width * 0.8, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = routeColor
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MapSketchPainter oldDelegate) =>
      oldDelegate.streetColor != streetColor ||
      oldDelegate.routeColor != routeColor;
}
