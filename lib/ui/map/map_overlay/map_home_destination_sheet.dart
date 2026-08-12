import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/place_search/place_search_body.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:provider/provider.dart';

class MapHomeDestinationSheet extends StatefulWidget {
  const MapHomeDestinationSheet({
    super.key,
    required this.searchCenter,
    required this.onSelected,
    required this.onPlanRoute,
    required this.onSelectOnMap,
    required this.onShowInfo,
    required this.onToggleAttribution,
    required this.onShowSettings,
    required this.attributionExpanded,
    this.favoritesStore,
    this.recentSearchesStore,
    this.savedRoutesStore,
  });

  final LatLng? searchCenter;
  final ValueChanged<Object> onSelected;
  final VoidCallback onPlanRoute;
  final VoidCallback onSelectOnMap;
  final VoidCallback onShowInfo;
  final VoidCallback onToggleAttribution;
  final VoidCallback onShowSettings;
  final bool attributionExpanded;
  final RecentSearchesStore? favoritesStore;
  final RecentSearchesStore? recentSearchesStore;
  final SavedRoutesStore? savedRoutesStore;

  @override
  State<MapHomeDestinationSheet> createState() =>
      _MapHomeDestinationSheetState();
}

class _MapHomeDestinationSheetState extends State<MapHomeDestinationSheet> {
  /// Minimal map-first state: drag handle plus the destination row only.
  double get _minimalSize => .12;

  /// Stable compact height: reaches roughly to the location button and leaves
  /// room for the two quick actions plus favorites without jumping after data
  /// finishes loading.
  double get _compactSize => .28;

  List<double> get _snapSizes => [_minimalSize, _compactSize, .58, 1.0];

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _query = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final PlaceSearchScreenViewModel _model;
  Timer? _debounce;
  bool _searching = false;
  bool _openingSearch = false;
  bool _hasQuery = false;
  bool _hidingAttribution = false;
  bool _selectingFavorite = false;
  bool _showQuickChoices = false;
  bool _showHomeExtras = true;
  double _preservedSheetSize = .28;
  bool _restoringAfterParentUpdate = false;

