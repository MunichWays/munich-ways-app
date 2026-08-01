import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:munich_ways/api/munichways/geojson_converter.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';

import '../api_exception.dart';

class MunichwaysApi {
  static const _bundledRadlVorrangAsset =
      'assets/radlnetz/happy_bike_level_munich_RV.geojson';
  final String _happyBikeLevelUrl =
      "https://www.munichways.de/App/happy_bike_level_oberbayern.geojson";
  final String _detailsUrl =
      "https://www.munichways.de/App/IST_RadlVorrangNetz_MunichWays_V20.geojson";

  Future<Set<MPolyline>> _parse(File geojsonFile) async {
    final total = Stopwatch()..start();
    try {
      final read = Stopwatch()..start();
      final contents = await geojsonFile.readAsString();
      read.stop();
      log.d(
        'ratings file read: ${contents.length} chars in '
        '${read.elapsedMilliseconds} ms',
      );

      final parse = Stopwatch()..start();
      final polylines = await compute(_parseHappyBikeLevelGeojson, contents);
      parse.stop();
      total.stop();
      log.d(
        'ratings parsed: ${polylines.length} polylines in '
        '${parse.elapsedMilliseconds} ms '
        '(${total.elapsedMilliseconds} ms total)',
      );
      return polylines;
    } catch (e) {
      total.stop();
      log.e(
        'ratings parsing failed after ${total.elapsedMilliseconds} ms',
        error: e,
      );
      throw ApiException(e.toString());
    }
  }

  Future<Set<MPolyline>> getBundledRadlVorrangnetz() async {
    final contents = await rootBundle.loadString(_bundledRadlVorrangAsset);
    return compute(_parseHappyBikeLevelGeojson, contents);
  }

  /// Emits the bundled Munich RadlVorrang network first, followed by cached or
  /// downloaded ratings for all of Upper Bavaria.
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
  }) async* {
    try {
      final bundled = await getBundledRadlVorrangnetz();
      log.d('bundled RadlVorrang network loaded: ${bundled.length} polylines');
      yield bundled;
    } catch (e, st) {
      // A broken asset must not prevent the network-backed data from loading.
      log.e(
        'bundled RadlVorrang network load failed',
        error: e,
        stackTrace: st,
      );
    }

    final responses = StreamIterator(
      DefaultCacheManager().getFileStream(
        _happyBikeLevelUrl,
        withProgress: false,
      ),
    );
    try {
      while (await (responseTimeout == null
          ? responses.moveNext()
          : responses.moveNext().timeout(responseTimeout))) {
        final response = responses.current;
        if (response is FileInfo) {
          log.d("ratings valid till ${response.validTill.toIso8601String()}");
          // Parsing is deliberately outside the response timeout. A cached file
          // may take longer to decode on slower devices, but is still valid.
          yield await _parse(response.file);
        }
      }
    } finally {
      await responses.cancel();
    }
  }

  Future<Set<MPolyline>> getRadlvorrangnetz() =>
      getRadlvorrangnetzUpdates().first;

  Future<Map<String, StreetDetails>> getStreetDetails() async {
    final response = await DefaultCacheManager().getSingleFile(_detailsUrl);
    final contents = await response.readAsString();
    return compute(_parseV20Details, contents);
  }

  /// Removes only downloaded network data. The bundled fallback stays intact.
  Future<void> removeRatingsCache() async {
    await Future.wait([
      DefaultCacheManager().removeFile(_happyBikeLevelUrl),
      DefaultCacheManager().removeFile(_detailsUrl),
    ]);
  }
}

Set<MPolyline> _parseHappyBikeLevelGeojson(String contents) {
  return GeojsonConverter().getPolylines(
    geojson: json.decode(contents),
    happyBikeLevelFormat: true,
  );
}

Map<String, StreetDetails> _parseV20Details(String contents) {
  final geojson = json.decode(contents) as Map<String, dynamic>;
  final result = <String, StreetDetails>{};
  for (final feature in geojson['features'] as List<dynamic>) {
    final details = StreetDetails.fromV20Json(feature);
    final id = streetDetailsFeatureId(details);
    if (id != null) result[id] = details;
  }
  return result;
}
