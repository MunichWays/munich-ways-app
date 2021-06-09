import 'package:flutter/material.dart';
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
        return SearchLocationScreenViewModel();
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
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            Icons.error_outline,
            size: 48,
          ),
          SizedBox(
            height: 16,
          ),
          Text(
            model.errorMsg,
            style: TextStyle(fontSize: 18.0),
            textAlign: TextAlign.center,
          )
        ])),
      );
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
                title: Text(model.places.elementAt(index).displayName),
                trailing: Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.pop(context, model.places.elementAt(index));
                },
              );
            }
          });
    } else {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            Icons.search,
            size: 48,
          ),
          SizedBox(
            height: 16,
          ),
          Text(
            "Keine Ergebnisse vorhanden.\nBitte gebe einen Suchbegriff z.B. eine Straße in München ein..",
            style: TextStyle(fontSize: 18.0),
            textAlign: TextAlign.center,
          )
        ])),
      );
    }
  }
}
