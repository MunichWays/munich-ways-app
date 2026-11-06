import 'package:munich_ways/ui/map/map_overlay/direct_route_info_dialog.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
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
        _VariantCard(model: model, variant: RouteVariant.standard),
        _VariantCard(model: model, variant: RouteVariant.discovery),
        _VariantCard(model: model, variant: RouteVariant.direct),
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.model, required this.variant});

  final MapScreenViewModel model;
  final RouteVariant variant;
  bool get direct => variant == RouteVariant.direct;
  String get keySuffix => switch (variant) {
        RouteVariant.standard => 'false',
        RouteVariant.discovery => 'discovery',
        RouteVariant.direct => 'true',
      };

  Future<void> _showModeInfo(BuildContext context, String title) {
    if (direct) return showDirectRouteInfoDialog(context);
    final strings = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(strings.routeRecommendationInfo(
          variant == RouteVariant.discovery
              ? RouteRecommendation.discovery
              : RouteRecommendation.standard,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final english = context.l10n.isEnglish;
    final state = model.routeVariantFor(variant);
    final route = state?.route;
    final comfort = route?.comfort;
    final selected = model.selectedRouteVariant == variant;
    final title = direct
        ? (english ? 'Direct route' : 'Direkte Route')
        : variant == RouteVariant.discovery
            ? (english ? 'Discovery tour' : 'Entdeckertour')
            : (english ? 'Standard route' : 'Standard Route');
    final loading = state?.comfortState == RouteComfortState.loading;
    final comfortError = state?.comfortState == RouteComfortState.error;
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
      key: ValueKey('route-variant-card-$keySuffix'),
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
                key: ValueKey('route-variant-$keySuffix'),
                onTap: () => unawaited(
                  model.selectRouteVariant(variant),
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
                            _InlineInfoLine(
                              text: title,
                              style: titleStyle,
                              infoKey: ValueKey('variant-mode-info-$keySuffix'),
                              tooltip: '${context.l10n.tr('Info')}: $title',
                              onInfo: () => _showModeInfo(context, title),
                            ),
                            _InlineInfoLine(
                              text: comfortText,
                              style: secondaryStyle,
                              infoKey:
                                  ValueKey('variant-comfort-info-$keySuffix'),
                              tooltip: english
                                  ? 'About the cycling comfort index'
                                  : 'Erläuterung zum Radl-Komfort-Index',
                              onInfo: comfort == null
                                  ? null
                                  : () => showRouteComfortInfoDialog(
                                        context,
                                        comfort,
                                        direct: direct,
                                      ),
                            ),
                          ],
                        ),
                      ),
                      if (comfortError)
                        IconButton(
                          tooltip: english
                              ? 'Retry comfort analysis'
                              : 'Komfort erneut laden',
                          onPressed: () =>
                              model.retryRouteComfort(variant: variant),
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
                key: ValueKey('variant-comfort-bar-$keySuffix'),
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
                state?.state == MapRouteState.LOADING
                    ? (english ? 'Calculating…' : 'Wird berechnet…')
                    : (english
                        ? 'Tap to calculate / retry'
                        : 'Zum Berechnen antippen'),
                style: detailStyle,
              ),
            if (model.pendingRouteType == variant)
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

/// Inline buttons follow the text size without adding an IconButton's usual
/// minimum height to the two-line variant header.
class _InlineInfoLine extends StatelessWidget {
  const _InlineInfoLine(
      {required this.text,
      required this.style,
      required this.infoKey,
      required this.tooltip,
      required this.onInfo});

  final String text;
  final TextStyle? style;
  final Key infoKey;
  final String tooltip;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final fontSize = effectiveStyle.fontSize ?? 14;
    final lineHeight = MediaQuery.textScalerOf(context).scale(fontSize) *
        (effectiveStyle.height ?? 1.2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(text, style: style)),
        if (onInfo != null) ...[
          const SizedBox(width: 4),
          SizedBox.square(
            dimension: lineHeight,
            child: IconButton(
              key: infoKey,
              tooltip: tooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              iconSize: MediaQuery.textScalerOf(context).scale(fontSize),
              onPressed: onInfo,
              icon: const Icon(Icons.info_outline),
            ),
          ),
        ],
      ],
    );
  }
}
