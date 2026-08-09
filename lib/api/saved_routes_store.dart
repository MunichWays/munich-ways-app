import 'dart:convert';
import 'dart:io';

import 'package:munich_ways/model/saved_route.dart';
import 'package:path_provider/path_provider.dart';

var savedRoutesStore = SavedRoutesStore();

class SavedRoutesStore {
  static const maxEntries = 25;
  static const _fileName = 'savedRoutes.json';

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<List<SavedRoute>> load() async {
    final file = await _file();
    if (!file.existsSync()) return [];
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return (json['routes'] as List<dynamic>? ?? const [])
        .map((entry) => SavedRoute.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> store(List<SavedRoute> routes) async {
    final file = await _file();
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'routes': routes.map((route) => route.toJson()).toList(),
    }));
  }

  Future<void> add(SavedRoute route) async {
    final routes = await load();
    routes.removeWhere((saved) => saved.name == route.name);
    routes.insert(0, route);
    await store(routes.take(maxEntries).toList());
  }
}
