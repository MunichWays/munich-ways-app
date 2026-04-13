import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

var settingsStore = SettingsStore();

/// Persisted app settings (same pattern as [RecentSearchesStore]).
class SettingsStore {
  static const _fileName = 'settings.json';
  static const _legacyFileName = 'map_ui_prefs.json';

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
}

class SettingsData {
  const SettingsData({
    required this.showZoomButtons,
    required this.sidePanelEdgeName,
  });

  final bool showZoomButtons;

  /// [MapSidePanelEdge.name] (`left` / `right`).
  final String sidePanelEdgeName;

  static const SettingsData defaults = SettingsData(
    showZoomButtons: false,
    sidePanelEdgeName: 'right',
  );

  Map<String, dynamic> toJson() => {
        'showZoomButtons': showZoomButtons,
        'sidePanelEdge': sidePanelEdgeName,
      };

  factory SettingsData.fromJson(Map<String, dynamic> json) {
    final edge = json['sidePanelEdge'] as String?;
    return SettingsData(
      showZoomButtons: json['showZoomButtons'] as bool? ?? false,
      sidePanelEdgeName: (edge == 'left' || edge == 'right') ? edge! : 'right',
    );
  }
}
