import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/ui/app_theme_controller.dart';
import 'package:munich_ways/ui/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final hour in [12, 0]) {
      testWidgets('automatic appearance: system ${brightness.name}, hour $hour',
          (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final store = _MemorySettingsStore();
        final controller = AppThemeController(
          store: store,
          now: () => DateTime.utc(2026, 6, 21, hour),
        );
        try {
          await controller.load();
          controller.startAutomaticUpdates();

          // Before GPS, follow the system; the first fix must never turn a
          // system-dark app light, even in daylight.
          expect(controller.isDark, brightness == Brightness.dark);
          controller.updateLocation(48.137, 11.575);
          final expectedDark = brightness == Brightness.dark || hour == 0;
          expect(controller.isDark, expectedDark);
          expect(controller.themeMode,
              expectedDark ? ThemeMode.dark : ThemeMode.light);
          expect(store.savedModes, isEmpty);
        } finally {
          controller.dispose();
        }
      });
    }
  }

  testWidgets(
      'system changes update the rendered theme and recover in daylight',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final controller = AppThemeController(
      store: _MemorySettingsStore(),
      now: () => DateTime.utc(2026, 6, 21, 12),
    );
    try {
      controller.startAutomaticUpdates();
      controller.updateLocation(48.137, 11.575);
      var notifications = 0;
      controller.addListener(() => notifications++);

      late BuildContext themeContext;
      await tester.pumpWidget(ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          theme: themeData,
          darkTheme: darkThemeData,
          themeMode: controller.themeMode,
          home: Builder(builder: (context) {
            themeContext = context;
            return const SizedBox.shrink();
          }),
        ),
      ));
      expect(Theme.of(themeContext).brightness, Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(Theme.of(themeContext).brightness, Brightness.dark);
      expect(notifications, 1);

      // Repeated fixes/callbacks must not reload the map for an unchanged theme.
      controller.updateLocation(48.138, 11.576);
      controller.didChangePlatformBrightness();
      expect(notifications, 1);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(Theme.of(themeContext).brightness, Brightness.light);
      expect(notifications, 2);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('automatic night mode survives a light system setting',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final controller = AppThemeController(
      store: _MemorySettingsStore(),
      now: () => DateTime.utc(2026, 6, 21),
    );
    try {
      controller.startAutomaticUpdates();
      controller.updateLocation(48.137, 11.575);
      var notifications = 0;
      controller.addListener(() => notifications++);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      expect(controller.isDark, isTrue);
      expect(notifications, 0);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('timer and resume retain daylight updates and system precedence',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    var now = DateTime.utc(2026, 6, 21, 12);
    final controller = AppThemeController(
      store: _MemorySettingsStore(),
      now: () => now,
    );
    try {
      controller.startAutomaticUpdates();
      controller.updateLocation(48.137, 11.575);
      expect(controller.isDark, isFalse);
      var notifications = 0;
      controller.addListener(() => notifications++);

      now = DateTime.utc(2026, 6, 22);
      await tester.pump(const Duration(minutes: 5));
      expect(controller.themeMode, ThemeMode.dark);
      expect(notifications, 1);

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = DateTime.utc(2026, 6, 22, 12);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(controller.themeMode, ThemeMode.light);
      expect(notifications, 2);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      now = DateTime.utc(2026, 6, 23);
      await tester.pump(const Duration(minutes: 5));
      now = DateTime.utc(2026, 6, 23, 12);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(controller.themeMode, ThemeMode.dark);
      expect(notifications, 3);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('manual preferences persist and energy saving remains temporary',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final store = _MemorySettingsStore();
    final controller = AppThemeController(
      store: store,
      now: () => DateTime.utc(2026, 6, 21, 12),
    );
    try {
      controller.startAutomaticUpdates();
      controller.updateLocation(48.137, 11.575);

      controller.setPreference(AppThemePreference.light);
      expect(controller.isDark, isFalse);
      final reloaded = AppThemeController(store: store);
      addTearDown(reloaded.dispose);
      await reloaded.load();
      expect(reloaded.preference, AppThemePreference.light);
      expect(reloaded.isDark, isFalse);

      controller.setEnergySavingEnabled(true);
      expect(controller.isDark, isTrue);
      controller.setEnergySavingEnabled(false);
      expect(controller.isDark, isFalse);
      expect(controller.preference, AppThemePreference.light);

      controller.setPreference(AppThemePreference.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      expect(controller.isDark, isTrue);

      controller.setPreference(AppThemePreference.automatic);
      expect(controller.isDark, isFalse);
      controller.setEnergySavingEnabled(true);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      controller.setEnergySavingEnabled(false);
      expect(controller.isDark, isTrue);
      expect(controller.preference, AppThemePreference.automatic);
      expect(store.savedModes, ['light', 'dark', 'automatic']);
    } finally {
      controller.dispose();
    }
  });
}

class _MemorySettingsStore extends SettingsStore {
  SettingsData data = SettingsData.defaults;
  final savedModes = <String>[];

  @override
  Future<SettingsData> load() async => data;

  @override
  Future<void> saveThemeMode(String themeModeName) async {
    savedModes.add(themeModeName);
    data = data.copyWith(themeModeName: themeModeName);
  }
}
