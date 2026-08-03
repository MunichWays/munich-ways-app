import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

void main() {
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
