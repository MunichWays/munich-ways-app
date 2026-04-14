import 'package:flutter/material.dart';
import 'package:munich_ways/ui/info/info_sheet_legend_row.dart';
import 'package:munich_ways/ui/theme.dart';

/// Map usage copy + color legend for [InfoSheet].
class InfoSheetHelpContent extends StatelessWidget {
  const InfoSheetHelpContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.35);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Details zu Streckenabschnitten',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          'Tippe auf eine farbige Linie auf der Karte. Es öffnet sich eine '
          'Übersicht mit Details zu diesem Straßenabschnitt (Bewertung, '
          'Maßnahmen, Links).',
          style: bodyStyle,
        ),
        const SizedBox(height: 24),
        Text(
          'Farben (MunichWays-Bewertung)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InfoSheetLegendRow(
          color: AppColors.mapGreen,
          label: 'Grün',
          description: 'gute Bedingungen fürs Radfahren',
        ),
        const SizedBox(height: 8),
        InfoSheetLegendRow(
          color: AppColors.mapYellow,
          label: 'Gelb',
          description: 'mittlere Bewertung',
        ),
        const SizedBox(height: 8),
        InfoSheetLegendRow(
          color: AppColors.mapRed,
          label: 'Rot',
          description: 'schwächere Bedingungen',
        ),
        const SizedBox(height: 8),
        InfoSheetLegendRow(
          color: AppColors.mapBlack,
          label: 'Schwarz',
          description: 'ohne einfarbige Bewertung im Kataster',
        ),
        const SizedBox(height: 8),
        InfoSheetLegendRow(
          color: AppColors.mapGrey,
          label: 'Grau',
          description: 'Sonderfall / neutral im Datenmodell',
        ),
      ],
    );
  }
}
