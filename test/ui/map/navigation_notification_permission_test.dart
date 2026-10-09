import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/navigation_notification_permission.dart';

import '../../support/wakelock_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.munichways.app/notification_permission');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late NavigationNotificationPermission permission;
  late MapScreenViewModel model;
  late _MemorySettingsStore store;
  late List<String> calls;
  var granted = false;
  bool? requestResult = true;
  var proceed = true;
  String? failingMethod;
  String? blockedStep;
  Completer<void>? gate;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    stubWakelock();
    permission = NavigationNotificationPermission();
    store = _MemorySettingsStore();
    model = MapScreenViewModel(store: store);
    await Future<void>.delayed(Duration.zero);
    model.locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();
    calls = [];
    granted = false;
    requestResult = true;
    proceed = true;
    failingMethod = null;
    blockedStep = null;
    gate = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (blockedStep == call.method) await gate!.future;
      if (failingMethod == call.method) {
        throw PlatformException(code: 'temporarily_unavailable');
      }
      if (call.method == 'isGranted') return granted;
      if (call.method == 'request') {
        granted = requestResult == true;
        return requestResult;
      }
      throw MissingPluginException();
    });
  });

  tearDown(() {
    model.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> request({bool Function()? isCurrent}) => permission.request(
        explain: () async {
          calls.add('explain');
          if (blockedStep == 'explain') await gate!.future;
          return proceed;
        },
        isCurrent: isCurrent ?? () => model.navigationStarted,
        onGranted: () => model.setVoiceGuidanceEnabled(true),
      );

  test('new grant enables and persists speech without changing navigation',
      () async {
    expect(model.voiceGuidanceEnabled, isFalse);
    await request();
    expect(calls, ['isGranted', 'explain', 'request']);
    expect(model.voiceGuidanceEnabled, isTrue);
    expect(store.data.voiceGuidanceEnabled, isTrue);
    expect(store.voiceWrites, [true]);
    expect(model.navigationStarted, isTrue);
    expect(model.locationState, LocationState.FOLLOW_AND_ROTATE_MAP);

    // A later navigation start must respect a deliberately muted speaker.
    model.setVoiceGuidanceEnabled(false);
    calls.clear();
    await request();
    expect(calls, ['isGranted']);
    expect(model.voiceGuidanceEnabled, isFalse);
    expect(store.voiceWrites, [true, false]);
  });

  test('already granted notifications preserve a muted speaker', () async {
    granted = true;
    await request();
    expect(calls, ['isGranted']);
    expect(model.voiceGuidanceEnabled, isFalse);
    expect(store.voiceWrites, isEmpty);
  });

  test('Not now does not request native permission or enable speech', () async {
    proceed = false;
    await request();
    expect(calls, ['isGranted', 'explain']);
    expect(model.voiceGuidanceEnabled, isFalse);
    expect(store.voiceWrites, isEmpty);
  });

  for (final result in [false, null]) {
    test('denied or dismissed permission ($result) can recover on retry',
        () async {
      requestResult = result;
      await request();
      expect(model.voiceGuidanceEnabled, isFalse);
      expect(store.voiceWrites, isEmpty);
      expect(model.navigationStarted, isTrue);

      requestResult = true;
      calls.clear();
      await request();
      expect(calls, ['isGranted', 'request']);
      expect(model.voiceGuidanceEnabled, isTrue);
      expect(store.voiceWrites, [true]);
    });
  }

  for (final method in ['isGranted', 'request']) {
    test('platform error at $method preserves navigation and allows retry',
        () async {
      failingMethod = method;
      await request();
      expect(model.navigationStarted, isTrue);
      expect(model.voiceGuidanceEnabled, isFalse);
      expect(store.voiceWrites, isEmpty);

      failingMethod = null;
      await request();
      expect(model.voiceGuidanceEnabled, isTrue);
      expect(store.voiceWrites, [true]);
    });
  }

  for (final step in ['isGranted', 'explain', 'request']) {
    test('ending navigation while awaiting $step prevents late activation',
        () async {
      blockedStep = step;
      gate = Completer<void>();
      final pending = request();
      await Future<void>.delayed(Duration.zero);
      expect(calls.last, step);
      model.clearDestination();
      gate!.complete();
      await pending;
      expect(model.voiceGuidanceEnabled, isFalse);
      expect(store.voiceWrites, isEmpty);
      expect(calls.last, step);
    });
  }

  test('an obsolete screen or route never requests permission', () async {
    await request(isCurrent: () => false);
    expect(calls, isEmpty);
    expect(store.voiceWrites, isEmpty);
  });

  test('iOS retains its existing speech setting without Android calls',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await request();
    expect(calls, isEmpty);
    expect(model.voiceGuidanceEnabled, isFalse);
    expect(store.voiceWrites, isEmpty);
  });
}

class _MemorySettingsStore extends SettingsStore {
  SettingsData data = SettingsData.defaults;
  final voiceWrites = <bool>[];

  @override
  Future<SettingsData> load() async => data;

  @override
  Future<void> saveVoiceGuidanceEnabled(bool enabled) async {
    voiceWrites.add(enabled);
    data = data.copyWith(voiceGuidanceEnabled: enabled);
  }
}
