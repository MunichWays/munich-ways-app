import 'package:flutter/material.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/nav_routes.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/search_location/search_location_screen.dart';

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
            onPressed: () {},
            child: const Icon(Icons.info_outline),
          ),
          MapOverlayButton(
            circular: false,
            tooltip: 'Suche',
            onPressed: () async {
              final place = await Navigator.push<Place?>(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchLocationScreen(),
                ),
              );
              if (place != null && context.mounted) {
                model.setDestination(place);
              }
            },
            child: const Icon(Icons.search),
          ),
          MapOverlayButton(
            circular: false,
            tooltip: 'Einstellungen',
            onPressed: () {
              Navigator.pushNamed(context, NavRoutes.settings);
            },
            child: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }
}
