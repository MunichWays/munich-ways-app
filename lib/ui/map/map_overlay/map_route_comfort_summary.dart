import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:url_launcher/url_launcher.dart';

const _comfortInfoUrl =
    'https://www.munichways.de/berwertungskriterien-radwege/#radl-komfort-index';
const routeComfortSummaryAdditionalBottomOffset = 88.0;

bool showsRouteComfortSummary(MapScreenViewModel model) =>
    !model.navigationStarted &&
    model.route.state == MapRouteState.SHOWN &&
    model.route.comfortState != RouteComfortState.unavailable;

class MapRouteComfortSummary extends StatelessWidget {
  const MapRouteComfortSummary({super.key, required this.model});

  final MapScreenViewModel model;

  @override
  Widget build(BuildContext context) {
    if (!showsRouteComfortSummary(model)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RouteComfortContent(
        route: model.route,
        onRetry: () => model.retryRouteComfort(),
      ),
    );
  }
}

/// Shared metadata display for the map and the currently open route planner.
class RouteComfortContent extends StatelessWidget {
  const RouteComfortContent({
    super.key,
    required this.route,
    required this.onRetry,
    this.compact = false,
  });

  final MapRoute route;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final comfort = route.route?.comfort;
    if (comfort != null) {
      return MapRouteComfortCard(comfort: comfort, compact: compact);
    }
    final loading = route.comfortState == RouteComfortState.loading;
    if (!loading && route.comfortState != RouteComfortState.error) {
      return const SizedBox.shrink();
    }
    final english = context.l10n.isEnglish;
    return Material(
      key: ValueKey(loading ? 'route-comfort-loading' : 'route-comfort-error'),
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(loading
                    ? (english
                        ? 'Cycling comfort: calculating …'
                        : 'Radl-Komfort: Wird berechnet …')
                    : (english
                        ? 'Cycling comfort currently unavailable'
                        : 'Radl-Komfort derzeit nicht verfügbar')),
              ),
            ),
            if (!loading)
              IconButton(
                tooltip:
                    english ? 'Retry comfort analysis' : 'Komfort erneut laden',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      ),
    );
  }
}

class MapRouteComfortCard extends StatelessWidget {
  const MapRouteComfortCard({
    super.key,
    required this.comfort,
    this.compact = false,
  });

  final RouteComfort comfort;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indexText = comfort.sufficientCoverage && comfort.index != null
        ? '${comfort.index}/100'
        : '${comfort.coverage} % ${context.l10n.isEnglish ? 'rated' : 'bewertet'}';

    return Material(
      key: const ValueKey('route-comfort-summary'),
      color: theme.colorScheme.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: compact
            ? const EdgeInsets.fromLTRB(12, 2, 4, 6)
            : const EdgeInsets.fromLTRB(12, 4, 4, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Radl-Komfort',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    indexText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.isEnglish
                      ? 'About the cycling comfort index'
                      : 'Erläuterung zum Radl-Komfort-Index',
                  onPressed: () => showRouteComfortInfoDialog(
                    context,
                    comfort,
                  ),
                  icon: const Icon(Icons.info_outline, size: 21),
                ),
              ],
            ),
            _ComfortDistributionBar(comfort: comfort),
          ],
        ),
      ),
    );
  }
}

class _ComfortDistributionBar extends StatelessWidget {
  const _ComfortDistributionBar({required this.comfort});

  final RouteComfort comfort;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final segments = <({String name, int percentage, Color color})>[
      (
        name: 'black',
        percentage: comfort.distribution.black,
        color: AppColors.getPolylineColor('schwarz', dark: dark),
      ),
      (
        name: 'red',
        percentage: comfort.distribution.red,
        color: AppColors.mapRed,
      ),
      (
        name: 'yellow',
        percentage: comfort.distribution.yellow,
        color: AppColors.mapYellow,
      ),
      (
        name: 'green',
        percentage: comfort.distribution.green,
        color: AppColors.getPolylineColor('grün', dark: dark),
      ),
      (
        name: 'unrated',
        percentage: comfort.distribution.unrated,
        color: AppColors.mapBrown,
      ),
    ];
    final semanticsLabel = context.l10n.isEnglish
        ? 'Route ratings: ${comfort.distribution.black} percent very stressful, '
            '${comfort.distribution.red} percent stressful, '
            '${comfort.distribution.yellow} percent average, '
            '${comfort.distribution.green} percent comfortable, '
            '${comfort.distribution.unrated} percent unrated'
        : 'Routenbewertung: ${comfort.distribution.black} Prozent sehr stressig, '
            '${comfort.distribution.red} Prozent stressig, '
            '${comfort.distribution.yellow} Prozent durchschnittlich, '
            '${comfort.distribution.green} Prozent komfortabel, '
            '${comfort.distribution.unrated} Prozent nicht bewertet';

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Container(
        height: 14,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: themeBorderColor(context), width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final segment in segments)
              if (segment.percentage > 0)
                Expanded(
                  key: ValueKey('comfort-segment-${segment.name}'),
                  flex: segment.percentage,
                  child: ColoredBox(color: segment.color),
                ),
          ],
        ),
      ),
    );
  }

  Color themeBorderColor(BuildContext context) =>
      Theme.of(context).colorScheme.outline;
}

class _ComfortLegendRow extends StatelessWidget {
  const _ComfortLegendRow({
    required this.color,
    required this.label,
    required this.percentage,
  });

  final Color color;
  final String label;
  final int percentage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text('$percentage %'),
        ],
      ),
    );
  }
}

Future<void> showRouteComfortInfoDialog(
  BuildContext context,
  RouteComfort comfort,
) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final english = context.l10n.isEnglish;
        return AlertDialog(
          title: const Text('Radl-Komfort-Index'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  english ? 'Colors of this route' : 'Farben dieser Route',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                _ComfortLegendRow(
                  color: AppColors.getPolylineColor(
                    'schwarz',
                    dark: theme.brightness == Brightness.dark,
                  ),
                  label: english ? 'Very stressful' : 'Sehr stressig',
                  percentage: comfort.distribution.black,
                ),
                _ComfortLegendRow(
                  color: AppColors.mapRed,
                  label: english ? 'Stressful' : 'Stressig',
                  percentage: comfort.distribution.red,
                ),
                _ComfortLegendRow(
                  color: AppColors.mapYellow,
                  label: english ? 'Average' : 'Durchschnittlich',
                  percentage: comfort.distribution.yellow,
                ),
                _ComfortLegendRow(
                  color: AppColors.getPolylineColor(
                    'grün',
                    dark: theme.brightness == Brightness.dark,
                  ),
                  label: english ? 'Comfortable' : 'Komfortabel',
                  percentage: comfort.distribution.green,
                ),
                _ComfortLegendRow(
                  color: AppColors.mapBrown,
                  label: english ? 'Unrated' : 'Nicht bewertet',
                  percentage: comfort.distribution.unrated,
                ),
                const SizedBox(height: 12),
                Text(
                  english
                      ? '${comfort.coverage} % of the route rated'
                      : '${comfort.coverage} % der Route bewertet',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  english
                      ? 'The index ranges from 0 to 100; higher means more comfortable. Brown, unrated sections do not affect it. The index is shown from 70 % rating coverage.'
                      : 'Der Index reicht von 0 bis 100; höher bedeutet komfortabler. Braune, nicht bewertete Abschnitte fließen nicht ein. Ab 70 % Bewertungsabdeckung wird der Index angezeigt.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(_comfortInfoUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                english ? 'More details' : 'Weitere Erläuterungen',
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.close),
            ),
          ],
        );
      },
    );
