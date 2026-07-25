import 'package:flutter/material.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/place_search/place_search_result.dart';
import 'package:munich_ways/ui/place_search/place_search_sheet.dart';

class MapSearchBar extends StatelessWidget {
  const MapSearchBar({
    super.key,
    required this.model,
  });

  final MapScreenViewModel model;

  Future<void> _openSearch(BuildContext context) async {
    final result = await showPlaceSearchSheet(context);
    if (!context.mounted) {
      return;
    }
    if (result is Place) {
      model.setDestination(result);
    } else if (result == PlaceSearchSheetResult.selectOnMap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gewünschtes Ziel auf der Karte lange antippen.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 5,
        shadowColor: Colors.black38,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openSearch(context),
          child: Semantics(
            button: true,
            label: 'Ziel suchen',
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.search),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Wohin möchtest du?',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
