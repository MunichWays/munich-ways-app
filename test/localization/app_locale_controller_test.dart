import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/localization/app_locale_controller.dart';
import 'package:munich_ways/localization/app_localizations.dart';

void main() {
  test('loads and persists a manual language and system mode', () async {
    final store = _MemorySettingsStore(
      SettingsData.defaults.copyWith(languageCode: 'en'),
    );
    final controller = AppLocaleController(store: store);

    await controller.load();
    expect(controller.language, AppLanguage.english);
    expect(controller.locale, const Locale('en'));

    await controller.setLanguage(AppLanguage.german);
    expect(store.data.languageCode, 'de');

    await controller.setLanguage(AppLanguage.system);
    expect(controller.locale, isNull);
    expect(store.data.languageCode, isNull);
  });

  test('localizations contain German and English reload feedback', () {
    expect(
      const AppLocalizations(Locale('de')).reloadingMap,
      'Karte und Bewertungen werden neu geladen …',
    );
    expect(
      const AppLocalizations(Locale('en')).reloadingMap,
      'Reloading map and ratings…',
    );
  });
}

class _MemorySettingsStore extends SettingsStore {
  _MemorySettingsStore(this.data);

  SettingsData data;

  @override
  Future<SettingsData> load() async => data;

  @override
  Future<void> saveLanguage(String? languageCode) async {
    data = data.copyWith(
      languageCode: languageCode,
      clearLanguageCode: languageCode == null,
    );
  }
}
