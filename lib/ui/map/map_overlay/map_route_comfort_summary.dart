import 'package:munich_ways/ui/map/map_overlay/direct_route_info_dialog.dart';
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
  const MapRouteComfortSummary(
      {super.key, required this.model, this.compact = false});

  final MapScreenViewModel model;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!showsRouteComfortSummary(model)) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 8),
      child: RouteComfortContent(
        route: model.route,
        compact: compact,
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
    final hasIndex = comfort.sufficientCoverage && comfort.index != null;
    final indexText = hasIndex ? '${comfort.index}/100' : '-';

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
                    hasIndex ? 'Radl-Komfort' : 'Radl-Komfort -',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasIndex)
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
            if (!hasIndex)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${comfort.coverage} % '
                  '${context.l10n.isEnglish ? 'rated' : 'bewertet'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (!hasIndex) const SizedBox(height: 3),
            RouteComfortDistributionBar(comfort: comfort),
          ],
        ),
      ),
    );
  }
}

class RouteComfortDistributionBar extends StatelessWidget {
  const RouteComfortDistributionBar({
    super.key,
    required this.comfort,
    this.height = 14,
  });

  final RouteComfort comfort;
  final double height;

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
        height: height,
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
  RouteComfort comfort, {
  bool direct = false,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final english = context.l10n.isEnglish;
        final linkStyle = TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            minimumSize: const Size(48, 48));
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text('Radl-Komfort-Index',
                                style: theme.textTheme.titleLarge)),
                        IconButton(
                            key: const ValueKey('comfort-info-close'),
                            tooltip: context.l10n.close,
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close)),
                      ]),
                      const SizedBox(height: 8),
                      Expanded(
                          child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                english
                                    ? 'Colors of this route'
                                    : 'Farben dieser Route',
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
                                label: english
                                    ? 'Very stressful'
                                    : 'Sehr stressig',
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
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Radl-Komfort '
                                '${comfort.sufficientCoverage && comfort.index != null ? '${comfort.index}/100' : '-'}',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                english
                                    ? 'Index 0 to 100: higher means more comfortable. Unrated sections (brown) are excluded. Shown from 70 % rating coverage.'
                                    : 'Index 0 bis 100: höher bedeutet komfortabler. Unbewertete Abschnitte (braun) zählen nicht mit. Anzeige ab 70 % Bewertungsabdeckung.',
                              ),
                              if (direct)
                                TextButton(
                                    style: linkStyle,
                                    onPressed: () =>
                                        showDirectRouteInfoDialog(sheetContext),
                                    child: Text(english
                                        ? 'About the direct route'
                                        : 'Info zur direkten Route')),
                              TextButton(
                                  style: linkStyle,
                                  onPressed: () => launchUrl(
                                      Uri.parse(_comfortInfoUrl),
                                      mode: LaunchMode.externalApplication),
                                  child: Text(english
                                      ? 'More about the comfort index'
                                      : 'Weitere Infos zum Komfort-Index')),
                            ]),
                      )),
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: FilledButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: Text(context.l10n.close))),
                    ]),
              )),
        );
      },
    );
