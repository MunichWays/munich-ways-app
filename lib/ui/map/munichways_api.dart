import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/ui/map/geojson_converter.dart';

class MunichwaysApi {
  final String _radlvorrangnetzUrl =
      "https://www.munichways.com/App/radlvorrangnetz_app_V04.geojson";

  GeojsonConverter _converter = GeojsonConverter();

  Future<Set<MPolyline>> getRadlvorrangnetz() async {
    if (await DefaultCacheManager().getFileFromCache(_radlvorrangnetzUrl) !=
        null) {
      log.d("cached");
    } else {
      log.d("not cached");
    }

    File geojsonFile =
        await DefaultCacheManager().getSingleFile(_radlvorrangnetzUrl);
    if (geojsonFile == null) {
      throw ApiException("Could not load geojson from server.");
    }

    try {
      return _converter.getPolylines(
          geojson: json.decode(await geojsonFile.readAsString()));
    } catch (e) {
      throw ApiException(e);
    }
  }

  Future<void> emptyCache() {
    return DefaultCacheManager().emptyCache();
  }
}

class ApiException implements Exception {
  final String message;

  ApiException([this.message = ""]);

  String toString() => "ApiException: $message";
}
