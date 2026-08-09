import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/icons/munichways_icons_icons.dart';
import 'package:munich_ways/ui/info/info_sheet.dart';
import 'package:munich_ways/ui/map/map_overlay/map_settings_sheet.dart';
import 'package:munich_ways/ui/map/map_overlay/map_search_bar.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_button.dart';
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
    final controlsOnLeft = model.sidePanelEdge == MapSidePanelEdge.left;
    final infoButton = MapOverlayButton(
      tooltip: context.l10n.tr('Info'),
      onPressed: () => showMapInfoSheet(context),
      child: const Icon(Icons.info_outline),
    );
    final attributionButton = MapOverlayButton(
      size: 36,
      outlined: true,
      tooltip: attributionExpanded
          ? (context.l10n.isEnglish
              ? 'Hide map attribution'
              : 'Kartenquellen ausblenden')
          : (context.l10n.isEnglish
              ? 'Show map attribution'
              : 'Kartenquellen anzeigen'),
      onPressed: onToggleAttribution,
      child: const Text(
        '©',
        style: TextStyle(
          color: Color(0xFF616161),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final settingsButton = MapOverlayButton(
      tooltip: context.l10n.settings,
      onPressed: () => showMapSettingsSheet(context, model),
      child: const Icon(Icons.settings),
    );
    final trackingButton = MapOverlayButton(
      circular: false,
      tooltip: _locationTooltip(context, model.locationState),
      isActive: model.locationState == LocationState.FOLLOW ||
          model.locationState == LocationState.FOLLOW_AND_ROTATE_MAP,
      emphasizeActive: true,
      onPressed: onPressLocation,
      child: _locationIcon(model.locationState),
    );
    final infoAndAttribution = Row(
      mainAxisSize: MainAxisSize.min,
      children: controlsOnLeft
          ? [attributionButton, const SizedBox(width: 8), infoButton]
          : [infoButton, const SizedBox(width: 8), attributionButton],
    );
    final leadingControl = controlsOnLeft ? trackingButton : infoAndAttribution;
    final trailingControl =
        controlsOnLeft ? infoAndAttribution : trackingButton;

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
          SizedBox(
            width: double.infinity,
            height: kMapOverlayControlSize,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: leadingControl,
                  ),
                ),
                SizedBox.square(
                  dimension: kMapOverlayControlSize,
                  child: settingsButton,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailingControl,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationIcon(LocationState state) {
    return switch (state) {
      LocationState.NOT_AVAILABLE =>
        const Icon(Icons.location_searching, color: Colors.white38),
      LocationState.DISPLAY => const Icon(Icons.my_location),
      LocationState.FOLLOW => const Icon(Icons.my_location),
      LocationState.FOLLOW_AND_ROTATE_MAP =>
        const Icon(MunichwaysIcons.compass),
    };
  }

  String _locationTooltip(BuildContext context, LocationState state) {
    final english = context.l10n.isEnglish;
    return switch (state) {
      LocationState.NOT_AVAILABLE => english
          ? 'Location unavailable – tap to grant permission'
          : 'Standort nicht verfügbar – antippen, um Berechtigung zu erteilen',
      LocationState.DISPLAY => english
          ? 'Show location – tap to follow your position'
          : 'Standort anzeigen – antippen, um der Position zu folgen',
      LocationState.FOLLOW => english
          ? 'Following location – tap to rotate the map'
          : 'Folgt Standort – antippen, um Karte mitzudrehen',
      LocationState.FOLLOW_AND_ROTATE_MAP => english
          ? 'Following location and rotating map – tap to stop'
          : 'Folgt Standort und dreht Karte – antippen, um Standort-Verfolgung zu beenden',
    };
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
