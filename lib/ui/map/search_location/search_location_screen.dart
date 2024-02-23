import 'package:flutter/material.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/search_location/search_app_bar.dart';
import 'package:munich_ways/ui/map/search_location/search_location_screen_model.dart';
import 'package:provider/provider.dart';

class SearchLocationScreen extends StatefulWidget {
  const SearchLocationScreen({key}) : super(key: key);

  @override
  _SearchLocationScreenState createState() => _SearchLocationScreenState();
}

class _SearchLocationScreenState extends State<SearchLocationScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SearchLocationScreenViewModel>(
      create: (BuildContext context) {
        return SearchLocationScreenViewModel(
            recentSearchesRepo: recentSearchesRepo);
      },
      child: Consumer<SearchLocationScreenViewModel>(
        builder: (context, model, child) {
          return Scaffold(
            appBar: SearchAppBar(onSearch: (String query) {
              model.startSearch(query);
            }),
            body: _buildBody(model),
          );
        },
      ),
    );
  }

  Widget _buildBody(SearchLocationScreenViewModel model) {
    if (model.loading) {
      return Center(
        child: SizedBox(
          width: 32.0,
          height: 32.0,
          child: CircularProgressIndicator(
            strokeWidth: 3,
          ),
        ),
      );
    } else if (model.errorMsg != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            model.errorMsg!,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        RecentSearchesSection(
            onClearAllRecentSearches: () {
              model.clearAllRecentSearches();
            },
            recentSearches: model.recentSearches)
      ]);
    } else if (model.places.length > 0) {
      return ListView.separated(
          separatorBuilder: (context, index) {
            return Divider();
          },
          itemCount: model.places.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == model.places.length) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  "Data © OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            } else {
              return ListTile(
                title: Text(model.places.elementAt(index).displayName!),
                trailing: Icon(Icons.arrow_forward),
                onTap: () {
                  var place = model.places.elementAt(index);
                  model.addToRecentSearches(place);
                  Navigator.pop(context, place);
                },
              );
            }
          });
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Text(
              model.isFirstSearch
                  ? "Bitte gebe einen Suchbegriff ein z.B. eine Straße in München. Betätige dann den Suchen Button."
                  : "Keine Ergebnisse vorhanden.\nBitte überprüfe den Suchbegriff.",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          RecentSearchesSection(
              recentSearches: model.recentSearches,
              onClearAllRecentSearches: () {
                model.clearAllRecentSearches();
              })
        ],
      );
    }
  }
}

class RecentSearchesSection extends StatelessWidget {
  final List<Place> recentSearches;
  final Function onClearAllRecentSearches;

  const RecentSearchesSection(
      {Key? key,
      required this.onClearAllRecentSearches,
      required this.recentSearches});

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) {
      return Container();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text(
                "Letzte Ziele",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () {
                this.onClearAllRecentSearches();
              },
              child: Text("Suchverlauf löschen"),
            ),
          ],
        ),
        for (var recentSearch in recentSearches)
          Column(
            children: [
              Divider(height: 1),
              ListTile(
                title: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                    child: Text(recentSearch.displayName!)),
                trailing: Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.pop(context, recentSearch);
                },
              ),
            ],
          ),
      ],
    );
  }
}
