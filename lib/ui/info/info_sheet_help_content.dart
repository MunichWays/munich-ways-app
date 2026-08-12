import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              context.l10n.isEnglish
                  ? 'Colors (MunichWays rating)'
                  : 'Farben (MunichWays-Bewertung)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            InfoSheetLegendRow(
              color: AppColors.mapGreen,
              dashed: false,
              label: context.l10n.isEnglish
                  ? 'Comfortable and convenient – solid line'
                  : 'Gemütlich und komfortabel – durchgezogene Linie',
              description: context.l10n.isEnglish
                  ? 'Cycle path is wide, safe and smooth'
                  : 'Radweg ist breit, sicher, eben',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapYellow,
              dashed: false,
              label: context.l10n.isEnglish
                  ? 'Average – solid line'
                  : 'Durchschnittlich – durchgezogene Linie',
              description: context.l10n.isEnglish
                  ? 'Cycle path is acceptable but could be improved'
                  : 'Radweg ist akzeptabel, verbesserungswürdig',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapRed,
              dashed: true,
              label: context.l10n.isEnglish
                  ? 'Stressful – dashed line'
                  : 'Stressig – gestrichelte Linie',
              description: context.l10n.isEnglish
                  ? 'Cycle path is very narrow and uncomfortable'
                  : 'Radweg ist sehr schmal, nicht komfortabel',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapBlack,
              dashed: true,
              label: context.l10n.isEnglish
                  ? 'Very stressful – dashed line'
                  : 'Sehr stressig – gestrichelte Linie',
              description: context.l10n.isEnglish
                  ? 'No cycle path on busy roads'
                  : 'Kein Radweg auf vielbefahrenen Straßen',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(context.l10n.tr('Ziel auswählen'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(context.l10n.isEnglish
            ? 'Touch and hold a place on the map and select “Start route here”. The route is calculated and navigation starts immediately.'
            : 'Halte einen Ort auf der Karte gedrückt und wähle „Route hierhin“. Die Route wird berechnet und die Navigation startet direkt.'),
        const SizedBox(height: 24),
        Text(context.l10n.tr('Details zu Streckenabschnitten'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(context.l10n.isEnglish
            ? 'Touch and hold a colored line and select “Show details” to see its rating, measures and links.'
            : 'Halte eine farbige Linie gedrückt und wähle „Details anzeigen“, um Bewertung, Maßnahmen und Links zu sehen.'),
      ],
    );
  }
}
