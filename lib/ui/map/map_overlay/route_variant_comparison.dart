import 'dart:async';

import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/map/map_overlay/map_route_comfort_summary.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';

class RouteVariantComparison extends StatelessWidget {
  const RouteVariantComparison({super.key, required this.model});

  final MapScreenViewModel model;

  @override
  Widget build(BuildContext context) {
    if (!model.hasRouteComparison) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VariantCard(model: model, direct: false),
        _VariantCard(model: model, direct: true),
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.model, required this.direct});

  final MapScreenViewModel model;
  final bool direct;

  @override
  Widget build(BuildContext context) {
    final english = context.l10n.isEnglish;
    final variant = model.routeVariant(direct);
    final route = variant?.route;
    final comfort = route?.comfort;
    final selected = model.temporaryShortestRouteEnabled == direct;
    final title = direct
        ? (english ? 'Direct route' : 'Direkte Route')
        : (english ? 'Standard route' : 'Standard Route');
    final loading = variant?.comfortState == RouteComfortState.loading;
    final comfortError = variant?.comfortState == RouteComfortState.error;
    final hasIndex =
        comfort?.sufficientCoverage == true && comfort?.index != null;
    final comfortText = comfort != null
        ? 'Radl-Komfort ${hasIndex ? '${comfort.index}/100' : '-'}'
        : loading
            ? (english ? 'Loading comfort…' : 'Komfort wird geladen…')
            : (english ? 'Comfort unavailable' : 'Komfort nicht verfügbar');
    final coverageText = comfort != null && !hasIndex
        ? '${comfort.coverage} % ${english ? 'rated' : 'bewertet'}'
        : null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleStyle = direct
        ? theme.textTheme.bodyMedium
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final secondaryStyle = direct
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final detailStyle = direct ? theme.textTheme.bodySmall : null;

    return Card(
      key: ValueKey('route-variant-card-$direct'),
      margin: EdgeInsets.symmetric(vertical: direct ? 2 : 3),
      elevation: direct ? 0 : 1,
      color: selected
          ? Color.alphaBlend(
              AppColors.mapRouteColor.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.22 : 0.10,
              ),
              colors.surface,
            )
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.mapRouteColor : colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 8, direct ? 6 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              checked: selected,
              inMutuallyExclusiveGroup: true,
              child: InkWell(
                key: ValueKey('route-variant-$direct'),
                onTap: () => unawaited(
                  model.setTemporaryShortestRouteEnabled(direct),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: direct ? 21 : 24,
                      ),
                      SizedBox(width: direct ? 8 : 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: titleStyle),
                            Text(comfortText, style: secondaryStyle),
                          ],
                        ),
                      ),
                      if (comfort != null)
                        IconButton(
                          key: ValueKey('variant-comfort-info-$direct'),
                          tooltip: english
                              ? 'About the cycling comfort index'
                              : 'Erläuterung zum Radl-Komfort-Index',
                          onPressed: () => showRouteComfortInfoDialog(
                            context,
                            comfort,
                            direct: direct,
                          ),
                          icon: Icon(
                            Icons.info_outline,
                            size: direct ? 19 : 21,
                          ),
                        )
                      else if (comfortError)
                        IconButton(
                          tooltip: english
                              ? 'Retry comfort analysis'
                              : 'Komfort erneut laden',
                          onPressed: () =>
                              model.retryRouteComfort(direct: direct),
                          icon: const Icon(Icons.refresh),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (coverageText != null)
              Text(coverageText, style: theme.textTheme.bodySmall),
            if (comfort != null)
              Padding(
                key: ValueKey('variant-comfort-bar-$direct'),
                padding: EdgeInsets.only(
                  top: coverageText == null ? 1 : 3,
                  bottom: direct ? 4 : 6,
                ),
                child: RouteComfortDistributionBar(
                  comfort: comfort,
                  height: direct ? 10 : 12,
                ),
              ),
            if (route != null) ...[
              Text(
                '${(route.distance / 1000).toStringAsFixed(1).replaceAll('.', english ? '.' : ',')} km · ${(route.duration / 60).round()} min',
                style: detailStyle,
              ),
              if (!route.supportsVoiceGuidance)
                Text(
                  english
                      ? 'BRouter · no voice instructions'
                      : 'BRouter · ohne Abbiegeansagen',
                  style: detailStyle,
                ),
            ] else
              Text(
                variant?.state == MapRouteState.LOADING
                    ? (english ? 'Calculating…' : 'Wird berechnet…')
                    : (english
                        ? 'Tap to calculate / retry'
                        : 'Zum Berechnen / Wiederholen antippen'),
                style: detailStyle,
              ),
            if (model.pendingRouteVariant == direct)
              Text(
                english ? 'Switching when ready…' : 'Wechsel, sobald bereit…',
                style: detailStyle,
              ),
          ],
        ),
      ),
    );
  }
}
