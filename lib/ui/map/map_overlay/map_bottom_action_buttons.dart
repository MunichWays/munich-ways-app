import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/map/map_overlay/map_search_bar.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

/// Bottom map controls: destination search, location, settings and info.
class MapBottomActionButtons extends StatelessWidget {
  const MapBottomActionButtons({
    super.key,
    required this.model,
    required this.searchCenterProvider,
    required this.onPlanRoute,
    required this.onSelectOnMap,
    required this.onPressLocation,
    this.onReloadNetwork,
    this.showSearch = true,
    this.navigationBar,
    this.attributionExpanded = false,
    this.onToggleAttribution,
  });

  final MapScreenViewModel model;
  final LatLng? Function() searchCenterProvider;
  final Future<void> Function() onPlanRoute;
  final VoidCallback onSelectOnMap;
  final VoidCallback onPressLocation;
  final Future<void> Function()? onReloadNetwork;
  final bool showSearch;
  final Widget? navigationBar;
  final bool attributionExpanded;
  final VoidCallback? onToggleAttribution;

  static const double _maxLandscapeContentWidth = 480;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom +
        (attributionExpanded
            ? kMapBottomActionRowExpandedPadding
            : kMapBottomActionRowCollapsedPadding);
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (model.initialRatingsLoadFailed && onReloadNetwork != null) ...[
            _WidthLimitedMapContent(
              maxWidth: _maxLandscapeContentWidth,
              child: FilledButton.icon(
                onPressed: model.loading ? null : onReloadNetwork,
                icon: model.loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(context.l10n.reloadNetwork),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (navigationBar case final bar?) ...[
            _WidthLimitedMapContent(
              maxWidth: _maxLandscapeContentWidth,
              child: bar,
            ),
            const SizedBox(height: 8),
          ],
          if (showSearch) ...[
            _WidthLimitedMapContent(
              maxWidth: _maxLandscapeContentWidth,
              child: MapSearchBar(
                model: model,
                searchCenterProvider: searchCenterProvider,
                onPlanRoute: onPlanRoute,
                onSelectOnMap: onSelectOnMap,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _WidthLimitedMapContent extends StatelessWidget {
  const _WidthLimitedMapContent({
    required this.maxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}
