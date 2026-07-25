import 'dart:async';

import 'package:flutter/material.dart';
import 'package:munich_ways/api/settings_store.dart';

enum AppLanguage { system, german, english }

class AppLocaleController extends ChangeNotifier {
  AppLocaleController({SettingsStore? store}) : _store = store ?? settingsStore;

  final SettingsStore _store;
  AppLanguage _language = AppLanguage.system;

  AppLanguage get language => _language;

  Locale? get locale => switch (_language) {
        AppLanguage.system => null,
        AppLanguage.german => const Locale('de'),
        AppLanguage.english => const Locale('en'),
      };

  Future<void> load() async {
    final code = (await _store.load()).languageCode;
    _language = switch (code) {
      'de' => AppLanguage.german,
      'en' => AppLanguage.english,
      _ => AppLanguage.system,
    };
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    notifyListeners();
    final code = switch (value) {
      AppLanguage.system => null,
      AppLanguage.german => 'de',
      AppLanguage.english => 'en',
    };
    await _store.saveLanguage(code);
  }
}
