import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:munich_ways/ui/place_search/place_search_body.dart';
import 'package:munich_ways/ui/place_search/place_search_result.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';
import 'package:provider/provider.dart';

Future<Object?> showPlaceSearchSheet(
  BuildContext context, {
  LatLng? searchCenter,
  bool showRoutePlannerOption = true,
}) {
  final sheetController = DraggableScrollableController();
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ChangeNotifierProvider<PlaceSearchScreenViewModel>(
      create: (_) => PlaceSearchScreenViewModel(
        recentSearchesRepo: recentSearchesRepo,
        searchCenter: searchCenter,
      ),
      child: DraggableScrollableSheet(
        controller: sheetController,
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.28,
        maxChildSize: 1,
        shouldCloseOnMinExtent: false,
        snap: true,
        snapSizes: const [0.28, 0.55, 1],
        builder: (context, scrollController) => SizedBox.expand(
          child: _PlaceSearchSheet(
            showRoutePlannerOption: showRoutePlannerOption,
            scrollController: scrollController,
            sheetController: sheetController,
          ),
        ),
      ),
    ),
  ).whenComplete(sheetController.dispose);
}

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({
    required this.showRoutePlannerOption,
    required this.scrollController,
    required this.sheetController,
  });

  final bool showRoutePlannerOption;
  final ScrollController scrollController;
  final DraggableScrollableController sheetController;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _hasQuery = false;
  bool _expandedForKeyboard = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocus);
  }

  void _handleSearchFocus() {
    if (!_searchFocusNode.hasFocus) {
      _expandedForKeyboard = false;
      return;
    }
    if (_expandedForKeyboard) return;
    _expandedForKeyboard = true;
    _expandForKeyboard();
  }

  void _expandForKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_searchFocusNode.hasFocus) return;
      if (!widget.sheetController.isAttached) {
        _expandForKeyboard();
        return;
      }
      widget.sheetController.animateTo(
        1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode
      ..removeListener(_handleSearchFocus)
      ..dispose();
    _query.dispose();
    super.dispose();
  }

  void _submitSearch() {
    _searchDebounce?.cancel();
    context.read<PlaceSearchScreenViewModel>().startSearch(_query.text);
  }

  void _previewSearch(String query) {
    final hasQuery = query.isNotEmpty;
    if (hasQuery != _hasQuery) {
      setState(() => _hasQuery = hasQuery);
    }
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      context.read<PlaceSearchScreenViewModel>().resetSearch();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        context.read<PlaceSearchScreenViewModel>().startSearch(query);
      }
    });
  }

  void _clearQuery() {
    _searchDebounce?.cancel();
    _query.clear();
    setState(() => _hasQuery = false);
    context.read<PlaceSearchScreenViewModel>().resetSearch();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          top: bottomSheetTopPadding(context),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: bottomSheetMaxHeight(context),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: bottomSheetDecoration(context),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DraggableBottomSheetRegion(
                    controller: widget.sheetController,
                    onDismiss: () => Navigator.of(context).pop(),
                    child: const BottomSheetDragHandle(),
                  ),
                  DraggableBottomSheetRegion(
                    controller: widget.sheetController,
                    onDismiss: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 4, 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _query,
                              focusNode: _searchFocusNode,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: context.l10n.tr('Ziel suchen'),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                              textInputAction: TextInputAction.done,
                              onChanged: _previewSearch,
                              onSubmitted: (_) => _submitSearch(),
                            ),
                          ),
                          if (_hasQuery)
                            IconButton(
                              tooltip: context.l10n.tr('Eingabe löschen'),
                              icon: const Icon(Icons.close),
                              onPressed: _clearQuery,
                            ),
                          IconButton(
                            tooltip: context.l10n.close,
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Row(
                      children: [
                        if (widget.showRoutePlannerOption) ...[
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(
                                PlaceSearchSheetResult.planRoute,
                              ),
                              icon: const Icon(Icons.route, size: 20),
                              label: Text(
                                context.l10n.isEnglish
                                    ? 'Plan route'
                                    : 'Route planen',
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(
                              PlaceSearchSheetResult.selectOnMap,
                            ),
                            icon: const Icon(
                              Icons.add_location_alt_outlined,
                              size: 20,
                            ),
                            label: Text(
                              context.l10n.tr('Auf Karte wählen'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: viewInsetsBottom),
                      child: Consumer<PlaceSearchScreenViewModel>(
                        builder: (context, model, _) {
                          return PlaceSearchBody(
                            model: model,
                            showSavedRoutes: widget.showRoutePlannerOption,
                            scrollController: widget.scrollController,
                          );
                        },
                      ),
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
