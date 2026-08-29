import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:munich_ways/api/settings_store.dart';

enum AppThemePreference { light, dark, automatic }

class AppThemeController extends ChangeNotifier with WidgetsBindingObserver {
  AppThemeController({SettingsStore? store, DateTime Function()? now})
      : _store = store ?? settingsStore,
        _now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
  }

  final SettingsStore _store;
  final DateTime Function() _now;
  Timer? _timer;
  bool? _lastAutomaticIsDark;
  double? _latitude;
  double? _longitude;
  AppThemePreference _preference = AppThemePreference.automatic;
  bool _energySavingEnabled = false;

  AppThemePreference get preference => _preference;
  bool get isDark =>
      _energySavingEnabled ||
      switch (_preference) {
        AppThemePreference.light => false,
        AppThemePreference.dark => true,
        AppThemePreference.automatic => _latitude == null || _longitude == null
            ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark
            : !_isDaylightAt(_now(), _latitude!, _longitude!),
      };
  ThemeMode get themeMode => isDark ? ThemeMode.dark : ThemeMode.light;

  void startAutomaticUpdates() {
    _lastAutomaticIsDark = isDark;
    _timer ??= Timer.periodic(const Duration(minutes: 5), (_) {
      _refreshAutomaticTheme();
    });
  }

  void _refreshAutomaticTheme() {
    if (_preference != AppThemePreference.automatic) return;
    final currentIsDark = isDark;
    if (_lastAutomaticIsDark == currentIsDark) return;
    _lastAutomaticIsDark = currentIsDark;
    notifyListeners();
  }

  Future<void> load() async {
    final data = await _store.load();
    _preference = AppThemePreference.values.firstWhere(
      (value) => value.name == data.themeModeName,
      orElse: () => AppThemePreference.automatic,
    );
    notifyListeners();
  }

  void setPreference(AppThemePreference value) {
    if (_preference == value) return;
    _preference = value;
    _lastAutomaticIsDark =
        value == AppThemePreference.automatic ? isDark : null;
    notifyListeners();
    _store.saveThemeMode(value.name);
  }

  void setEnergySavingEnabled(bool enabled) {
    if (_energySavingEnabled == enabled) return;
    _energySavingEnabled = enabled;
    notifyListeners();
  }

  /// Uses a position already obtained by the map/navigation flow. This method
  /// never requests location permission itself; without a position, automatic
  /// appearance follows the operating-system theme.
  void updateLocation(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
    _refreshAutomaticTheme();
  }

  @override
  void didChangePlatformBrightness() {
    _refreshAutomaticTheme();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _preference == AppThemePreference.automatic) {
      _refreshAutomaticTheme();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}

// Sunrise/sunset approximation for the available map/navigation position. It
// is accurate to a few minutes and never requests location solely for theme.
bool _isDaylightAt(
  DateTime localTime,
  double latitudeDegrees,
  double longitudeDegrees,
) {
  final day = int.parse(DateFormatDayOfYear.format(localTime));
  final latitude = latitudeDegrees * math.pi / 180;
  final gamma = 2 * math.pi / 365 * (day - 1);
  final equationOfTime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(gamma) -
          0.032077 * math.sin(gamma) -
          0.014615 * math.cos(2 * gamma) -
          0.040849 * math.sin(2 * gamma));
  final declination = 0.006918 -
      0.399912 * math.cos(gamma) +
      0.070257 * math.sin(gamma) -
      0.006758 * math.cos(2 * gamma) +
      0.000907 * math.sin(2 * gamma) -
      0.002697 * math.cos(3 * gamma) +
      0.00148 * math.sin(3 * gamma);
  final hourAngleCos = math.cos(90.833 * math.pi / 180) /
          (math.cos(latitude) * math.cos(declination)) -
      math.tan(latitude) * math.tan(declination);
  if (hourAngleCos >= 1) return false;
  if (hourAngleCos <= -1) return true;
  final hourAngle = math.acos(hourAngleCos);
  final solarNoon = 720 -
      4 * longitudeDegrees -
      equationOfTime +
      localTime.timeZoneOffset.inMinutes;
  final halfDay = hourAngle * 180 / math.pi * 4;
  final minute = localTime.hour * 60 + localTime.minute;
  return minute >= solarNoon - halfDay && minute < solarNoon + halfDay;
}

class DateFormatDayOfYear {
  const DateFormatDayOfYear._();

  static String format(DateTime date) {
    final first = DateTime(date.year);
    return (date.difference(first).inDays + 1).toString();
  }
}
