import 'package:flutter/material.dart';
import 'package:munich_ways/ui/info/info_sheet_legend_row.dart';
import 'package:munich_ways/ui/theme.dart';

/// Map usage copy + color legend for [InfoSheet].
class InfoSheetHelpContent extends StatelessWidget {
  const InfoSheetHelpContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ziel auswählen',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
            'Nutze den Button unten in der Mitte, um nach einem Ziel zu suchen. Du kannst aber auch auf einen Ort auf der Karte tippen und ca. eine Sekunde gedrückt halten, um die Navigation dorthin zu starten.'),
        const SizedBox(height: 24),
        Text('Details zu Streckenabschnitten',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          'Tippe auf eine farbige Linie auf der Karte. Es öffnet sich eine '
          'Übersicht mit Details zu diesem Straßenabschnitt (Bewertung, '
          'Maßnahmen, Links).',
        ),
        const SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              'Farben (MunichWays-Bewertung)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            InfoSheetLegendRow(
              color: AppColors.mapGreen,
              label: 'Gemütlich',
              description: 'Radweg ist breit, sicher, eben',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapYellow,
              label: 'Durchschnittlich',
              description: 'Radweg ist verbesserungswürdig',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapRed,
              label: 'Stressig',
              description: 'Radweg ist eng, uneben, nicht komfortabel',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapBlack,
              label: 'Kein Radweg',
              description: 'Lücke im Radnetz',
            ),
          ],
        ),
      ],
    );
  }
}
