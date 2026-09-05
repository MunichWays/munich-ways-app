import 'dart:async';

import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';
import 'package:munich_ways/ui/theme.dart';

/// Blue navigation summary shown while a destination is set (same color as the route line).
class MapNavigationHeaderBar extends StatelessWidget {
  const MapNavigationHeaderBar({
    super.key,
    required this.model,
    required this.onRefreshRoute,
    required this.onEditRoute,
    required this.onStartNavigation,
    required this.onToggleVoiceGuidance,
    required this.onEndRoute,
    this.onToggleTemporaryShortestRoute,
    this.onShowInfo,
    this.onShowSettings,
    this.nextManeuver,
  });

  final MapScreenViewModel model;
  final Future<void> Function() onRefreshRoute;
  final VoidCallback onEditRoute;
  final Future<void> Function() onStartNavigation;
  final VoidCallback onToggleVoiceGuidance;
  final VoidCallback onEndRoute;
  final Future<void> Function()? onToggleTemporaryShortestRoute;
  final VoidCallback? onShowInfo;
  final VoidCallback? onShowSettings;
  final VoiceGuidanceDisplay? nextManeuver;

  static String _formatKm(double meters) {
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  static String _formatMin(double seconds) {
    final min = (seconds / 60.0).round();
    return '$min Min';
  }

  static IconData _maneuverIcon(VoiceGuidanceDisplay maneuver) {
    if (maneuver.type == 'notification') return Icons.sync;
    if (maneuver.type == 'map') return Icons.map_outlined;
    if (maneuver.type == 'arrive') return Icons.location_on;
    if (maneuver.type == 'roundabout' ||
        maneuver.type == 'rotary' ||
        maneuver.type == 'roundabout turn') {
      return Icons.roundabout_right;
    }
    return switch (maneuver.modifier) {
      'left' || 'sharp left' => Icons.turn_left,
      'slight left' => Icons.turn_slight_left,
      'right' || 'sharp right' => Icons.turn_right,
      'slight right' => Icons.turn_slight_right,
      'uturn' => Icons.u_turn_left,
      _ => Icons.straight,
    };
  }

  Widget _heroAction(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final compactLandscape = mediaSize.width >= mediaSize.height * 1.5;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: double.infinity,
          height:
              compactLandscape ? (largeText ? 56 : 48) : (largeText ? 64 : 56),
          child: Center(
            child: IgnorePointer(
              child: FilledButton.icon(
                style: AppButtonStyles.hero(context).merge(
                  FilledButton.styleFrom(
                    minimumSize: Size(
                      compactLandscape ? 160 : 180,
                      compactLandscape ? 44 : 48,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: compactLandscape ? 18 : 24,
                      vertical: compactLandscape ? 9 : 12,
                    ),
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                onPressed: onPressed,
                icon: Icon(icon, size: compactLandscape ? 21 : 24),
                label: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDirectRouteDialog(
    BuildContext context, {
    required bool directRouteActive,
    required Future<void> Function() toggleRouteChoice,
  }) async {
    final english = context.l10n.isEnglish;
    final useDirectRoute = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(english ? 'Direct route' : 'Direkte Route'),
        content: Text(
          english
              ? 'The direct route is shorter, but may be more stressful. It has no turn-by-turn voice instructions, so please watch the map. This choice applies only to this trip.'
              : 'Die direkte Route ist kürzer, kann aber stressiger sein. Sie hat keine Abbiegeansagen, deshalb bitte auf die Karte achten. Die Auswahl gilt nur für diese Fahrt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              directRouteActive,
            ),
            child: Text(
              directRouteActive
                  ? (english
                      ? 'Keep direct route'
                      : 'Direkte Route beibehalten')
                  : (english ? 'Keep standard' : 'Bei Standard bleiben'),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              !directRouteActive,
            ),
            child: Text(
              directRouteActive
                  ? (english ? 'Calculate standard' : 'Standard berechnen')
                  : (english
                      ? 'Calculate direct route'
                      : 'Direkte Route berechnen'),
            ),
          ),
        ],
      ),
    );
    if (useDirectRoute == null || useDirectRoute == directRouteActive) return;
    await toggleRouteChoice();
  }

  @override
  Widget build(BuildContext context) {
    final dest = model.destination;
    if (dest == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final compactLandscape = mediaSize.width >= mediaSize.height * 1.5;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final actionSize = compactLandscape ? 48.0 : 52.0;
    final refreshWidth = compactLandscape ? 60.0 : 68.0;
    final refreshIconSize = compactLandscape ? 24.0 : 28.0;
    final baseStyle = theme.textTheme.bodyLarge?.copyWith(
          color: Colors.white,
        ) ??
        const TextStyle(color: Colors.white);
    final emphasisStyle = baseStyle.copyWith(fontWeight: FontWeight.w500);

    final route = model.route;
    final navigationTrackingInterrupted = model.navigationStarted &&
        model.locationState != LocationState.FOLLOW_AND_ROTATE_MAP;
    final guidanceDisplay = model.navigationStarted
        ? navigationTrackingInterrupted
            ? VoiceGuidanceDisplay(
                text: context.l10n.isEnglish ? 'Resume' : 'Fortsetzen',
                type: 'map',
                mapReason: VoiceGuidanceMapReason.trackingInterrupted,
              )
            : nextManeuver ??
                VoiceGuidanceDisplay(
                  text: context.l10n.followRouteOnMap,
                  type: 'map',
                  mapReason: VoiceGuidanceMapReason.noInstruction,
                )
        : null;
    final destinationReached = guidanceDisplay?.isFinalDestination ?? false;
    Widget routeStat(IconData icon, String value) => Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 19),
            const SizedBox(width: 7),
            Text(value, softWrap: false, style: emphasisStyle),
          ],
        );
    final Widget stats;
    switch (route.state) {
      case MapRouteState.LOADING:
        stats = Text(
          context.l10n.isEnglish
              ? 'Calculating route...'
              : 'Route wird berechnet...',
          softWrap: true,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        );
        break;
      case MapRouteState.SHOWN:
        final r = route.route;
        if (r == null) {
          stats = Text('…', style: baseStyle);
          break;
        }
        stats = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: largeText
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    routeStat(Icons.route, _formatKm(r.distance)),
                    const SizedBox(height: 4),
                    routeStat(Icons.schedule, _formatMin(r.duration)),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: routeStat(Icons.route, _formatKm(r.distance)),
                    ),
                    Expanded(
                      child: routeStat(Icons.schedule, _formatMin(r.duration)),
                    ),
                  ],
                ),
        );
        break;
      case MapRouteState.ERROR:
      case MapRouteState.NO_ROUTE:
        stats = Text(
          route.state == MapRouteState.ERROR ? '—' : '…',
          style: baseStyle,
        );
        break;
    }

    final refreshEnabled = route.state != MapRouteState.LOADING;
    final routeReadyToStart = route.state == MapRouteState.SHOWN &&
        route.route != null &&
        !model.navigationStarted &&
        model.routeStart == null;
    final showTemporaryRouteChoice = onToggleTemporaryShortestRoute != null &&
        model.canSelectTemporaryShortestRoute &&
        !model.navigationStarted &&
        model.routeStart == null &&
        route.state != MapRouteState.LOADING;
    final useConfiguredRoute = model.temporaryShortestRouteEnabled;
    final routeChoiceLabel = useConfiguredRoute
        ? (context.l10n.isEnglish
            ? 'Choose standard route'
            : 'Standardroute auswählen')
        : (context.l10n.isEnglish
            ? 'Choose direct route'
            : 'Direkte Route auswählen');
    final refreshLabel = refreshEnabled
        ? (navigationTrackingInterrupted
            ? (context.l10n.isEnglish ? 'Resume' : 'Fortsetzen')
            : (context.l10n.isEnglish
                ? 'Recalculate route'
                : 'Route neu berechnen'))
        : (context.l10n.isEnglish
            ? 'Calculating route'
            : 'Route wird berechnet');
    final refreshAction = Semantics(
      container: true,
      button: true,
      enabled: refreshEnabled,
      label: refreshLabel,
      onTap: refreshEnabled ? onRefreshRoute : null,
      excludeSemantics: true,
      child: navigationTrackingInterrupted
          ? SizedBox(
              width: refreshWidth,
              height: actionSize,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.munichWaysOrange,
                  foregroundColor: AppColors.heroForeground,
                  disabledBackgroundColor:
                      AppColors.munichWaysOrange.withValues(alpha: 0.55),
                  disabledForegroundColor: AppColors.heroForeground,
                ),
                padding: const EdgeInsets.all(10),
                tooltip: refreshLabel,
                onPressed: refreshEnabled ? onRefreshRoute : null,
                icon: refreshEnabled
                    ? Icon(Icons.refresh, size: refreshIconSize)
                    : const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.heroForeground,
                          strokeWidth: 2.5,
                        ),
                      ),
              ),
            )
          : SizedBox(
              width: refreshWidth,
              height: actionSize,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.mapRouteColor,
                  disabledBackgroundColor: Colors.white54,
                  disabledForegroundColor: AppColors.mapRouteColor,
                ),
                padding: const EdgeInsets.all(10),
                tooltip: refreshLabel,
                onPressed: refreshEnabled ? onRefreshRoute : null,
                icon: refreshEnabled
                    ? Icon(Icons.refresh, size: refreshIconSize)
                    : const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.mapRouteColor,
                          strokeWidth: 2.5,
                        ),
                      ),
              ),
            ),
    );
    final editLabel =
        context.l10n.isEnglish ? 'Edit route' : 'Route bearbeiten';
    final editAction = Semantics(
      container: true,
      button: true,
      label: editLabel,
      onTap: onEditRoute,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: actionSize,
        child: IconButton.outlined(
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70, width: 1.5),
          ),
          tooltip: editLabel,
          onPressed: onEditRoute,
          icon: Icon(
            Icons.edit_location_alt,
            size: compactLandscape ? 24 : 27,
          ),
        ),
      ),
    );
    final routeChoiceAction = Semantics(
      container: true,
      button: true,
      label: routeChoiceLabel,
      onTap: showTemporaryRouteChoice
          ? () => unawaited(_showDirectRouteDialog(
                context,
                directRouteActive: useConfiguredRoute,
                toggleRouteChoice: onToggleTemporaryShortestRoute!,
              ))
          : null,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: actionSize,
        child: IconButton(
          color: Colors.white70,
          tooltip: routeChoiceLabel,
          onPressed: showTemporaryRouteChoice
              ? () => unawaited(_showDirectRouteDialog(
                    context,
                    directRouteActive: useConfiguredRoute,
                    toggleRouteChoice: onToggleTemporaryShortestRoute!,
                  ))
              : null,
          icon: Icon(
            useConfiguredRoute ? Icons.route : Icons.straighten,
            size: compactLandscape ? 23 : 25,
          ),
        ),
      ),
    );
    final showVoiceAction = route.state == MapRouteState.SHOWN &&
        route.route != null &&
        model.navigationStarted &&
        model.voiceGuidanceAvailable;
    final voiceLabel = model.voiceGuidanceEnabled
        ? (context.l10n.isEnglish
            ? 'Turn off voice guidance'
            : 'Sprachansagen ausschalten')
        : (context.l10n.isEnglish
            ? 'Turn on voice guidance'
            : 'Sprachansagen einschalten');
    final voiceAction = Semantics(
      container: true,
      button: true,
      label: voiceLabel,
      onTap: onToggleVoiceGuidance,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: actionSize,
        child: IconButton.outlined(
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70, width: 1.5),
          ),
          tooltip: voiceLabel,
          onPressed: onToggleVoiceGuidance,
          icon: Icon(
            model.voiceGuidanceEnabled ? Icons.volume_up : Icons.volume_off,
            size: compactLandscape ? 24 : 27,
          ),
        ),
      ),
    );
    final closeLabel = context.l10n.tr('Route beenden');
    final closeAction = Semantics(
      container: true,
      button: true,
      label: closeLabel,
      onTap: onEndRoute,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: compactLandscape ? 48 : 56,
        child: IconButton(
          color: Colors.white70,
          tooltip: closeLabel,
          onPressed: onEndRoute,
          icon: Icon(Icons.close, size: compactLandscape ? 22 : 24),
        ),
      ),
    );
    Widget pausedAction({
      required String label,
      required IconData icon,
      required VoidCallback onPressed,
    }) =>
        SizedBox.square(
          dimension: 48,
          child: IconButton(
            style: IconButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.all(8),
            ),
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(icon, size: 23),
          ),
        );
    return Material(
      color: AppColors.mapRouteColor,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compactLandscape ? 4 : 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (guidanceDisplay != null)
              ExcludeSemantics(
                excluding: navigationTrackingInterrupted,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                  child: Row(
                    children: [
                      if (guidanceDisplay.type != 'map') ...[
                        Icon(
                          _maneuverIcon(guidanceDisplay),
                          size: 32,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          guidanceDisplay.text,
                          textAlign: TextAlign.center,
                          maxLines: guidanceDisplay.type == 'map' ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: (guidanceDisplay.type == 'map'
                                      ? theme.textTheme.titleMedium
                                      : theme.textTheme.titleLarge)
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ) ??
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (navigationTrackingInterrupted &&
                          onShowInfo != null) ...[
                        const SizedBox(width: 8),
                        pausedAction(
                          label: context.l10n.tr('Info'),
                          icon: Icons.info_outline,
                          onPressed: onShowInfo!,
                        ),
                      ],
                      if (navigationTrackingInterrupted &&
                          onShowSettings != null) ...[
                        const SizedBox(width: 8),
                        pausedAction(
                          label: context.l10n.settings,
                          icon: Icons.settings_outlined,
                          onPressed: onShowSettings!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            SizedBox(width: double.infinity, child: Center(child: stats)),
            if (destinationReached) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kMapHorizontalHolderClearance,
                ),
                child: _heroAction(
                  context,
                  label: context.l10n.isEnglish ? 'Finish' : 'Beenden',
                  icon: Icons.sports_score,
                  onPressed: onEndRoute,
                ),
              ),
            ],
            if (routeReadyToStart) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kMapHorizontalHolderClearance,
                ),
                child: _heroAction(
                  context,
                  label: context.l10n.tr('Starten'),
                  icon: Icons.navigation,
                  onPressed: onStartNavigation,
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kMapHorizontalHolderClearance,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!destinationReached) closeAction,
                  if (!destinationReached && showTemporaryRouteChoice) ...[
                    SizedBox(width: compactLandscape ? 6 : 10),
                    routeChoiceAction,
                  ],
                  const Spacer(),
                  editAction,
                  if (showVoiceAction) ...[
                    SizedBox(width: compactLandscape ? 6 : 10),
                    voiceAction,
                  ],
                  SizedBox(width: compactLandscape ? 10 : 16),
                  refreshAction,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
