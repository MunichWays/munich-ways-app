import 'package:flutter/material.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';

/// Scrollable search results, errors, hints, and recent destinations.
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
        child: Padding(
          padding: EdgeInsets.all(48),
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    final children = <Widget>[];

    if (model.errorMsg != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            model.errorMsg!,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
      children.addAll(_recentSearchWidgets(context, model));
    } else if (model.places.isNotEmpty) {
      for (var i = 0; i < model.places.length; i++) {
        if (i > 0) {
          children.add(const Divider(height: 1));
        }
        final place = model.places.elementAt(i);
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
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            'Data © OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade800,
                ),
          ),
        ),
      );
    } else {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Text(
            model.isFirstSearch
                ? 'Bitte gebe einen Suchbegriff ein z.B. eine Straße in München. Betätige dann den Suchen Button.'
                : 'Keine Ergebnisse vorhanden.\nBitte überprüfe den Suchbegriff.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
      children.addAll(_recentSearchWidgets(context, model));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
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
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'Letzte Ziele',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(
            onPressed: model.clearAllRecentSearches,
            child: const Text('Suchverlauf löschen'),
          ),
        ],
      ),
      for (final recentSearch in model.recentSearches) ...[
        const Divider(height: 1),
        ListTile(
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(recentSearch.displayName!),
          ),
          trailing: Icon(
            Icons.arrow_forward,
            semanticLabel: 'Ziel auswählen: ${recentSearch.displayName!}',
          ),
          onTap: () {
            Navigator.pop(context, recentSearch);
          },
        ),
      ],
    ];
  }
}
