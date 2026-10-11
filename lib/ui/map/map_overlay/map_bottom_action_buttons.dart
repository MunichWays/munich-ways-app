import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    this.onNavigationBarHeightChanged,
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
  final ValueChanged<double>? onNavigationBarHeightChanged;
  final bool attributionExpanded;
  final VoidCallback? onToggleAttribution;

  static const double _maxLandscapeContentWidth = 480;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final landscapePhone =
        mediaQuery.size.width >= mediaQuery.size.height * 1.5;
    final bottomInset = mediaQuery.padding.bottom +
        (attributionExpanded
            ? kMapBottomActionRowExpandedPadding
            : navigationBar != null && !model.navigationStarted
                ? 4
                : kMapBottomActionRowCollapsedPadding);
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (model.initialRatingsLoadFailed && onReloadNetwork != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kMapHorizontalHolderClearance,
              ),
              child: _WidthLimitedMapContent(
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
            ),
            const SizedBox(height: 8),
          ],
          if (navigationBar case final bar?) ...[
            Padding(
              padding: EdgeInsets.only(
                left: landscapePhone
                    ? kMapHorizontalHolderClearance +
                        (model.sidePanelEdge == MapSidePanelEdge.left ? 64 : 0)
                    : 0,
                // In landscape the controls sit beside the panel. Reserve their
                // 56-pixel tap targets plus a gap instead of pushing them up.
                right: landscapePhone &&
                        model.sidePanelEdge == MapSidePanelEdge.right
                    ? kMapHorizontalHolderClearance + 64
                    : 0,
              ),
              child: Align(
                alignment:
                    landscapePhone ? Alignment.centerRight : Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: landscapePhone ? 360 : double.infinity,
                  ),
                  child: _NavigationBarSizeObserver(
                    onHeightChanged: onNavigationBarHeightChanged,
                    child: SizedBox(width: double.infinity, child: bar),
                  ),
                ),
              ),
            ),
            if (showSearch) const SizedBox(height: 8),
          ],
          if (showSearch) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kMapHorizontalHolderClearance,
              ),
              child: _WidthLimitedMapContent(
                maxWidth: _maxLandscapeContentWidth,
                child: MapSearchBar(
                  model: model,
                  searchCenterProvider: searchCenterProvider,
                  onPlanRoute: onPlanRoute,
                  onSelectOnMap: onSelectOnMap,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Measures the whole panel, including folding and accessibility text wrapping.
class _NavigationBarSizeObserver extends SingleChildRenderObjectWidget {
  const _NavigationBarSizeObserver(
      {required super.child, this.onHeightChanged});

  final ValueChanged<double>? onHeightChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _NavigationBarSizeRenderObject(onHeightChanged);

  @override
  void updateRenderObject(BuildContext context,
          covariant _NavigationBarSizeRenderObject renderObject) =>
      renderObject.onHeightChanged = onHeightChanged;
}

class _NavigationBarSizeRenderObject extends RenderProxyBox {
  _NavigationBarSizeRenderObject(this.onHeightChanged);

  ValueChanged<double>? onHeightChanged;
  double? _lastHeight;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _lastHeight) return;
    _lastHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeightChanged?.call(height);
    });
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
