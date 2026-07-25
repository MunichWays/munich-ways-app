import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';

class BikenetSelectionSheet extends StatefulWidget {
  const BikenetSelectionSheet({
    super.key,
    required this.model,
  });

  final MapScreenViewModel model;

  @override
  State<BikenetSelectionSheet> createState() => _BikenetSelectionSheetState();
}

class _BikenetSelectionSheetState extends State<BikenetSelectionSheet> {
  static const _lineColors = <Color>[
    AppColors.mapGreen,
    AppColors.mapYellow,
    AppColors.mapRed,
    AppColors.mapBlack,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowTitleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );
    final rowSubtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.black87,
    );

    return BottomSheetFrame(
      title: BottomSheetTitle(
        title: context.l10n.tr('Fahrradnetz auswählen'),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BikenetLayerRow(
            selected: widget.model.isRadlvorrangnetzVisible,
            dashed: false,
            title: context.l10n.tr('Radl-Vorrang-Netz'),
            subtitle: context.l10n.tr('Linie durchgezogen'),
            lineColors: _lineColors,
            onTap: () {
              widget.model.toggleRadvorrangnetzVisible();
              setState(() {});
            },
            titleStyle: rowTitleStyle,
            subtitleStyle: rowSubtitleStyle,
          ),
          _BikenetLayerRow(
            selected: widget.model.isGesamtnetzVisible,
            dashed: true,
            title: context.l10n.tr('Weitere Strecken'),
            subtitle: context.l10n.tr('Linie gestrichelt'),
            lineColors: _lineColors,
            onTap: () {
              widget.model.toggleGesamtnetzVisible();
              setState(() {});
            },
            titleStyle: rowTitleStyle,
            subtitleStyle: rowSubtitleStyle,
          ),
        ],
      ),
    );
  }
}

class _BikenetLayerRow extends StatelessWidget {
  const _BikenetLayerRow({
    required this.selected,
    required this.dashed,
    required this.title,
    required this.subtitle,
    required this.lineColors,
    required this.onTap,
    required this.titleStyle,
    required this.subtitleStyle,
  });

  final bool selected;
  final bool dashed;
  final String title;
  final String subtitle;
  final List<Color> lineColors;
  final VoidCallback onTap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  static const double _previewSize = 56;
  static const double _lineThickness = 3;
  static const double _lineGap = 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title, $subtitle',
      toggled: selected,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: _LinePreviewBadge(
                    size: _previewSize,
                    selected: selected,
                    dashed: dashed,
                    lineColors: lineColors,
                    lineThickness: _lineThickness,
                    lineGap: _lineGap,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: titleStyle),
                        const SizedBox(height: 4),
                        Text(subtitle, style: subtitleStyle),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinePreviewBadge extends StatelessWidget {
  const _LinePreviewBadge({
    required this.size,
    required this.selected,
    required this.dashed,
    required this.lineColors,
    required this.lineThickness,
    required this.lineGap,
  });

  final double size;
  final bool selected;
  final bool dashed;
  final List<Color> lineColors;
  final double lineThickness;
  final double lineGap;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lineColors.length; i++) ...[
            if (i > 0) SizedBox(height: lineGap),
            dashed
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, lineThickness),
                        painter: _DashedBarPainter(color: lineColors[i]),
                      );
                    },
                  )
                : Container(
                    height: lineThickness,
                    decoration: BoxDecoration(
                      color: lineColors[i],
                      borderRadius: BorderRadius.circular(lineThickness / 2),
                    ),
                  ),
          ],
        ],
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? Colors.white : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.mapAccentColor : Colors.black54,
                width: selected ? 4 : 1,
              ),
            ),
            child: inner,
          ),
          if (selected)
            Positioned(
              top: -4,
              right: -4,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.mapAccentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Short horizontal dashes for the “gestrichelt” preview.
class _DashedBarPainter extends CustomPainter {
  _DashedBarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashLen = 4.0;
    const gap = 6.0;
    final y = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height.clamp(1.0, 4.0)
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dashLen).clamp(0.0, size.width);
      if (end > x) {
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      }
      x += dashLen + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBarPainter oldDelegate) =>
      oldDelegate.color != color;
}
