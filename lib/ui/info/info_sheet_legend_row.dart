import 'package:flutter/material.dart';
import 'package:munich_ways/ui/theme.dart';

class InfoSheetLegendRow extends StatelessWidget {
  const InfoSheetLegendRow({
    super.key,
    required this.color,
    required this.label,
    required this.description,
  });

  final Color color;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captionStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.black87,
      height: 1.3,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(top: 4, right: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: color == AppColors.mapBlack
                ? Border.all(color: Colors.black87)
                : null,
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
