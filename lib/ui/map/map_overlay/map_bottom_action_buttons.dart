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

/// Bottom map controls: destination search and settings.
class MapBottomActionButtons extends StatelessWidget {
  const MapBottomActionButtons({
    super.key,
    required this.model,
    required this.searchCenterProvider,
    required this.onPressLocation,
    this.showSearch = true,
    this.navigationBar,
  });

  final MapScreenViewModel model;
  final LatLng? Function() searchCenterProvider;
  final VoidCallback onPressLocation;
  final bool showSearch;
  final Widget? navigationBar;

  static const double _maxLandscapeContentWidth = 480;

  @override
  Widget build(BuildContext context) {
    // Sit above the OSM attribution strip at the bottom of the map.
    final bottomInset = MediaQuery.paddingOf(context).bottom +
        kMapBottomActionRowPaddingAboveSafeBottom;
    final controlsOnLeft = model.sidePanelEdge == MapSidePanelEdge.left;
    final infoButton = MapOverlayButton(
      tooltip: context.l10n.tr('Info'),
      onPressed: () => showMapInfoSheet(context),
      child: const Icon(Icons.info_outline),
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
    final actionButtons = controlsOnLeft
        ? [trackingButton, settingsButton, infoButton]
        : [infoButton, settingsButton, trackingButton];

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: actionButtons,
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
