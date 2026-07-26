import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/localization/app_localizations.dart';
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
    this.showSearch = true,
    this.navigationBar,
  });

  final MapScreenViewModel model;
  final LatLng? Function() searchCenterProvider;
  final bool showSearch;
  final Widget? navigationBar;

  @override
  Widget build(BuildContext context) {
    // Sit above the OSM attribution strip at the bottom of the map.
    final bottomInset = MediaQuery.paddingOf(context).bottom +
        kMapBottomActionRowPaddingAboveSafeBottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (navigationBar case final bar?) ...[
            bar,
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (showSearch) ...[
                Expanded(
                  child: MapSearchBar(
                    model: model,
                    searchCenterProvider: searchCenterProvider,
                  ),
                ),
                const SizedBox(width: 12),
              ] else
                const Spacer(),
              MapOverlayButton(
                circular: false,
                tooltip: context.l10n.settings,
                onPressed: () => showMapSettingsSheet(context, model),
                child: const Icon(Icons.settings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
