import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:munich_ways/api/munichways/geojson_converter.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/polyline.dart';

import '../api_exception.dart';

class MunichwaysApi {
  final String _radlvorrangnetzUrl =
      "https://www.munichways.de/App/radlvorrangnetz_app_V07.geojson";

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
      final polylines = await compute(_parseGeojson, contents);
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

  /// Emits cached ratings immediately, then a refreshed file when the cached
  /// response is stale. This keeps subsequent starts independent of the network.
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
  }) async* {
    final responses = StreamIterator(
      DefaultCacheManager().getFileStream(
        _radlvorrangnetzUrl,
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

  /// Removes only the ratings file. Other cached app resources stay intact.
  Future<void> removeRatingsCache() {
    return DefaultCacheManager().removeFile(_radlvorrangnetzUrl);
  }
}

Set<MPolyline> _parseGeojson(String contents) {
  return GeojsonConverter().getPolylines(geojson: json.decode(contents));
}
