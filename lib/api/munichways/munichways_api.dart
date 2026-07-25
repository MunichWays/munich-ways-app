import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:munich_ways/api/munichways/geojson_converter.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/polyline.dart';

import '../api_exception.dart';

class MunichwaysApi {
  final String _radlvorrangnetzUrl =
      "https://www.munichways.de/App/radlvorrangnetz_app_V07.geojson";

  GeojsonConverter _converter = GeojsonConverter();

  Future<Set<MPolyline>> _parse(File geojsonFile) async {
    try {
      return _converter.getPolylines(
          geojson: json.decode(await geojsonFile.readAsString()));
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  /// Emits cached ratings immediately, then a refreshed file when the cached
  /// response is stale. This keeps subsequent starts independent of the network.
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates() async* {
    await for (final response in DefaultCacheManager().getFileStream(
      _radlvorrangnetzUrl,
      withProgress: false,
    )) {
      if (response is FileInfo) {
        log.d("ratings valid till ${response.validTill.toIso8601String()}");
        yield await _parse(response.file);
      }
    }
  }

  Future<Set<MPolyline>> getRadlvorrangnetz() =>
      getRadlvorrangnetzUpdates().first;

  /// Removes only the ratings file. Other cached app resources stay intact.
  Future<void> removeRatingsCache() {
    return DefaultCacheManager().removeFile(_radlvorrangnetzUrl);
  }
}
