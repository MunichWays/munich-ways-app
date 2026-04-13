import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/map_overlay/map_info_sheet.dart';
import 'package:munich_ways/ui/map/map_overlay/map_settings_sheet.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/search_location/search_location_sheet.dart';

/// Bottom map controls: info (placeholder), search, settings.
class MapBottomActionButtons extends StatelessWidget {
  const MapBottomActionButtons({
    super.key,
    required this.model,
  });

  final MapScreenViewModel model;

  @override
  Widget build(BuildContext context) {
    // Sit above the OSM attribution strip at the bottom of the map.
    final bottomInset = MediaQuery.paddingOf(context).bottom +
        kMapBottomActionRowPaddingAboveSafeBottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MapOverlayButton(
            circular: false,
            tooltip: 'Info',
            onPressed: () => showMapInfoSheet(context),
            child: const Icon(Icons.info_outline),
          ),
          MapOverlayButton(
            circular: false,
            tooltip: 'Suche',
            onPressed: () async {
              final place = await showSearchLocationSheet(context);
              if (place != null && context.mounted) {
                model.setDestination(place);
              }
            },
            child: const Icon(Icons.search),
          ),
          MapOverlayButton(
            circular: false,
            tooltip: 'Einstellungen',
            onPressed: () => showMapSettingsSheet(context, model),
            child: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }
}
