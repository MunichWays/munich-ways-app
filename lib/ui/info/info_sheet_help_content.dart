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
              label: context.l10n.isEnglish ? 'Comfortable' : 'Gemütlich',
              description: context.l10n.isEnglish
                  ? 'Cycle path is wide, safe and smooth'
                  : 'Radweg ist breit, sicher, eben',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapYellow,
              label: context.l10n.isEnglish ? 'Average' : 'Durchschnittlich',
              description: context.l10n.isEnglish
                  ? 'Cycle path could be improved'
                  : 'Radweg ist verbesserungswürdig',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapRed,
              label: context.l10n.isEnglish ? 'Stressful' : 'Stressig',
              description: context.l10n.isEnglish
                  ? 'Cycle path is narrow, uneven or uncomfortable'
                  : 'Radweg ist eng, uneben, nicht komfortabel',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapBlack,
              label: context.l10n.isEnglish ? 'No cycle path' : 'Kein Radweg',
              description: context.l10n.isEnglish
                  ? 'Gap in the network'
                  : 'Lücke im Radnetz',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(context.l10n.tr('Ziel auswählen'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(context.l10n.isEnglish
            ? 'You can also touch and hold a place on the map for about one second to start navigation there.'
            : 'Du kannst auch auf einen Ort auf der Karte tippen und ca. eine Sekunde gedrückt halten, um die Navigation dorthin zu starten.'),
        const SizedBox(height: 24),
        Text(context.l10n.tr('Details zu Streckenabschnitten'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(context.l10n.isEnglish
            ? 'Tap a colored line on the map to see its rating, measures and links.'
            : 'Tippe auf eine farbige Linie auf der Karte. Es öffnet sich eine Übersicht mit Details zu diesem Straßenabschnitt (Bewertung, Maßnahmen, Links).'),
      ],
    );
  }
}
