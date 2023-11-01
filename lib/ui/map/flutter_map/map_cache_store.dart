import 'dart:io';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:path_provider/path_provider.dart';

class MapCacheStore {
  static CacheStore? _cacheStore = null;

  Future<CacheStore> getMapCacheStore() async {
    if (_cacheStore != null) {
      return Future.value(_cacheStore);
    }
    _cacheStore = FileCacheStore(await _getMapCachePath());
    return Future.value(_cacheStore);
  }

  Future<String> _getMapCachePath() async {
    final tempDirForCaches = await getTemporaryDirectory();
    return '${tempDirForCaches.path}${Platform.pathSeparator}MapTiles';
  }

  Future<String> getStats() async {
    CacheStore cacheStore = await getMapCacheStore();
    var path = await _getMapCachePath();

    log.d("cache Path: $path");
    int fileNum = 0;
    int totalSize = 0;
    var dir = Directory(path);
    try {
      if (dir.existsSync()) {
        dir
            .listSync(recursive: true, followLinks: false)
            .forEach((FileSystemEntity entity) {
          if (entity is File) {
            log.d("file ${entity.path}");
            fileNum++;
            totalSize += entity.lengthSync();
          }
        });
      }
    } catch (e) {
      print(e.toString());
    }
    log.d('FileNum: $fileNum, totalSize: ${totalSize / 1024} KB');

    var list = await cacheStore.getFromPath(RegExp('https:'));
    for (var element in list) {
      log.d(
          "${element.url} ${element.expires?.toIso8601String()} ${element.maxStale?.toIso8601String()}");
    }
    return "Gesamt: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB";
  }

  Future<void> emptyCache() async {
    CacheStore cacheStore = await getMapCacheStore();
    await cacheStore.clean(
        priorityOrBelow: CachePriority.high, staleOnly: false);
  }
}
