import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/map/map_screen.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

void main() {
  test('uses a direction arrow only for reliable movement heading', () {
    expect(
      hasReliableMovementHeading(
        accuracy: 5,
        heading: 90,
        headingAccuracy: 5,
        speed: 2,
      ),
      isTrue,
    );
    expect(
      hasReliableMovementHeading(
        accuracy: 5,
        heading: 90,
        headingAccuracy: 5,
        speed: 0,
      ),
      isFalse,
    );
    expect(
      hasReliableMovementHeading(
        accuracy: 80,
        heading: 90,
        headingAccuracy: 5,
        speed: 2,
      ),
      isFalse,
    );
  });

  test('accepts a coarse initial position but rejects unusable fixes', () {
    expect(
      isUsableMapPosition(
        latitude: 48.14,
        longitude: 11.57,
        accuracy: 250,
      ),
      isTrue,
    );
    expect(
      isUsableMapPosition(
        latitude: 48.14,
        longitude: 11.57,
        accuracy: 1001,
      ),
      isFalse,
    );
    expect(
      isUsableMapPosition(
        latitude: 91,
        longitude: 11.57,
        accuracy: 10,
      ),
      isFalse,
    );
  });

  test('uses only recent cached positions at startup', () {
    final now = DateTime(2026, 8, 29, 12);

    expect(
      isFreshCachedPosition(
        now.subtract(const Duration(minutes: 15)),
        now,
      ),
      isTrue,
    );
    expect(
      isFreshCachedPosition(
        now.subtract(const Duration(minutes: 16)),
        now,
      ),
      isFalse,
    );
    expect(
      isFreshCachedPosition(now.add(const Duration(seconds: 1)), now),
      isFalse,
    );
  });

  test('allows the optional initial network load longer in background',
      () async {
    final api = _RecordingMunichwaysApi();
    final model = MapScreenViewModel(
      store: _MemorySettingsStore(),
      munichwaysApi: api,
    );

    model.startInitialLoad();
    await Future<void>.delayed(Duration.zero);

    expect(api.responseTimeout, const Duration(seconds: 30));
  });

  test('finishes initial loading when ratings stream stalls offline', () async {
    final model = MapScreenViewModel(
      store: _MemorySettingsStore(),
      munichwaysApi: _StalledMunichwaysApi(),
    );

    final result = await model.refreshRadlnetze(
      requestTimeout: const Duration(milliseconds: 20),
    );

    expect(result, isFalse);
    expect(model.loading, isFalse);
    expect(model.initialLoadComplete, isTrue);
    expect(model.initialRatingsLoadFailed, isTrue);
  });

  test('offers retry when only the bundled fallback was loaded', () async {
    final model = MapScreenViewModel(
      store: _MemorySettingsStore(),
      munichwaysApi: _FallbackOnlyMunichwaysApi(),
    );

    final result = await model.refreshRadlnetze(
      requestTimeout: const Duration(milliseconds: 20),
    );

    expect(result, isFalse);
    expect(model.loading, isFalse);
    expect(model.initialRatingsLoadFailed, isTrue);
  });

  test('keeps retry available when reloading the full network fails', () async {
    final model = MapScreenViewModel(
      store: _MemorySettingsStore(),
      munichwaysApi: _ReloadFailureMunichwaysApi(),
    )..initialRatingsLoadFailed = true;

    final result = await model.reloadRadnetz();

    expect(result, isFalse);
    expect(model.loading, isFalse);
    expect(model.initialRatingsLoadFailed, isTrue);
  });
}

class _StalledMunichwaysApi extends MunichwaysApi {
  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
  }) =>
      StreamController<Set<MPolyline>>()
          .stream
          .timeout(responseTimeout ?? const Duration(seconds: 6));

  @override
  Future<Map<String, StreetDetails>> getStreetDetails() async => {};
}

class _RecordingMunichwaysApi extends MunichwaysApi {
  Duration? responseTimeout;

  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
  }) async* {
    this.responseTimeout = responseTimeout;
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails() async => {};
}

class _FallbackOnlyMunichwaysApi extends MunichwaysApi {
  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
  }) async* {
    yield <MPolyline>{};
    await Completer<void>().future.timeout(
          responseTimeout ?? const Duration(seconds: 6),
        );
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails() async => {};
}

class _ReloadFailureMunichwaysApi extends MunichwaysApi {
  @override
  Future<void> removeRatingsCache() async {}

  @override
  Stream<Set<MPolyline>> getRadlvorrangnetzUpdates({
    Duration? responseTimeout,
  }) async* {
    yield <MPolyline>{};
    throw TimeoutException('offline');
  }

  @override
  Future<Map<String, StreetDetails>> getStreetDetails() async => {};
}

class _MemorySettingsStore extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}
