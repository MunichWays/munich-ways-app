import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:munich_ways/routing/routing_preferences.dart';

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

  Future<void> saveMapCamera({
    required double latitude,
    required double longitude,
    required double zoom,
    required double bearing,
  }) {
    return _enqueueUpdate((current) => current.copyWith(
          mapLatitude: latitude,
          mapLongitude: longitude,
          mapZoom: zoom,
          mapBearing: bearing,
        ));
  }

  Future<void> saveLanguage(String? languageCode) {
    return _enqueueUpdate((current) => current.copyWith(
          languageCode: languageCode,
          clearLanguageCode: languageCode == null,
        ));
  }

  Future<void> saveThemeMode(String themeModeName) {
    return _enqueueUpdate((current) => current.copyWith(
          themeModeName: themeModeName,
        ));
  }

  Future<void> saveEnergySavingEnabled(bool enabled) {
    return _enqueueUpdate((current) => current.copyWith(
          energySavingEnabled: enabled,
        ));
  }

  Future<void> saveVoiceGuidanceEnabled(bool enabled) {
    return _enqueueUpdate((current) => current.copyWith(
          voiceGuidanceEnabled: enabled,
        ));
  }

  Future<void> saveAutomaticReroutingEnabled(bool enabled) {
    return _enqueueUpdate((current) => current.copyWith(
          automaticReroutingEnabled: enabled,
        ));
  }

  Future<void> saveRoutingMode(RoutingMode routingMode) {
    return _enqueueUpdate((current) => current.copyWith(
          routingMode: routingMode,
        ));
  }

  Future<void> saveBRouterProfile(BRouterProfile profile) {
    return _enqueueUpdate((current) => current.copyWith(
          bRouterProfile: profile,
        ));
  }

  Future<void> saveRouteRecommendation(
    RouteRecommendation? recommendation,
  ) {
    return _enqueueUpdate((current) => current.copyWith(
          routeRecommendation: recommendation,
          clearRouteRecommendation: recommendation == null,
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
    required this.voiceGuidanceEnabled,
    required this.automaticReroutingEnabled,
    required this.routingMode,
    required this.bRouterProfile,
    required this.routeRecommendation,
    this.themeModeName = 'automatic',
    this.mapLatitude,
    this.mapLongitude,
    this.mapZoom,
    this.mapBearing,
    this.energySavingEnabled = false,
  });

  final bool showZoomButtons;

  /// [MapSidePanelEdge.name] (`left` / `right`).
  final String sidePanelEdgeName;

  /// `null` follows the operating system, otherwise `de` or `en`.
  final String? languageCode;
  final bool voiceGuidanceEnabled;
  final bool automaticReroutingEnabled;
  final RoutingMode routingMode;
  final BRouterProfile bRouterProfile;
  final RouteRecommendation? routeRecommendation;
  final String themeModeName;
  final double? mapLatitude;
  final double? mapLongitude;
  final double? mapZoom;
  final double? mapBearing;
  final bool energySavingEnabled;

  static const SettingsData defaults = SettingsData(
    showZoomButtons: true,
    sidePanelEdgeName: 'right',
    languageCode: null,
    voiceGuidanceEnabled: false,
    automaticReroutingEnabled: true,
    routingMode: RoutingMode.automatic,
    bRouterProfile: BRouterProfile.trekking,
    routeRecommendation: RouteRecommendation.standard,
    themeModeName: 'automatic',
    energySavingEnabled: false,
  );

  Map<String, dynamic> toJson() => {
        'showZoomButtons': showZoomButtons,
        'sidePanelEdge': sidePanelEdgeName,
        if (languageCode != null) 'language': languageCode,
        'voiceGuidanceEnabled': voiceGuidanceEnabled,
        'automaticReroutingEnabled': automaticReroutingEnabled,
        'routingMode': routingMode.name,
        'bRouterProfile': bRouterProfile.name,
        if (routeRecommendation != null)
          'routeRecommendation': routeRecommendation!.name,
        'themeMode': themeModeName,
        if (mapLatitude != null) 'mapLatitude': mapLatitude,
        if (mapLongitude != null) 'mapLongitude': mapLongitude,
        if (mapZoom != null) 'mapZoom': mapZoom,
        if (mapBearing != null) 'mapBearing': mapBearing,
        'energySavingEnabled': energySavingEnabled,
      };

  SettingsData copyWith({
    bool? showZoomButtons,
    String? sidePanelEdgeName,
    String? languageCode,
    bool clearLanguageCode = false,
    bool? voiceGuidanceEnabled,
    bool? automaticReroutingEnabled,
    RoutingMode? routingMode,
    BRouterProfile? bRouterProfile,
    RouteRecommendation? routeRecommendation,
    bool clearRouteRecommendation = false,
    String? themeModeName,
    double? mapLatitude,
    double? mapLongitude,
    double? mapZoom,
    double? mapBearing,
    bool? energySavingEnabled,
  }) =>
      SettingsData(
        showZoomButtons: showZoomButtons ?? this.showZoomButtons,
        sidePanelEdgeName: sidePanelEdgeName ?? this.sidePanelEdgeName,
        languageCode:
            clearLanguageCode ? null : languageCode ?? this.languageCode,
        voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
        automaticReroutingEnabled:
            automaticReroutingEnabled ?? this.automaticReroutingEnabled,
        routingMode: routingMode ?? this.routingMode,
        bRouterProfile: bRouterProfile ?? this.bRouterProfile,
        routeRecommendation: clearRouteRecommendation
            ? null
            : routeRecommendation ?? this.routeRecommendation,
        themeModeName: themeModeName ?? this.themeModeName,
        mapLatitude: mapLatitude ?? this.mapLatitude,
        mapLongitude: mapLongitude ?? this.mapLongitude,
        mapZoom: mapZoom ?? this.mapZoom,
        mapBearing: mapBearing ?? this.mapBearing,
        energySavingEnabled: energySavingEnabled ?? this.energySavingEnabled,
      );

  factory SettingsData.fromJson(Map<String, dynamic> json) {
    final edge = json['sidePanelEdge'] as String?;
    final language = json['language'] as String?;
    final routingMode = json['routingMode'] == 'bRouterEverywhere' ||
            json['routingMode'] == 'bRouter'
        ? RoutingMode.bRouterEverywhere
        : RoutingMode.automatic;
    final bRouterProfile = BRouterProfile.values.firstWhere(
      (profile) => profile.name == json['bRouterProfile'],
      orElse: () => BRouterProfile.trekking,
    );
    final storedRecommendation = RouteRecommendation.values
        .where(
          (recommendation) =>
              recommendation.name == json['routeRecommendation'],
        )
        .firstOrNull;
    final inferredRecommendation = routingMode == RoutingMode.automatic &&
            bRouterProfile == BRouterProfile.trekking
        ? RouteRecommendation.standard
        : routingMode == RoutingMode.bRouterEverywhere &&
                bRouterProfile == BRouterProfile.shortest
            ? RouteRecommendation.shortest
            : null;
    return SettingsData(
      showZoomButtons: json['showZoomButtons'] as bool? ?? true,
      sidePanelEdgeName: (edge == 'left' || edge == 'right') ? edge! : 'right',
      languageCode: (language == 'de' || language == 'en') ? language : null,
      voiceGuidanceEnabled: json['voiceGuidanceEnabled'] as bool? ?? false,
      automaticReroutingEnabled:
          json['automaticReroutingEnabled'] as bool? ?? true,
      routingMode: routingMode,
      bRouterProfile: bRouterProfile,
      routeRecommendation: storedRecommendation ?? inferredRecommendation,
      themeModeName: switch (json['themeMode']) {
        'light' => 'light',
        'dark' => 'dark',
        _ => 'automatic',
      },
      mapLatitude: (json['mapLatitude'] as num?)?.toDouble(),
      mapLongitude: (json['mapLongitude'] as num?)?.toDouble(),
      mapZoom: (json['mapZoom'] as num?)?.toDouble(),
      mapBearing: (json['mapBearing'] as num?)?.toDouble(),
      energySavingEnabled: json['energySavingEnabled'] as bool? ?? false,
    );
  }
}
