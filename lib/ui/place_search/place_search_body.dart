import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Scrollable search results, errors, and recent destinations.
class PlaceSearchBody extends StatefulWidget {
  const PlaceSearchBody({
    super.key,
    required this.model,
  });

  final PlaceSearchScreenViewModel model;

  @override
  State<PlaceSearchBody> createState() => _PlaceSearchBodyState();
}

class _PlaceSearchBodyState extends State<PlaceSearchBody> {
  String? _selectedPlaceKey;

  PlaceSearchScreenViewModel get model => widget.model;

  String _placeKey(Place place) =>
      '${place.latLng.latitude}:${place.latLng.longitude}';

  Place? _selectedPlace(PlaceSearchScreenViewModel model) {
    if (_selectedPlaceKey == null) return null;
    for (final place in [...model.favoritePlaces, ...model.recentSearches]) {
      if (_placeKey(place) == _selectedPlaceKey) return place;
    }
    return null;
  }

  void _selectSavedPlace(Place place, bool selected) {
    setState(() => _selectedPlaceKey = selected ? _placeKey(place) : null);
  }

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
    var showSavedPlaceToolbar = false;

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
      showSavedPlaceToolbar =
          model.favoritePlaces.isNotEmpty || model.recentSearches.isNotEmpty;
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
      showSavedPlaceToolbar =
          model.favoritePlaces.isNotEmpty || model.recentSearches.isNotEmpty;
    }

    final results = ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: children,
    );
    final content = showAttribution
        ? Column(
            children: [
              Expanded(child: results),
              _buildAttribution(context),
            ],
          )
        : results;
    if (!showSavedPlaceToolbar) return content;

    return Column(
      children: [
        _savedPlaceToolbar(context, model),
        const Divider(height: 1),
        Expanded(child: content),
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
          selected: _placeKey(favorite) == _selectedPlaceKey,
          onSelected: (selected) => _selectSavedPlace(favorite, selected),
          onConfirm: () => _selectPlace(context, model, favorite),
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
          selected: _placeKey(recentSearch) == _selectedPlaceKey,
          onSelected: (selected) => _selectSavedPlace(recentSearch, selected),
          onConfirm: () => _selectPlace(context, model, recentSearch),
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
    required bool selected,
    required ValueChanged<bool> onSelected,
    required VoidCallback onConfirm,
  }) {
    return InkWell(
      onTap: onConfirm,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onSelected(value ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                place.displayName!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            IconButton(
              tooltip: context.l10n.isEnglish
                  ? 'Use selected destination'
                  : 'Auswahl übernehmen',
              color: AppColors.mapGreen,
              iconSize: 32,
              onPressed: onConfirm,
              icon: const Icon(Icons.check_circle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedPlaceToolbar(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    final selected = _selectedPlace(model);
    final isFavorite = selected != null && model.isFavorite(selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.isEnglish
                ? 'Delete permanently'
                : 'Endgültig löschen',
            color: Theme.of(context).colorScheme.error,
            onPressed: selected == null
                ? null
                : () => _confirmDelete(context, model, selected),
            icon: const Icon(Icons.delete_outline),
          ),
          const Spacer(),
          IconButton(
            tooltip: context.l10n.isEnglish ? 'Rename' : 'Umbenennen',
            onPressed: selected == null
                ? null
                : () => isFavorite
                    ? _renameFavorite(context, model, selected)
                    : _renameRecentSearch(context, model, selected),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: isFavorite
                ? (context.l10n.isEnglish
                    ? 'Remove favorite'
                    : 'Favorit entfernen')
                : (context.l10n.isEnglish
                    ? 'Add favorite'
                    : 'Als Favorit speichern'),
            onPressed: selected == null
                ? null
                : () => _toggleSelectedFavorite(context, model, selected),
            icon: Icon(isFavorite ? Icons.star : Icons.star_border),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSelectedFavorite(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place place,
  ) async {
    if (!model.isFavorite(place) && model.favoritePlaces.length >= 3) {
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
    await model.toggleFavorite(place);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place place,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              context.l10n.isEnglish ? 'Delete destination?' : 'Ziel löschen?',
            ),
            content: Text(place.displayName ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.tr('Abbrechen')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.isEnglish ? 'Delete' : 'Löschen'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await model.deleteSavedPlace(place);
    if (mounted) setState(() => _selectedPlaceKey = null);
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
