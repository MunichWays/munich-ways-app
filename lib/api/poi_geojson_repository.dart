import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:munich_ways/common/logger_setup.dart';

class PoiGeoJsonRepository {
  PoiGeoJsonRepository({BaseCacheManager? cacheManager})
      : _cacheManager = cacheManager ?? _poiCacheManager;

  static const drinkingWaterUrl =
      'https://www.munichways.de/App/poi/drinking_water.geojson';

  static final CacheManager _poiCacheManager = CacheManager(
    Config(
      'munichwaysPoiGeoJson',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 12,
    ),
  );

  final BaseCacheManager _cacheManager;

  /// Removes the cached POIs so the next update stream downloads fresh data.
  Future<void> removeDrinkingWaterCache() =>
      _cacheManager.removeFile(drinkingWaterUrl);

  /// Emits cached POIs immediately, then a refreshed file when the weekly
  /// cache entry is stale. Download and parsing never participate in app start.
  Stream<Map<String, dynamic>> drinkingWaterUpdates() async* {
    await for (final response in _cacheManager.getFileStream(
      drinkingWaterUrl,
      withProgress: false,
    )) {
      if (response is! FileInfo) continue;
      try {
        final contents = await response.file.readAsString();
        yield await compute(parsePoiFeatureCollection, contents);
      } catch (error, stackTrace) {
        // Keep listening: a stale malformed file may still be followed by a
        // valid network response. Optional POIs must never affect the map.
        log.w(
          'Loading drinking-water POIs failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}

@visibleForTesting
Map<String, dynamic> parsePoiFeatureCollection(String contents) {
  final decoded = jsonDecode(contents);
  if (decoded is! Map<String, dynamic> ||
      decoded['type'] != 'FeatureCollection' ||
      decoded['features'] is! List) {
    throw const FormatException('Expected a GeoJSON FeatureCollection');
  }
  for (final feature in decoded['features'] as List<dynamic>) {
    if (feature is! Map<String, dynamic> ||
        feature['type'] != 'Feature' ||
        feature['geometry'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid GeoJSON feature');
    }
  }
  return decoded;
}
