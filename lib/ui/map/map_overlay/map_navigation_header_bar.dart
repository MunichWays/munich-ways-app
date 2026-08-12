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
    this.nextManeuver,
  });

  final MapScreenViewModel model;
  final Future<void> Function() onRefreshRoute;
  final VoidCallback onEditRoute;
  final Future<void> Function() onStartNavigation;
  final VoidCallback onToggleVoiceGuidance;
  final VoidCallback onEndRoute;
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
          height: 56,
          child: Center(
            child: IgnorePointer(
              child: FilledButton.icon(
                style: AppButtonStyles.hero(context).merge(
                  FilledButton.styleFrom(
                    minimumSize: const Size(180, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                onPressed: onPressed,
                icon: Icon(icon, size: 24),
                label: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dest = model.destination;
    if (dest == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge?.copyWith(
          color: Colors.white,
        ) ??
        const TextStyle(color: Colors.white);
    final emphasisStyle = baseStyle.copyWith(fontWeight: FontWeight.w500);

    final route = model.route;
    final guidanceDisplay = model.navigationStarted
        ? nextManeuver ??
            VoiceGuidanceDisplay(
              text: context.l10n.followRouteOnMap,
              type: 'map',
            )
        : null;
    final destinationReached = guidanceDisplay?.isFinalDestination ?? false;
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
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatKm(r.distance),
                softWrap: false,
                style: emphasisStyle,
              ),
              const SizedBox(width: 4),
              Text('·', style: baseStyle),
              const SizedBox(width: 4),
              Text(
                _formatMin(r.duration),
                softWrap: false,
                style: emphasisStyle,
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
    final navigationTrackingInterrupted = model.navigationStarted &&
        model.locationState != LocationState.FOLLOW_AND_ROTATE_MAP;
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
          ? SizedBox.square(
              dimension: 52,
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
                    ? const Icon(Icons.refresh, size: 28)
                    : const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.heroForeground,
                          strokeWidth: 2.5,
                        ),
                      ),
              ),
            )
          : SizedBox.square(
              dimension: 52,
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
                    ? const Icon(Icons.refresh, size: 28)
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
        dimension: 52,
        child: IconButton.outlined(
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70, width: 1.5),
          ),
          tooltip: editLabel,
          onPressed: onEditRoute,
          icon: const Icon(Icons.edit_location_alt, size: 27),
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
        dimension: 52,
        child: IconButton.outlined(
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70, width: 1.5),
          ),
          tooltip: voiceLabel,
          onPressed: onToggleVoiceGuidance,
          icon: Icon(
            model.voiceGuidanceEnabled ? Icons.volume_up : Icons.volume_off,
            size: 27,
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
        dimension: 56,
        child: IconButton(
          color: Colors.white70,
          tooltip: closeLabel,
          onPressed: onEndRoute,
          icon: const Icon(Icons.close),
        ),
      ),
    );
    return Material(
      color: AppColors.mapRouteColor,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (guidanceDisplay != null)
              Padding(
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
                  ],
                ),
              ),
            SizedBox(width: double.infinity, child: Center(child: stats)),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kMapHorizontalHolderClearance,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!destinationReached) closeAction,
                  const Spacer(),
                  editAction,
                  if (showVoiceAction) ...[
                    const SizedBox(width: 10),
                    voiceAction,
                  ],
                  const SizedBox(width: 10),
                  refreshAction,
                ],
              ),
            ),
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
            if (route.state == MapRouteState.SHOWN &&
                route.route != null &&
                !model.navigationStarted &&
                model.routeStart == null) ...[
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
          ],
        ),
      ),
    );
  }
}
