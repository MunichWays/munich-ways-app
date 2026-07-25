import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

var settingsStore = SettingsStore();

/// Persisted app settings (same pattern as [RecentSearchesStore]).
class SettingsStore {
  static const _fileName = 'settings.json';
  static const _legacyFileName = 'map_ui_prefs.json';
  Future<void> _updateQueue = Future<void>.value();

  Future<File> _getJsonFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<SettingsData> load() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/$_fileName');
    if (!file.existsSync()) {
      final legacy = File('${directory.path}/$_legacyFileName');
      if (legacy.existsSync()) {
        try {
          final json =
              jsonDecode(await legacy.readAsString()) as Map<String, dynamic>;
          final data = SettingsData.fromJson(json);
          await save(data);
          try {
            await legacy.delete();
          } catch (_) {}
          return data;
        } catch (_) {
          return SettingsData.defaults;
        }
      }
      return SettingsData.defaults;
    }
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SettingsData.fromJson(json);
    } catch (_) {
      return SettingsData.defaults;
    }
  }

  Future<void> save(SettingsData data) async {
    final file = await _getJsonFile();
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(data.toJson()));
  }

  Future<void> saveMapSettings({
    required bool showZoomButtons,
    required String sidePanelEdgeName,
  }) {
    return _enqueueUpdate((current) => current.copyWith(
          showZoomButtons: showZoomButtons,
          sidePanelEdgeName: sidePanelEdgeName,
        ));
  }

  Future<void> saveLanguage(String? languageCode) {
    return _enqueueUpdate((current) => current.copyWith(
          languageCode: languageCode,
          clearLanguageCode: languageCode == null,
        ));
  }

  Future<void> _enqueueUpdate(
    SettingsData Function(SettingsData current) update,
  ) {
    final operation = _updateQueue.then((_) async {
      final current = await load();
      await save(update(current));
    });
    _updateQueue = operation.catchError((_) {});
    return operation;
  }
}

class SettingsData {
  const SettingsData({
    required this.showZoomButtons,
    required this.sidePanelEdgeName,
    required this.languageCode,
  });

  final bool showZoomButtons;

  /// [MapSidePanelEdge.name] (`left` / `right`).
  final String sidePanelEdgeName;

  /// `null` follows the operating system, otherwise `de` or `en`.
  final String? languageCode;

  static const SettingsData defaults = SettingsData(
    showZoomButtons: false,
    sidePanelEdgeName: 'right',
    languageCode: null,
  );

  Map<String, dynamic> toJson() => {
        'showZoomButtons': showZoomButtons,
        'sidePanelEdge': sidePanelEdgeName,
        if (languageCode != null) 'language': languageCode,
      };

  SettingsData copyWith({
    bool? showZoomButtons,
    String? sidePanelEdgeName,
    String? languageCode,
    bool clearLanguageCode = false,
  }) =>
      SettingsData(
        showZoomButtons: showZoomButtons ?? this.showZoomButtons,
        sidePanelEdgeName: sidePanelEdgeName ?? this.sidePanelEdgeName,
        languageCode:
            clearLanguageCode ? null : languageCode ?? this.languageCode,
      );

  factory SettingsData.fromJson(Map<String, dynamic> json) {
    final edge = json['sidePanelEdge'] as String?;
    final language = json['language'] as String?;
    return SettingsData(
      showZoomButtons: json['showZoomButtons'] as bool? ?? false,
      sidePanelEdgeName: (edge == 'left' || edge == 'right') ? edge! : 'right',
      languageCode: (language == 'de' || language == 'en') ? language : null,
    );
  }
}
