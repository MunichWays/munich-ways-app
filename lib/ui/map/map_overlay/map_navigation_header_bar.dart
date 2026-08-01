import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
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

    final refreshAction = IconButton.filled(
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.mapRouteColor,
        disabledBackgroundColor: Colors.white54,
        disabledForegroundColor: AppColors.mapRouteColor,
        minimumSize: const Size(44, 44),
      ),
      padding: const EdgeInsets.all(10),
      tooltip: route.state == MapRouteState.LOADING
          ? (context.l10n.isEnglish
              ? 'Calculating route'
              : 'Route wird berechnet')
          : (context.l10n.isEnglish
              ? 'Recalculate route'
              : 'Route neu berechnen'),
      onPressed: route.state == MapRouteState.LOADING ? null : onRefreshRoute,
      icon: route.state == MapRouteState.LOADING
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: AppColors.mapRouteColor,
                strokeWidth: 2.5,
              ),
            )
          : const Icon(Icons.refresh, size: 26),
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
          color: Colors.white,
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
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (model.navigationStarted && nextManeuver != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                child: Row(
                  children: [
                    Icon(
                      _maneuverIcon(nextManeuver!),
                      size: 32,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nextManeuver!.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
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
            Center(child: stats),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                closeAction,
                const Spacer(),
                IconButton(
                  color: Colors.white,
                  tooltip: context.l10n.isEnglish
                      ? 'Edit route'
                      : 'Route bearbeiten',
                  onPressed: onEditRoute,
                  icon: const Icon(Icons.edit_location_alt),
                ),
                if (route.state == MapRouteState.SHOWN &&
                    route.route != null &&
                    model.navigationStarted &&
                    model.voiceGuidanceAvailable)
                  IconButton(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    tooltip: model.voiceGuidanceEnabled
                        ? (context.l10n.isEnglish
                            ? 'Turn off voice guidance'
                            : 'Sprachansagen ausschalten')
                        : (context.l10n.isEnglish
                            ? 'Turn on voice guidance'
                            : 'Sprachansagen einschalten'),
                    onPressed: onToggleVoiceGuidance,
                    icon: Icon(
                      model.voiceGuidanceEnabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                    ),
                  ),
                const SizedBox(width: 4),
                refreshAction,
              ],
            ),
            if (route.state == MapRouteState.SHOWN &&
                route.route != null &&
                !model.navigationStarted &&
                model.routeStart == null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.munichWaysYellow,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: onStartNavigation,
                  icon: const Icon(Icons.navigation, size: 24),
                  label: Text(context.l10n.tr('Starten')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
