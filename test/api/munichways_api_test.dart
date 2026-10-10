import 'dart:async';
import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/model/polyline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled Munich RadlVorrang network', () async {
    final polylines = await MunichwaysApi().getBundledRadlVorrangnetz();

    expect(polylines, isNotEmpty);
    expect(polylines.every((polyline) => polyline.isRadlVorrangNetz), isTrue);
    expect(
      polylines.every((polyline) => polyline.details?.farbe != null),
      isTrue,
    );
  });

  test('does not apply the network timeout to bundled ratings', () async {
    final polylines = await _SlowBundledMunichwaysApi()
        .getRadlvorrangnetzUpdates(
          responseTimeout: const Duration(milliseconds: 1),
        )
        .first;

    expect(polylines, isEmpty);
  });

  FileInfo onlineFile() {
    final file = MemoryFileSystem().file('/ratings.geojson');
    file.writeAsStringSync(jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [11.5, 48.1],
              [11.6, 48.2]
            ]
          },
          'properties': {'osm_id': 42, 'color': 'green'},
        }
      ],
    }));
    return FileInfo(file, FileSource.Online, DateTime(2030),
        'https://example.test/ratings');
  }

  test('a slow progressing download can exceed the inactivity deadline',
      () async {
    final response = onlineFile();
    final api = _TinyBundledApi((url, forceRefresh) async* {
      for (var i = 1; i <= 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        yield DownloadProgress(url, 100, i * 10);
      }
      yield response;
    });
    final updates = await api
        .getRadlvorrangnetzUpdates(
          responseTimeout: const Duration(milliseconds: 80),
        )
        .toList();
    expect(updates, hasLength(2));
    expect(updates.last.single.details?.osmId, '42');
  });

  test('stalled download terminates, cancels subscription and can retry',
      () async {
    var cancelled = false;
    var requests = 0;
    final stalled = StreamController<FileResponse>(onCancel: () {
      cancelled = true;
    });
    addTearDown(stalled.close);
    final response = onlineFile();
    final api = _TinyBundledApi((url, forceRefresh) {
      requests++;
      return requests == 1 ? stalled.stream : Stream.value(response);
    });
    final received = <Set<MPolyline>>[];
    await expectLater(
        api
            .getRadlvorrangnetzUpdates(
              responseTimeout: const Duration(milliseconds: 30),
            )
            .forEach(received.add),
        throwsA(isA<TimeoutException>()));
    expect(received, hasLength(1));
    expect(cancelled, isTrue);
    final updates = await api
        .getRadlvorrangnetzUpdates(
          responseTimeout: const Duration(milliseconds: 80),
          forceRefresh: true,
        )
        .toList();
    expect(updates.last.single.details?.osmId, '42');
  });

  test('a corrupt cached file is removed and replaced without losing fallback',
      () async {
    final online = onlineFile();
    final broken = MemoryFileSystem().file('/broken.geojson');
    broken.writeAsStringSync('invalid JSON');
    final cached =
        FileInfo(broken, FileSource.Cache, DateTime(2030), online.originalUrl);
    var removed = 0;
    final api = _TinyBundledApi((url, forceRefresh) async* {
      yield cached;
      expect(broken.existsSync(), isFalse);
      yield online;
    }, removeCachedRatings: (url) async {
      removed++;
      await broken.delete();
    });
    final received = await api.getRadlvorrangnetzUpdates().toList();
    expect(removed, 1);
    expect(received, hasLength(2));
    expect(received.last.single.details?.osmId, '42');
  });

  test('empty online ratings never replace the local fallback', () async {
    final response = onlineFile();
    response.file
        .writeAsStringSync('{"type":"FeatureCollection","features":[]}');
    final api = _TinyBundledApi((url, forceRefresh) => Stream.value(response));
    final received = <Set<MPolyline>>[];
    await expectLater(api.getRadlvorrangnetzUpdates().forEach(received.add),
        throwsA(isA<Exception>()));
    expect(received, hasLength(1));
  });

  test('cached ratings survive failed online revalidation', () async {
    final online = onlineFile();
    final cached = FileInfo(
        online.file, FileSource.Cache, DateTime(2020), online.originalUrl);
    var refreshRequested = false;
    final api = _TinyBundledApi((url, forceRefresh) async* {
      refreshRequested = forceRefresh;
      yield cached;
      throw StateError('Network unavailable');
    });
    final received = <Set<MPolyline>>[];
    await expectLater(
        api.getRadlvorrangnetzUpdates(forceRefresh: true).forEach(received.add),
        throwsStateError);
    expect(refreshRequested, isTrue);
    expect(received, hasLength(2));
    expect(received.last.single.details?.osmId, '42');
    expect(cached.file.existsSync(), isTrue);
  });
}

class _SlowBundledMunichwaysApi extends MunichwaysApi {
  @override
  Future<Set<MPolyline>> getBundledRadlVorrangnetz() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return <MPolyline>{};
  }
}

class _TinyBundledApi extends MunichwaysApi {
  _TinyBundledApi(Stream<FileResponse> Function(String, bool) responses,
      {Future<void> Function(String)? removeCachedRatings})
      : super(
            ratingsResponses: responses,
            removeCachedRatings: removeCachedRatings);
  @override
  Future<Set<MPolyline>> getBundledRadlVorrangnetz() async => {};
}
