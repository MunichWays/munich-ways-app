import 'dart:convert';
import 'dart:io';

import 'package:munich_ways/model/place.dart';
import 'package:path_provider/path_provider.dart';

var recentSearchesRepo = RecentSearchesStore();

class RecentSearchesStore {
  String _fileName = "recentSearches.json";

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
