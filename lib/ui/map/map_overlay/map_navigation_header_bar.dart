import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/map_action_buttons/route_button_bar.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';

/// Blue navigation summary shown while a destination is set (same color as the route line).
class MapNavigationHeaderBar extends StatelessWidget {
  const MapNavigationHeaderBar({
    super.key,
    required this.model,
  });

  final MapScreenViewModel model;

  static String _formatKm(double meters) {
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  static String _formatMin(double seconds) {
    final min = (seconds / 60.0).round();
    return '$min Min';
  }

  @override
  Widget build(BuildContext context) {
    final dest = model.destination;
    if (dest == null) {
      return const SizedBox.shrink();
    }

    final title = dest.displayName?.trim();
    final headline = (title != null && title.isNotEmpty) ? title : 'Ziel';

    final route = model.route;
    final Widget stats;
    switch (route.state) {
      case MapRouteState.LOADING:
        stats = const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        );
        break;
      case MapRouteState.SHOWN:
      case MapRouteState.HIDDEN:
        final r = route.route;
        if (r == null) {
          stats = const Text(
            '…',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          );
          break;
        }
        stats = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatKm(r.distance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '·',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            Text(
              _formatMin(r.duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
        break;
      case MapRouteState.ERROR:
      case MapRouteState.NO_ROUTE:
        stats = Text(
          route.state == MapRouteState.ERROR ? '—' : '…',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        );
        break;
    }

    return Material(
      color: AppColors.mapRouteColor,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              headline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: stats),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => model.clearDestination(),
                  child: const Text(
                    'Route beenden',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
