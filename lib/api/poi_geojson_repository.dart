import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:munich_ways/common/logger_setup.dart';

class PoiGeoJsonRepository {
  PoiGeoJsonRepository({BaseCacheManager? cacheManager})
      : _cacheManager = cacheManager ?? _poiCacheManager;

  static const drinkingWaterUrl =
      'https://www.munichways.de/App/poi/drinking_water.geojson';
  static const publicToiletsUrl =
      'https://www.munichways.de/App/poi/public_toilets.geojson';
  static const bicycleRepairStationsUrl =
      'https://www.munichways.de/App/poi/bicycle_repair_stations.geojson';

  static final CacheManager _poiCacheManager = CacheManager(
    Config(
      'munichwaysPoiGeoJson',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 12,
    ),
  );

  final BaseCacheManager _cacheManager;

  /// Removes the cached POIs so the next update stream downloads fresh data.
  Future<void> removeCache(String url) => _cacheManager.removeFile(url);

  /// Emits cached POIs immediately, then a refreshed file when the weekly
  /// cache entry is stale. Download and parsing never participate in app start.
  Stream<Map<String, dynamic>> updates(String url, String description) async* {
    await for (final response in _cacheManager.getFileStream(
      url,
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
          'Loading $description POIs failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Stream<Map<String, dynamic>> drinkingWaterUpdates() =>
      updates(drinkingWaterUrl, 'drinking-water');

  Stream<Map<String, dynamic>> publicToiletsUpdates() =>
      updates(publicToiletsUrl, 'public-toilet');

  Stream<Map<String, dynamic>> bicycleRepairStationsUpdates() =>
      updates(bicycleRepairStationsUrl, 'bicycle-repair-station');
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
