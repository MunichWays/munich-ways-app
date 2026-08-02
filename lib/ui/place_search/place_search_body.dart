import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
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
      children.addAll(_savedPlaceWidgets(context, model));
    } else if (model.places.isNotEmpty) {
      if (model.correctedQuery case final correctedQuery?) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(context.l10n.isEnglish
                ? 'Corrected to “$correctedQuery”'
                : 'Korrigiert zu „$correctedQuery“'),
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
            dense: true,
            leading: Icon(
              Icons.location_on_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              place.displayName!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.black45,
              semanticLabel: context.l10n.selectDestination(place.displayName!),
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
              context.l10n.tr(
                'Keine Ergebnisse vorhanden.\nBitte überprüfe den Suchbegriff.',
              ),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        );
        children.add(const Divider(height: 1));
      }
      children.addAll(_savedPlaceWidgets(context, model));
    }

    final results = ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: children,
    );
    if (!showAttribution) return results;

    return Column(
      children: [
        Expanded(child: results),
        _buildAttribution(context),
      ],
    );
  }

  static const _attributionStyle = TextStyle(
    color: Colors.black45,
    fontSize: 10,
    height: 1.2,
  );

  Widget _buildAttribution(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      color: Theme.of(context).colorScheme.surface,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Powered by ', style: _attributionStyle),
          InkWell(
            onTap: () => launchUrl(
              Uri.parse(
                model.resultsFromNominatim
                    ? 'https://nominatim.org/'
                    : 'https://www.geoapify.com/',
              ),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              model.resultsFromNominatim ? 'Nominatim' : 'Geoapify',
              style: _attributionStyle.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: Colors.black45,
              ),
            ),
          ),
          Text(
            context.l10n.isEnglish
                ? ' · © OpenStreetMap contributors · © City of Munich'
                : ' · © OpenStreetMap-Mitwirkende · © Stadt München',
            style: _attributionStyle,
          ),
        ],
      ),
    );
  }

  List<Widget> _savedPlaceWidgets(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    return [
      ..._favoriteWidgets(context, model),
      ..._recentSearchWidgets(context, model),
    ];
  }

  List<Widget> _favoriteWidgets(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    if (model.favoritePlaces.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Text(
          context.l10n.isEnglish ? 'Favorites' : 'Favoriten',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      for (final favorite in model.favoritePlaces) ...[
        const Divider(height: 1),
        _savedPlaceTile(
          context,
          favorite,
          actions: [
            _routeButton(context, model, favorite),
            IconButton(
              tooltip: context.l10n.isEnglish ? 'Rename' : 'Umbenennen',
              onPressed: () => _renameFavorite(context, model, favorite),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: context.l10n.isEnglish
                  ? 'Remove favorite'
                  : 'Favorit entfernen',
              onPressed: () => model.toggleFavorite(favorite),
              icon: const Icon(Icons.star),
            ),
            IconButton(
              tooltip: context.l10n.isEnglish
                  ? 'Delete permanently'
                  : 'Endgültig löschen',
              onPressed: () => model.deleteSavedPlace(favorite),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
          onRoute: () => _selectPlace(context, model, favorite),
        ),
      ],
    ];
  }

  Future<void> _renameFavorite(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place favorite,
  ) async {
    var name = favorite.displayName ?? '';
    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.l10n.isEnglish ? 'Rename favorite' : 'Favorit umbenennen',
        ),
        content: TextFormField(
          initialValue: name,
          autofocus: true,
          onChanged: (value) => name = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.tr('Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, name),
            child: Text(
              context.l10n.isEnglish ? 'Save' : 'Speichern',
            ),
          ),
        ],
      ),
    );
    final trimmedName = updatedName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) return;
    await model.renameFavorite(favorite, trimmedName);
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
          context.l10n.tr('Letzte Ziele'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      for (final recentSearch in model.recentSearches) ...[
        const Divider(height: 1),
        _savedPlaceTile(
          context,
          recentSearch,
          actions: [
            _routeButton(context, model, recentSearch),
            IconButton(
              tooltip: context.l10n.isEnglish ? 'Rename' : 'Umbenennen',
              onPressed: () => _renameRecentSearch(
                context,
                model,
                recentSearch,
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: model.isFavorite(recentSearch)
                  ? (context.l10n.isEnglish
                      ? 'Remove favorite'
                      : 'Favorit entfernen')
                  : (context.l10n.isEnglish
                      ? 'Add favorite'
                      : 'Als Favorit speichern'),
              onPressed: () async {
                final isFavorite = model.isFavorite(recentSearch);
                if (!isFavorite && model.favoritePlaces.length >= 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.isEnglish
                            ? 'A maximum of three favorites is possible.'
                            : 'Es sind maximal drei Favoriten möglich.',
                      ),
                    ),
                  );
                  return;
                }
                await model.toggleFavorite(recentSearch);
              },
              icon: Icon(
                model.isFavorite(recentSearch) ? Icons.star : Icons.star_border,
              ),
            ),
            IconButton(
              tooltip: context.l10n.isEnglish
                  ? 'Delete permanently'
                  : 'Endgültig löschen',
              onPressed: () => model.deleteSavedPlace(recentSearch),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
          onRoute: () => _selectPlace(context, model, recentSearch),
        ),
      ],
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: model.clearAllRecentSearches,
          icon: const Icon(Icons.delete_outline),
          label: Text(context.l10n.tr('(Suchverlauf löschen)')),
        ),
      ),
    ];
  }

  Future<void> _renameRecentSearch(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place recentSearch,
  ) async {
    var name = recentSearch.displayName ?? '';
    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.l10n.isEnglish ? 'Rename destination' : 'Ziel umbenennen',
        ),
        content: TextFormField(
          initialValue: name,
          autofocus: true,
          onChanged: (value) => name = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.tr('Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, name),
            child: Text(context.l10n.isEnglish ? 'Save' : 'Speichern'),
          ),
        ],
      ),
    );
    final trimmedName = updatedName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) return;
    await model.renameRecentSearch(recentSearch, trimmedName);
  }

  Widget _savedPlaceTile(
    BuildContext context,
    Place place, {
    required List<Widget> actions,
    required VoidCallback onRoute,
  }) {
    return InkWell(
      onTap: onRoute,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                place.displayName!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeButton(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place place,
  ) {
    return IconButton(
      tooltip: context.l10n.isEnglish ? 'Calculate route' : 'Route berechnen',
      onPressed: () => _selectPlace(context, model, place),
      icon: const Icon(Icons.directions_bike_outlined),
    );
  }

  void _selectPlace(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place place,
  ) {
    model.addToRecentSearches(place);
    Navigator.pop(context, place);
  }
}
