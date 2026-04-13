import 'package:flutter/material.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/ui/map/search_location/search_app_bar.dart';
import 'package:munich_ways/ui/map/search_location/search_location_body.dart';
import 'package:munich_ways/ui/map/search_location/search_location_screen_model.dart';
import 'package:provider/provider.dart';

class SearchLocationScreen extends StatefulWidget {
  const SearchLocationScreen({super.key});

  @override
  State<SearchLocationScreen> createState() => _SearchLocationScreenState();
}

class _SearchLocationScreenState extends State<SearchLocationScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SearchLocationScreenViewModel>(
      create: (BuildContext context) {
        return SearchLocationScreenViewModel(
          recentSearchesRepo: recentSearchesRepo,
        );
      },
      child: Consumer<SearchLocationScreenViewModel>(
        builder: (context, model, child) {
          return Scaffold(
            appBar: SearchAppBar(
              onSearch: (String query) {
                model.startSearch(query);
              },
            ),
            body: SearchLocationBody(model: model),
          );
        },
      ),
    );
  }
}
