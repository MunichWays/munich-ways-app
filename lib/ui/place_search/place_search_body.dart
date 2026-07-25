import 'package:flutter/material.dart';
import 'package:munich_ways/ui/place_search/place_search_result.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Scrollable search results, errors, and recent destinations.
class PlaceSearchBody extends StatelessWidget {
  const PlaceSearchBody({
    super.key,
    required this.model,
  });

  final PlaceSearchScreenViewModel model;

  @override
  Widget build(BuildContext context) {
    if (model.loading) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    final children = <Widget>[];
    var showAttribution = false;
    var mapSelectionAdded = false;

    if (model.errorMsg != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            model.errorMsg!,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
      children.addAll(_recentSearchWidgets(context, model));
    } else if (model.places.isNotEmpty) {
      if (model.correctedQuery case final correctedQuery?) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Korrigiert zu „$correctedQuery“'),
          ),
        );
      }
      for (var i = 0; i < model.places.length; i++) {
        if (i > 0) {
          children.add(const Divider(height: 1));
        }
        final place = model.places[i];
        children.add(
          ListTile(
            title: Text(place.displayName!),
            trailing: Icon(
              Icons.arrow_forward,
              semanticLabel: 'Ziel auswählen: ${place.displayName!}',
            ),
            onTap: () {
              model.addToRecentSearches(place);
              Navigator.pop(context, place);
            },
          ),
        );
      }
      showAttribution = true;
    } else {
      if (!model.isFirstSearch) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Keine Ergebnisse vorhanden.\nBitte überprüfe den Suchbegriff.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        );
        children.add(const Divider(height: 1));
        children.add(_mapSelectionWidget(context));
        mapSelectionAdded = true;
      }
      children.addAll(_recentSearchWidgets(context, model));
    }

    if (!mapSelectionAdded) {
      if (children.isNotEmpty) {
        children.add(const Divider(height: 1));
      }
      children.add(_mapSelectionWidget(context));
    }

    if (showAttribution) {
      children.add(
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://www.geoapify.com/'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text(
              'Powered by Geoapify · Data © OpenStreetMap contributors · '
              'Straßennamen © Landeshauptstadt München',
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: children,
    );
  }

  Widget _mapSelectionWidget(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: const Icon(Icons.add_location_alt_outlined),
      title: const Text('Auf Karte auswählen'),
      onTap: () => Navigator.pop(
        context,
        PlaceSearchSheetResult.selectOnMap,
      ),
    );
  }

  List<Widget> _recentSearchWidgets(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    if (model.recentSearches.isEmpty) {
      return [];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
        child: Text(
          'Letzte Ziele',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      for (final recentSearch in model.recentSearches) ...[
        const Divider(height: 1),
        ListTile(
          title: Text(recentSearch.displayName!),
          trailing: Icon(
            Icons.arrow_forward,
            semanticLabel: 'Ziel auswählen: ${recentSearch.displayName!}',
          ),
          onTap: () {
            model.addToRecentSearches(recentSearch);
            Navigator.pop(context, recentSearch);
          },
        ),
      ],
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: model.clearAllRecentSearches,
          icon: const Icon(Icons.delete_outline),
          label: const Text('(Suchverlauf löschen)'),
        ),
      ),
    ];
  }
}
