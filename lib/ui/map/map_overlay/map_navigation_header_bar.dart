import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
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

    final route = model.route;
    final Widget stats;
    switch (route.state) {
      case MapRouteState.LOADING:
        stats = Text(
          'Route wird berechnet...',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 15,
            fontStyle: FontStyle.italic,
          ),
        );
        break;
      case MapRouteState.SHOWN:
        final r = route.route;
        if (r == null) {
          stats = const Text(
            '…',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          );
          break;
        }
        stats = Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text(
                  'Bei Start:',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 15),
                ),
                Text(
                  _formatKm(r.distance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '·',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
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
            ));
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
        padding: const EdgeInsets.all(8),
        // [Wrap] + [WrapAlignment.spaceBetween]: stats and action share one line
        // when their intrinsic widths fit; the previous LayoutBuilder+SizedBox(
        // width: constraints.maxWidth) forced the second child to claim the
        // full line width, so the action always wrapped.
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            stats,
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => model.clearDestination(),
              child: const Text(
                'Route beenden',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
