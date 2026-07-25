import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:munich_ways/ui/place_search/place_search_body.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';
import 'package:provider/provider.dart';

Future<Object?> showPlaceSearchSheet(
  BuildContext context, {
  LatLng? searchCenter,
}) {
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ChangeNotifierProvider<PlaceSearchScreenViewModel>(
      create: (_) => PlaceSearchScreenViewModel(
        recentSearchesRepo: recentSearchesRepo,
        searchCenter: searchCenter,
      ),
      child: const _PlaceSearchSheet(),
    ),
  );
}

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet();

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final TextEditingController _query = TextEditingController();
  Timer? _searchDebounce;
  bool _hasQuery = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
    return Padding(
      padding: EdgeInsets.only(
        top: bottomSheetTopPadding(context),
        bottom: viewInsetsBottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: bottomSheetMaxHeight(context),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: bottomSheetDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: context.l10n.tr('Zurück zur Karte'),
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _query,
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
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Consumer<PlaceSearchScreenViewModel>(
                    builder: (context, model, _) {
                      return PlaceSearchBody(model: model);
                    },
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
