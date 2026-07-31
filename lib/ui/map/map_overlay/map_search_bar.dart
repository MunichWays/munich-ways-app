import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/place_search/place_search_result.dart';
import 'package:munich_ways/ui/place_search/place_search_sheet.dart';
import 'package:latlong2/latlong.dart';

class MapSearchBar extends StatelessWidget {
  const MapSearchBar({
    super.key,
    required this.model,
    required this.searchCenterProvider,
    required this.onPlanRoute,
    required this.onSelectOnMap,
  });

  final MapScreenViewModel model;
  final LatLng? Function() searchCenterProvider;
  final Future<void> Function() onPlanRoute;
  final VoidCallback onSelectOnMap;

  Future<void> _openSearch(BuildContext context) async {
    final result = await showPlaceSearchSheet(
      context,
      searchCenter: searchCenterProvider(),
    );
    if (!context.mounted) {
      return;
    }
    if (result is Place) {
      model.setDestination(result);
    } else if (result == PlaceSearchSheetResult.planRoute) {
      await onPlanRoute();
    } else if (result == PlaceSearchSheetResult.selectOnMap) {
      onSelectOnMap();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.tr('Gewünschtes Ziel auf der Karte lange antippen.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 5,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSearch(context),
        child: Semantics(
          button: true,
          label: context.l10n.tr('Ziel suchen'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.search),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.l10n.isEnglish ? 'Destination?' : 'Wohin?',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
