import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/model/route_transfer.dart';
import 'package:path_provider/path_provider.dart';

var savedRoutesStore = SavedRoutesStore();

class SavedRoutesStore {
  static const maxEntries = 25;
  static const _fileName = 'savedRoutes.json';
  final Directory? directory;
  Future<void> _writes = Future.value();
  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  SavedRoutesStore({this.directory});
  Future<Directory> _directory() async =>
      directory ?? await getApplicationSupportDirectory();
  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');
  Future<File> _snapshot(String id) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id))
      throw const FormatException('Invalid snapshot ID');
    return File('${(await _directory()).path}/route-snapshots/$id.json');
  }

  Future<List<SavedRoute>> load() async {
    final file = await _file();
    if (!file.existsSync()) return [];
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return (json['routes'] as List<dynamic>? ?? const [])
        .map((entry) => SavedRoute.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Read only the selected snapshot; listing saved routes stays lightweight.
  Future<SavedRoute> loadSnapshot(SavedRoute route) async {
    if (route.snapshot != null || route.snapshotId == null) return route;
    final file = await _snapshot(route.snapshotId!);
    if (await file.length() > RouteTransfer.maxBytes)
      throw const FormatException('Snapshot too large');
    final transfer = RouteTransfer.fromStorageJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    return route.copyWith(snapshot: transfer.renamed(route.name));
  }

  Future<void> _atomicWrite(File file, String body) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(body, flush: true);
    await temp.rename(file.path);
  }

  Future<void> store(List<SavedRoute> routes) =>
      _serialize(() => _store(routes));
  Future<void> _store(List<SavedRoute> routes) async {
    await _atomicWrite(await _file(),
        jsonEncode({'routes': routes.map((route) => route.toJson()).toList()}));
    // Delete unreferenced immutable snapshots only after the index was saved.
    final folder = Directory('${(await _directory()).path}/route-snapshots');
    if (!await folder.exists()) return;
    final ids = routes.map((r) => r.snapshotId).whereType<String>().toSet();
    await for (final entry in folder.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File &&
          RegExp(r'^[a-f0-9]{32}\.json$').hasMatch(name) &&
          !ids.contains(name.substring(0, 32))) {
        try {
          await entry.delete();
        } catch (_) {/* A later store can retry cleanup. */}
      }
    }
  }

  Future<SavedRoute> _persistSnapshot(SavedRoute route) async {
    if (route.snapshot == null) return route;
    if (route.snapshotId != null)
      return route.copyWith(snapshot: route.snapshot!.renamed(route.name));
    final random = Random.secure();
    final id = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    final snapshot = route.snapshot!.renamed(route.name);
    await _atomicWrite(
        await _snapshot(id), jsonEncode(snapshot.toStorageJson()));
    return route.copyWith(snapshotId: id, snapshot: snapshot);
  }

  Future<SavedRoute> addImported(SavedRoute route) =>
      _serialize(() => _addImported(route));
  Future<SavedRoute> _addImported(SavedRoute route) async {
    final routes = await load();
    if (routes.length >= maxEntries)
      throw const FileSystemException(
          'Route storage is full; remove a saved route first');
    final saved = await _persistSnapshot(route);
    routes.insert(
        0, saved); // Imports never replace another route with the same name.
    await _store(routes);
    return saved;
  }

  Future<void> add(SavedRoute route) => _serialize(() => _add(route));
  Future<void> _add(SavedRoute route) async {
    final routes = await load();
    if (route.snapshot != null && route.snapshotId == null) {
      await _addImported(route);
      return;
    }
    if (route.snapshotId != null) {
      routes.removeWhere((saved) => saved.snapshotId == route.snapshotId);
      route = await _persistSnapshot(route);
    } else {
      routes.removeWhere(
          (saved) => saved.snapshotId == null && saved.name == route.name);
    }
    routes.insert(0, route);
    await _store(routes.take(maxEntries).toList());
  }
}