  @override
  void didUpdateWidget(covariant MapHomeDestinationSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.attributionExpanded) _hidingAttribution = false;
    _restoringAfterParentUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetController.isAttached) {
        _restoringAfterParentUpdate = false;
        return;
      }
      if ((_sheetController.size - _preservedSheetSize).abs() > .005) {
        _sheetController.jumpTo(_preservedSheetSize);
      }
      _restoringAfterParentUpdate = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _model = PlaceSearchScreenViewModel(
      recentSearchesRepo: widget.recentSearchesStore ?? recentSearchesRepo,
      favoritesRepo: widget.favoritesStore,
      savedRoutesRepo: widget.savedRoutesStore,
      searchCenter: widget.searchCenter,
    );
    _sheetController.addListener(_handleSheetSize);
    _focusNode.addListener(_handleFocus);
    _model.addListener(_handleModelChange);
  }

  void _handleModelChange() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_sheetController.isAttached ||
          _sheetController.size > _minimalSize + .01) {
        return;
      }
      _sheetController.jumpTo(_minimalSize);
    });
  }

  void _handleSheetSize() {
    if (!_sheetController.isAttached || _openingSearch) return;
    if (!_restoringAfterParentUpdate) {
      _preservedSheetSize = _sheetController.size;
    }
    if (widget.attributionExpanded &&
        _sheetController.size > _compactSize + .02) {
      _hideAttribution();
    }
    final shouldSearch = _sheetController.size > .9;
    final shouldShowHomeExtras =
        !shouldSearch && _sheetController.size > _minimalSize + .06;
    final shouldShowQuickChoices =
        !shouldSearch && _sheetController.size > _compactSize + .08;
    if (_searching != shouldSearch ||
        _showHomeExtras != shouldShowHomeExtras ||
        _showQuickChoices != shouldShowQuickChoices) {
      if (!shouldSearch) _focusNode.unfocus();
      setState(() {
        _searching = shouldSearch;
        _showHomeExtras = shouldShowHomeExtras;
        _showQuickChoices = shouldShowQuickChoices;
        if (!shouldSearch) _selectingFavorite = false;
      });
      if (shouldSearch) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _searching) _focusNode.requestFocus();
        });
      }
    }
  }

  void _handleFocus() {
    if (!_focusNode.hasFocus || !_sheetController.isAttached) return;
    _preservedSheetSize = 1;
    _sheetController.animateTo(
      1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sheetController
      ..removeListener(_handleSheetSize)
      ..dispose();
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    _query.dispose();
    _model.removeListener(_handleModelChange);
    _model.dispose();
    super.dispose();
  }

  Future<void> _startSearching() async {
    if (!_sheetController.isAttached || _openingSearch) return;
    _hideAttribution();
    _openingSearch = true;
    _preservedSheetSize = 1;
    await _sheetController.animateTo(
      1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    _openingSearch = false;
    setState(() {
      _searching = true;
      _showQuickChoices = false;
    });
    _focusNode.requestFocus();
  }

  void _startFavoriteSelection() {
    _selectingFavorite = true;
    unawaited(_startSearching());
  }

  void _startDestinationSearch() {
    _selectingFavorite = false;
    unawaited(_startSearching());
  }

  void _handleSelection(Object selection) {
    if (!_selectingFavorite) {
      widget.onSelected(selection);
      return;
    }
    if (selection is! Place && selection is! SavedRoute) return;
    unawaited(_saveSelectedFavorite(selection));
  }

  Future<void> _saveSelectedFavorite(Object item) async {
    try {
      final alreadyFavorite = switch (item) {
        Place place => _model.isFavorite(place),
        SavedRoute route => route.isFavorite,
        _ => false,
      };
      if (!alreadyFavorite && _model.favoriteCount >= 3) {
        final replaced = await _chooseFavoriteToReplace(item);
        if (replaced == null) return;
        await _model.replaceFavorite(replaced, item);
      } else if (!alreadyFavorite) {
        if (item is Place) await _model.toggleFavorite(item);
        if (item is SavedRoute) await _model.toggleRouteFavorite(item);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.isEnglish
                  ? 'The favorite could not be saved.'
                  : 'Favorit konnte nicht gespeichert werden.',
            ),
          ),
        );
      }
    }
    if (!mounted) return;
    _selectingFavorite = false;
    _focusNode.unfocus();
    setState(() => _searching = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetController.isAttached) return;
      _preservedSheetSize = _compactSize;
      unawaited(
        _sheetController.animateTo(
          _compactSize,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  Future<Object?> _chooseFavoriteToReplace(Object newItem) {
    return showDialog<Object>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          context.l10n.isEnglish
              ? 'Replace a favorite?'
              : 'Favoriten ersetzen?',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              context.l10n.isEnglish
                  ? 'A maximum of three favorites is possible.'
                  : 'Es sind maximal drei Favoriten möglich.',
            ),
          ),
          for (final favorite in _model.favoriteItems)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, favorite),
              child: Row(
                children: [
                  Icon(favorite is SavedRoute ? Icons.route : Icons.place),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_favoriteName(favorite))),
                ],
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.tr('Abbrechen')),
          ),
        ],
      ),
    );
  }

  String _favoriteName(Object favorite) => switch (favorite) {
        Place place => place.displayName ?? '',
        SavedRoute route => route.name,
        _ => '',
      };

  void _previewSearch(String query) {
    final hasQuery = query.isNotEmpty;
    if (_hasQuery != hasQuery) setState(() => _hasQuery = hasQuery);
    _debounce?.cancel();
    if (query.trim().length < 3) {
      _model.resetSearch();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _model.startSearch(query);
    });
  }

  void _clearQuery() {
    _query.clear();
    setState(() => _hasQuery = false);
    _model.resetSearch();
  }

  void _closeSearch() {
    _debounce?.cancel();
    _query.clear();
    _model.resetSearch();
    _focusNode.unfocus();
    _openingSearch = true;
    setState(() {
      _hasQuery = false;
      _searching = false;
      _showQuickChoices = false;
      _showHomeExtras = true;
      _selectingFavorite = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_sheetController.isAttached) {
        _openingSearch = false;
        return;
      }
      _preservedSheetSize = _compactSize;
      await _sheetController.animateTo(
        _compactSize,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
      _openingSearch = false;
    });
  }

  void _hideAttribution() {
    if (widget.attributionExpanded && !_hidingAttribution) {
      _hidingAttribution = true;
      widget.onToggleAttribution();
    }
  }

  void _runAction(VoidCallback action) {
    _hideAttribution();
    action();
  }

  Future<void> _selectOnMap() async {
    _hideAttribution();
    _focusNode.unfocus();
    _openingSearch = true;
    if (_searching || _showQuickChoices) {
      setState(() {
        _searching = false;
        _showQuickChoices = false;
        _showHomeExtras = true;
      });
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_sheetController.isAttached) {
      _openingSearch = false;
      return;
    }
    _preservedSheetSize = _compactSize;
    await _sheetController.animateTo(
      _compactSize,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    );
    _openingSearch = false;
    if (!mounted) return;
    widget.onSelectOnMap();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _model,
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: _compactSize,
        minChildSize: _minimalSize,
        maxChildSize: 1,
        snap: true,
        snapSizes: _snapSizes,
        shouldCloseOnMinExtent: false,
        builder: (context, scrollController) => Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  DraggableBottomSheetRegion(
                    controller: _sheetController,
                    snapSizes: _snapSizes,
                    child: const BottomSheetDragHandle(),
                  ),
                  if (_searching)
                    _searchHeader(context)
                  else
                    _homeHeader(context),
                  if (!_selectingFavorite &&
                      (_searching || _showHomeExtras)) ...[
                    _searchActions(context, showSelectOnMap: _searching),
                    if (_showQuickChoices)
                      Consumer<PlaceSearchScreenViewModel>(
                        builder: (context, model, _) => Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                          child: _favoriteButtons(context, model),
                        ),
                      ),
                    const Divider(height: 1),
                  ],
                  Expanded(
                    child: _searching
                        ? Consumer<PlaceSearchScreenViewModel>(
                            builder: (context, model, _) => PlaceSearchBody(
                              model: model,
                              scrollController: scrollController,
                              showSavedRoutes: true,
                              onSelected: _handleSelection,
                            ),
                          )
                        : _showQuickChoices
                            ? Consumer<PlaceSearchScreenViewModel>(
                                builder: (context, model, _) => PlaceSearchBody(
                                  model: model,
                                  showFavorites: false,
                                  scrollController: scrollController,
                                  onSelected: _handleSelection,
                                ),
                              )
                            : _favoriteShortcuts(context, scrollController),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeHeader(BuildContext context) {
    return DraggableBottomSheetRegion(
      controller: _sheetController,
      snapSizes: _snapSizes,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Material(
                key: const ValueKey('map-destination-search-field'),
                color: AppColors.uiPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _startDestinationSearch,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.isEnglish ? 'Destination?' : 'Wohin?',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.tr('Info'),
            onPressed: () => _runAction(widget.onShowInfo),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: context.l10n.settings,
            onPressed: () => _runAction(widget.onShowSettings),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }

  Widget _searchHeader(BuildContext context) {
    return DraggableBottomSheetRegion(
      controller: _sheetController,
      snapSizes: _snapSizes,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _query,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: _selectingFavorite
                        ? (context.l10n.isEnglish
                            ? 'Choose favorite'
                            : 'Favorit wählen')
                        : (context.l10n.isEnglish ? 'Destination?' : 'Wohin?'),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: _hasQuery
                        ? IconButton(
                            key: const ValueKey('destination-query-clear'),
                            tooltip: context.l10n.tr('Eingabe löschen'),
                            onPressed: _clearQuery,
                            icon: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(
                                dimension: 22,
                                child: Icon(Icons.close, size: 15),
                              ),
                            ),
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.search,
                  maxLines: 1,
                  onChanged: _previewSearch,
                  onSubmitted: _model.startSearch,
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.close,
              onPressed: _closeSearch,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchActions(
    BuildContext context, {
    required bool showSelectOnMap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 7),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => _runAction(widget.onPlanRoute),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.uiPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              icon: const Icon(Icons.route, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  context.l10n.isEnglish ? 'Plan route' : 'Route planen',
                  maxLines: 1,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          if (showSelectOnMap) ...[
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                onPressed: _selectOnMap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.uiPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    context.l10n.tr('Auf Karte wählen'),
                    maxLines: 1,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(width: 8),
            const Spacer(),
          ],
        ],
      ),
    );
  }

  Widget _favoriteShortcuts(
    BuildContext context,
    ScrollController scrollController,
  ) {
    return Consumer<PlaceSearchScreenViewModel>(
      builder: (context, model, _) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          children: [_favoriteButtons(context, model)],
        );
      },
    );
  }

  Widget _favoriteButtons(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    final favorites = model.favoriteItems.take(3).toList();
    if (favorites.isNotEmpty) {
      return Row(
        children: [
          for (var index = 0; index < favorites.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            Expanded(
              child: FilledButton(
                style: AppButtonStyles.secondary(context).merge(
                  FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                onPressed: () =>
                    _runAction(() => widget.onSelected(favorites[index])),
                child: Text(
                  _favoriteName(favorites[index]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      );
    }
    if (!model.favoritesLoaded) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: _startFavoriteSelection,
        icon: const Icon(Icons.star_outline),
        label: Text(
          context.l10n.isEnglish ? 'Choose favorite' : 'Favorit wählen',
        ),
      ),
    );
  }
}
