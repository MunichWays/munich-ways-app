import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/polyline.dart';
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
}

class _MemorySettingsStore extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}
