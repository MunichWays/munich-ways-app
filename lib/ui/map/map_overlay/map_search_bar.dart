import 'package:flutter/material.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/place_search/place_search_result.dart';
import 'package:munich_ways/ui/place_search/place_search_sheet.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:latlong2/latlong.dart';

class MapSearchBar extends StatefulWidget {
  const MapSearchBar({
    super.key,
    required this.model,
    required this.searchCenterProvider,
    required this.onPlanRoute,
    required this.onSelectOnMap,
    this.favoritesStore,
  });

  final MapScreenViewModel model;
  final LatLng? Function() searchCenterProvider;
  final Future<void> Function() onPlanRoute;
  final VoidCallback onSelectOnMap;
  final RecentSearchesStore? favoritesStore;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  List<Place> _favorites = const [];

  RecentSearchesStore get _favoritesStore =>
      widget.favoritesStore ?? favoritePlacesRepo;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _favoritesStore.load();
      if (mounted) {
        setState(() => _favorites = favorites.take(3).toList());
      }
    } catch (error, stackTrace) {
      log.w(
        'Loading favorite shortcuts failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _openSearch(BuildContext context) async {
    final result = await showPlaceSearchSheet(
      context,
      searchCenter: widget.searchCenterProvider(),
    );
    if (!context.mounted) {
      return;
    }
    await _loadFavorites();
    if (!context.mounted) return;
    if (result is Place) {
      widget.model.setDestination(result);
    } else if (result is SavedRoute) {
      widget.model.setSavedRoutePlan(result);
    } else if (result == PlaceSearchSheetResult.planRoute) {
      await widget.onPlanRoute();
    } else if (result == PlaceSearchSheetResult.selectOnMap) {
      widget.onSelectOnMap();
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
    final search = Material(
      key: const ValueKey('map-destination-search-button'),
      color: AppColors.uiPrimary,
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
                Icon(
                  Icons.search,
                  color: Colors.white,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.l10n.isEnglish ? 'Destination?' : 'Wohin?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (_favorites.isEmpty) return search;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        search,
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < _favorites.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _favoriteButton(context, _favorites[i])),
            ],
          ],
        ),
      ],
    );
  }

  Widget _favoriteButton(BuildContext context, Place favorite) {
    return FilledButton(
      style: AppButtonStyles.secondary(context).merge(
        FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
      onPressed: () => widget.model.setDestination(favorite),
      child: Text(
        favorite.displayName ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
