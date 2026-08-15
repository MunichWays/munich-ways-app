import 'package:flutter/material.dart';

class InfoSheetLegendRow extends StatelessWidget {
  const InfoSheetLegendRow({
    super.key,
    required this.color,
    required this.label,
    required this.description,
    required this.dashed,
  });

  final Color color;
  final String label;
  final String description;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captionStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      height: 1.3,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 16,
          margin: const EdgeInsets.only(top: 4, right: 12),
          alignment: Alignment.center,
          child: CustomPaint(
            size: const Size(44, 4),
            painter: _LegendLinePainter(color: color, dashed: dashed),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: captionStyle?.copyWith(fontWeight: FontWeight.w600)),
              Text(description, style: captionStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  const _LegendLinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }
    const dashLength = 6.0;
    const gap = 5.0;
    for (var x = 0.0; x < size.width; x += dashLength + gap) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dashLength).clamp(0, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
