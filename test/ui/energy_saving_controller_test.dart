import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/ui/app_theme_controller.dart';
import 'package:munich_ways/ui/energy_saving_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('automatically saves energy at twenty percent', () async {
    final battery = _Battery(20);
    final controller = EnergySavingController(
      store: _SettingsStore(),
      battery: battery,
      pollInterval: const Duration(days: 1),
    );
    addTearDown(controller.dispose);

    await controller.start();
    await controller.refreshBatteryLevel();
    expect(controller.automaticEnabled, isTrue);
    expect(controller.effectiveEnabled, isTrue);

    battery.level = 21;
    battery.emitStateChange();
    await Future<void>.delayed(Duration.zero);
    expect(controller.automaticEnabled, isFalse);

    battery.level = -1;
    battery.emitStateChange();
    await Future<void>.delayed(Duration.zero);
    expect(controller.automaticEnabled, isFalse);
  });

  test('manual energy saving persists and forces dark temporarily', () async {
    final store = _SettingsStore();
    final energy = EnergySavingController(
      store: store,
      battery: _Battery(80),
      pollInterval: const Duration(days: 1),
    );
    final theme = AppThemeController(store: store);
    addTearDown(energy.dispose);
    addTearDown(theme.dispose);
    await theme.load();
    theme.setPreference(AppThemePreference.light);
    await energy.start();

    await energy.setManualEnabled(true);
    theme.setEnergySavingEnabled(energy.effectiveEnabled);

    expect(store.data.energySavingEnabled, isTrue);
    expect(theme.isDark, isTrue);
    expect(theme.preference, AppThemePreference.light);

    await energy.disable();
    theme.setEnergySavingEnabled(energy.effectiveEnabled);
    expect(theme.isDark, isFalse);
    expect(theme.preference, AppThemePreference.light);
    expect(store.data.energySavingEnabled, isFalse);
  });

  test('explicit disable suppresses low-battery mode until recovery', () async {
    final battery = _Battery(20);
    final controller = EnergySavingController(
      store: _SettingsStore(),
      battery: battery,
      pollInterval: const Duration(days: 1),
    );
    addTearDown(controller.dispose);

    await controller.start();
    await controller.refreshBatteryLevel();
    expect(controller.automaticEnabled, isTrue);

    await controller.disable();
    expect(controller.automaticEnabled, isFalse);
    expect(controller.effectiveEnabled, isFalse);

    await controller.refreshBatteryLevel();
    expect(controller.effectiveEnabled, isFalse);

    battery.level = 21;
    await controller.refreshBatteryLevel();
    expect(controller.automaticEnabled, isFalse);

    battery.level = 20;
    await controller.refreshBatteryLevel();
    expect(controller.automaticEnabled, isTrue);
  });
}

class _Battery implements BatteryStatusProvider {
  _Battery(this.level);

  int level;
  final _changes = StreamController<void>.broadcast();

  @override
  Future<int> get batteryLevel async => level;

  @override
  Stream<void> get stateChanges => _changes.stream;

  void emitStateChange() => _changes.add(null);
}

class _SettingsStore extends SettingsStore {
  SettingsData data = SettingsData.defaults;

  @override
  Future<SettingsData> load() async => data;

  @override
  Future<void> save(SettingsData data) async => this.data = data;

  @override
  Future<void> saveEnergySavingEnabled(bool enabled) async {
    data = data.copyWith(energySavingEnabled: enabled);
  }

  @override
  Future<void> saveThemeMode(String themeModeName) async {
    data = data.copyWith(themeModeName: themeModeName);
  }
}
