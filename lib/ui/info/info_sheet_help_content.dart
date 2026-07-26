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
              label: context.l10n.isEnglish
                  ? 'Comfortable and convenient'
                  : 'Gemütlich und komfortabel',
              description: context.l10n.isEnglish
                  ? 'Cycle path is wide, safe and smooth'
                  : 'Radweg ist breit, sicher, eben',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapYellow,
              label: context.l10n.isEnglish ? 'Average' : 'Durchschnittlich',
              description: context.l10n.isEnglish
                  ? 'Cycle path is acceptable but could be improved'
                  : 'Radweg ist akzeptabel, verbesserungswürdig',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapRed,
              label: context.l10n.isEnglish ? 'Stressful' : 'Stressig',
              description: context.l10n.isEnglish
                  ? 'Cycle path is very narrow and uncomfortable'
                  : 'Radweg ist sehr schmal, nicht komfortabel',
            ),
            InfoSheetLegendRow(
              color: AppColors.mapBlack,
              label:
                  context.l10n.isEnglish ? 'Very stressful' : 'Sehr stressig',
              description: context.l10n.isEnglish
                  ? 'No cycle path on busy roads'
                  : 'Kein Radweg auf vielbefahrenen Straßen',
            ),
            InfoSheetLegendRow(
              color: Colors.grey,
              label: context.l10n.isEnglish
                  ? 'Plan / network gap'
                  : 'Plan / Lücke im Netz',
              description: context.l10n.isEnglish
                  ? 'Missing bridge or underpass'
                  : 'Fehlende Brücke oder Unterführung',
            ),
            const SizedBox(height: 4),
            const _NetworkLineLegend(),
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

class _NetworkLineLegend extends StatelessWidget {
  const _NetworkLineLegend();

  @override
  Widget build(BuildContext context) {
    final english = context.l10n.isEnglish;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NetworkLineLegendRow(
          dashed: false,
          label: english ? 'Priority cycling network' : 'RadlVorrang-Netz',
        ),
        const SizedBox(height: 8),
        _NetworkLineLegendRow(
          dashed: true,
          label: english ? 'Other routes' : 'Weitere Strecken',
        ),
      ],
    );
  }
}

class _NetworkLineLegendRow extends StatelessWidget {
  const _NetworkLineLegendRow({
    required this.dashed,
    required this.label,
  });

  final bool dashed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 8,
          child: dashed
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    5,
                    (_) => Container(
                      width: 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.mapBlack,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.mapBlack,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}
