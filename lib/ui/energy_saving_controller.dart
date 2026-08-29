import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/common/logger_setup.dart';

abstract interface class BatteryStatusProvider {
  Future<int> get batteryLevel;
  Stream<void> get stateChanges;
}

class DeviceBatteryStatusProvider implements BatteryStatusProvider {
  DeviceBatteryStatusProvider({Battery? battery})
      : _battery = battery ?? Battery();

  final Battery _battery;

  @override
  Future<int> get batteryLevel => _battery.batteryLevel;

  @override
  Stream<void> get stateChanges => _battery.onBatteryStateChanged.map((_) {});
}

class EnergySavingController extends ChangeNotifier
    with WidgetsBindingObserver {
  EnergySavingController({
    SettingsStore? store,
    BatteryStatusProvider? battery,
    Duration pollInterval = const Duration(minutes: 1),
  })  : _store = store ?? settingsStore,
        _battery = battery ?? DeviceBatteryStatusProvider(),
        _pollInterval = pollInterval {
    WidgetsBinding.instance.addObserver(this);
  }

  static const automaticThresholdPercent = 20;

  final SettingsStore _store;
  final BatteryStatusProvider _battery;
  final Duration _pollInterval;
  Timer? _pollTimer;
  StreamSubscription<void>? _stateSubscription;
  bool _manualEnabled = false;
  bool _automaticEnabled = false;
  int? _batteryLevel;
  bool _started = false;

  bool get manualEnabled => _manualEnabled;
  bool get automaticEnabled => _automaticEnabled;
  bool get effectiveEnabled => _manualEnabled || _automaticEnabled;
  int? get batteryLevel => _batteryLevel;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final data = await _store.load();
    _manualEnabled = data.energySavingEnabled;
    notifyListeners();
    _stateSubscription = _battery.stateChanges.listen(
      (_) => unawaited(refreshBatteryLevel()),
      onError: (Object error, StackTrace stackTrace) => log.w(
        'Battery state monitoring failed',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(refreshBatteryLevel()),
    );
    // Battery plugins are optional platform-channel work and must not delay
    // the critical map startup path.
    unawaited(refreshBatteryLevel());
  }

  Future<void> setManualEnabled(bool enabled) async {
    if (_manualEnabled == enabled) return;
    _manualEnabled = enabled;
    notifyListeners();
    await _store.saveEnergySavingEnabled(enabled);
  }

  Future<void> refreshBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (level < 0 || level > 100) {
        log.w('Ignoring invalid battery level: $level');
        return;
      }
      final automatic = level <= automaticThresholdPercent;
      if (_batteryLevel == level && _automaticEnabled == automatic) return;
      _batteryLevel = level;
      _automaticEnabled = automatic;
      notifyListeners();
    } catch (error, stackTrace) {
      log.w(
        'Reading battery level failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshBatteryLevel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }
}
