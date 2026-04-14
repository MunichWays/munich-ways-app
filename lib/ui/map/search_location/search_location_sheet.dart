import 'package:flutter/material.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:munich_ways/ui/map/search_location/search_location_body.dart';
import 'package:munich_ways/ui/map/search_location/search_location_screen_model.dart';
import 'package:provider/provider.dart';

Future<Place?> showSearchLocationSheet(BuildContext context) {
  return showModalBottomSheet<Place?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ChangeNotifierProvider<SearchLocationScreenViewModel>(
      create: (_) => SearchLocationScreenViewModel(
        recentSearchesRepo: recentSearchesRepo,
      ),
      child: const _SearchLocationSheet(),
    ),
  );
}

class _SearchLocationSheet extends StatefulWidget {
  const _SearchLocationSheet();

  @override
  State<_SearchLocationSheet> createState() => _SearchLocationSheetState();
}

class _SearchLocationSheetState extends State<_SearchLocationSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _submitSearch() {
    context.read<SearchLocationScreenViewModel>().startSearch(_query.text);
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
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _query,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Suche Ziel …',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 18),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _submitSearch(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Suchen',
                        icon: const Icon(Icons.search),
                        onPressed: _submitSearch,
                      ),
                      IconButton(
                        tooltip: 'Schließen',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Consumer<SearchLocationScreenViewModel>(
                    builder: (context, model, _) {
                      return SearchLocationBody(model: model);
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
