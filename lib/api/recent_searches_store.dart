import 'dart:convert';
import 'dart:io';

import 'package:munich_ways/model/place.dart';
import 'package:path_provider/path_provider.dart';

var recentSearchesRepo = RecentSearchesStore();
var favoritePlacesRepo = RecentSearchesStore(fileName: "favoritePlaces.json");

class RecentSearchesStore {
  static const maxEntries = 25;
  RecentSearchesStore({String fileName = "recentSearches.json"})
      : _fileName = fileName;

  final String _fileName;

  Future<File> _getJsonFile() async {
    Directory directory = await getApplicationSupportDirectory();
    return File("${directory.path}/$_fileName");
  }

  Future<List<Place>> load() async {
    File file = await _getJsonFile();
    if (!file.existsSync()) {
      await store([]);
      return [];
    }
    String json = await file.readAsString();
    var recentSearchesFile = RecentSearchesFile.fromJson(jsonDecode(json));
    return recentSearchesFile.recentSearches;
  }

  Future<void> store(List<Place> places) async {
    File file = await _getJsonFile();
    await file.create(recursive: true);
    String json = jsonEncode(RecentSearchesFile(places));
    file.writeAsString(json);
  }

  Future<void> add(
    Place place, {
    int maxEntries = RecentSearchesStore.maxEntries,
  }) async {
    final places = await load();
    places.removeWhere(
      (entry) =>
          entry.displayName == place.displayName ||
          (entry.latLng.latitude == place.latLng.latitude &&
              entry.latLng.longitude == place.latLng.longitude),
    );
    places.insert(0, place);
    await store(places.take(maxEntries).toList());
  }
}

class RecentSearchesFile {
  List<Place> recentSearches;

  RecentSearchesFile(this.recentSearches);

  Map<String, dynamic> toJson() => {'recentSearches': recentSearches};

  RecentSearchesFile.fromJson(Map<String, dynamic> json)
      : recentSearches = (json['recentSearches'] as List)
            .map((e) => Place.fromJson(e))
            .toList();
}
