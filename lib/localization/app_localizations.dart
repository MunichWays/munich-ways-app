import 'package:flutter/material.dart';
import 'package:munich_ways/routing/routing_preferences.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;
  bool get isEnglish => locale.languageCode == 'en';

  static const supportedLocales = [Locale('de'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('de'));

  String get settings => isEnglish ? 'Settings' : 'Einstellungen';
  String get close => isEnglish ? 'Close' : 'Schließen';
  String get language => isEnglish ? 'Language' : 'Sprache';
  String get systemLanguage => isEnglish ? 'System language' : 'Systemsprache';
  String get german => isEnglish ? 'German' : 'Deutsch';
  String get english => isEnglish ? 'English' : 'Englisch';
  String get showZoomButtons => 'Zoom-Buttons';
  String get positionMapButtons => isEnglish ? 'Map buttons' : 'Karten-Buttons';
  String get left => isEnglish ? 'Left' : 'Links';
  String get right => isEnglish ? 'Right' : 'Rechts';
  String get reloadNetwork =>
      isEnglish ? 'Reload cycling network' : 'Radnetz neu laden';
  String get routePlanning =>
      isEnglish ? 'Route calculation' : 'Routenberechnung';
  String get routeRecommendation =>
      isEnglish ? 'Route recommendation' : 'Routenwunsch';
  String get standardRoute =>
      isEnglish ? 'Standard (recommended)' : 'Standard (empfohlen)';
  String get aloneAfterDark =>
      isEnglish ? 'Alone after dark (Beta)' : 'Allein im Dunkeln (Beta)';
  String get hotWeather =>
      isEnglish ? 'In hot weather (Beta)' : 'Bei Hitze (Beta)';
  String get snowAndMud =>
      isEnglish ? 'In snow and mud (Beta)' : 'Bei Schnee und Matsch (Beta)';
  String routeRecommendationInfo(RouteRecommendation recommendation) =>
      switch (recommendation) {
        RouteRecommendation.standard => isEnglish
            ? 'Returns to the balanced automatic route recommendation used by default.'
            : 'Kehrt zur ausgewogenen automatischen Routenempfehlung zurück, die standardmäßig verwendet wird.',
        RouteRecommendation.trekking => isEnglish
            ? 'Prefers comfortable, cycle-friendly connections. Turn-by-turn directions and voice guidance are unavailable in this selection; please follow the map.'
            : 'Bevorzugt komfortable, fahrradfreundliche Verbindungen. Abbiegehinweise und Sprachansagen sind bei dieser Auswahl nicht verfügbar; bitte folge der Karte.',
        RouteRecommendation.roadBike => isEnglish
            ? 'Prefers fast connections suitable for road bikes. Turn-by-turn directions and voice guidance are unavailable in this selection; please follow the map.'
            : 'Bevorzugt schnelle, für Rennräder geeignete Verbindungen. Abbiegehinweise und Sprachansagen sind bei dieser Auswahl nicht verfügbar; bitte folge der Karte.',
        RouteRecommendation.shortest => isEnglish
            ? 'Finds the shortest available route. Comfort, lighting and road surface may receive less consideration.'
            : 'Sucht die kürzeste verfügbare Strecke. Komfort, Beleuchtung und Oberfläche können dabei weniger berücksichtigt werden.',
        RouteRecommendation.aloneAfterDark => isEnglish
            ? 'Many people, especially women, feel uncomfortable cycling alone after dark. This recommendation tends to use direct, easily visible main connections. Lighting and how busy a road is are not known everywhere. Please check the route before setting off.'
            : 'Viele Menschen, besonders Frauen, fühlen sich unwohl, allein im Dunkeln zu fahren. Diese Empfehlung nutzt tendenziell direkte, gut einsehbare Hauptverbindungen. Beleuchtung und Belebtheit sind nicht überall bekannt. Bitte prüfe die Route vor der Fahrt.',
        RouteRecommendation.hotWeather => isEnglish
            ? 'Uses the balanced standard recommendation. Shade and local heat exposure are not yet included in the routing data.'
            : 'Nutzt die ausgewogene Standardempfehlung. Schatten und örtliche Hitzebelastung sind in den Routendaten noch nicht enthalten.',
        RouteRecommendation.snowAndMud => isEnglish
            ? 'Tends to prefer fast, well-surfaced connections. Surface condition and winter maintenance are not known everywhere.'
            : 'Bevorzugt tendenziell zügig befahrbare, befestigte Verbindungen. Der aktuelle Zustand und Winterdienst sind nicht überall bekannt.',
      };
  String get moreSettings =>
      isEnglish ? 'More settings' : 'Weitere Einstellungen';
  String get routingAutomatic => isEnglish ? 'Automatic' : 'Automatisch';
  String get routingAutomaticDescription => isEnglish
      ? 'RadlNavi (Upper Bavaria) / BRouter (worldwide)'
      : 'RadlNavi (Oberbayern) / BRouter (weltweit)';
  String get routingBRouterEverywhere =>
      isEnglish ? 'BRouter everywhere' : 'BRouter überall';
  String get bRouterProfile => isEnglish ? 'BRouter profile' : 'BRouter Profil';
  String get bRouterTrekking => 'Trekking';
  String get bRouterFastBike =>
      isEnglish ? 'Road bike (fast)' : 'Rennrad (schnell)';
  String get bRouterShortest =>
      isEnglish ? 'Shortest route' : 'Kürzeste Strecke';
  String get bRouterGuidanceInfo => isEnglish
      ? 'BRouter is used for route calculation only. Turn-by-turn directions '
          'and voice guidance are unavailable because BRouter does not provide '
          'sufficiently reliable maneuver data.'
      : 'BRouter wird nur zur Routenberechnung verwendet. Abbiegehinweise und '
          'Sprachansagen sind nicht verfügbar, da BRouter keine ausreichend '
          'zuverlässigen Abbiegedaten liefert.';
  String get followRouteOnMap => isEnglish ? 'Follow map' : 'Karte beachten';
  String get routePlanningInfo => isEnglish
      ? 'Automatic uses RadlNavi for low-stress routes within Upper Bavaria '
          'and BRouter outside the region or when RadlNavi is unavailable.'
      : 'Automatisch nutzt RadlNavi für stressarme Routen innerhalb '
          'Oberbayerns und BRouter außerhalb der Region oder wenn RadlNavi '
          'nicht erreichbar ist.';
  String get reloadingMap => isEnglish
      ? 'Reloading map and ratings…'
      : 'Karte und Bewertungen werden neu geladen …';
  String get mapUpdated => isEnglish ? 'Map updated' : 'Karte aktualisiert';
  String get mapUpdateFailed =>
      isEnglish ? 'Update failed' : 'Aktualisierung fehlgeschlagen';
  String get loadingMap => isEnglish
      ? 'Loading map and ratings'
      : 'Karte und Bewertungen werden geladen';
  String get loadingRatingsInBackground => isEnglish
      ? 'Loading ratings in the background…'
      : 'Bewertungen werden im Hintergrund geladen …';

  String selectDestination(String name) =>
      isEnglish ? 'Select destination: $name' : 'Ziel auswählen: $name';

  String tr(String de) => isEnglish ? (_english[de] ?? de) : de;

  static const _english = <String, String>{
    'Zurück zur Karte': 'Back to map',
    'Ziel suchen': 'Search destination',
    'Eingabe löschen': 'Clear input',
    'Keine Ergebnisse vorhanden.\\nBitte überprüfe den Suchbegriff.':
        'No results found.\\nPlease check your search term.',
    'Auf Karte auswählen': 'Select on map',
    'Letzte Ziele': 'Recent destinations',
    '(Suchverlauf löschen)': '(Clear search history)',
    'Fehler beim Laden.': 'Error while loading.',
    'Strecke': 'Route section',
    'Ist-Situation': 'Current situation',
    'Soll-Maßnahmen': 'Planned measures',
    'Maßnahmen-Kategorie': 'Measure category',
    'Beschreibung': 'Description',
    'Status-Umsetzung': 'Implementation status',
    'Bezirk': 'District',
    'Unbekannte Straße': 'Unknown street',
    'Kein Bild hinterlegt': 'No image available',
    'Mapillary öffnen': 'Open Mapillary',
    'Legende & Tipps': 'Legend & tips',
    'Impressum & Datenschutz': 'Legal notice & privacy',
    'Nutzungsbedingungen': 'Terms of use',
    'Impressum': 'Legal notice',
    'Zurück': 'Back',
    'Ziel auswählen': 'Select destination',
    'Details zu Streckenabschnitten': 'Route section details',
    'Standortberechtigung': 'Location permission',
    'Abbrechen': 'Cancel',
    'Appeinstellungen': 'App settings',
    'Standort aktivieren': 'Enable location',
    'Standorteinstellungen': 'Location settings',
    'Info': 'Info',
    'Fahrradnetz auswählen': 'Select cycling network',
    'Radl-Vorrang-Netz': 'Priority cycling network',
    'Linie durchgezogen': 'Solid line',
    'Weitere Strecken': 'Other routes',
    'Linie gestrichelt': 'Dashed line',
    'Gewünschtes Ziel auf der Karte lange antippen.':
        'Touch and hold the desired destination on the map.',
    'Vergrößern': 'Zoom in',
    'Verkleinern': 'Zoom out',
    'Starten': 'Start',
    'Route beenden': 'End route',
    'Bewertung | Happy Bike Level | OSM class:bicycle':
        'Rating | Happy Bike Level | OSM class:bicycle',
    'RadlVorrangNetz': 'Priority cycling network',
    'Neuralgischer Punkt': 'Critical point',
    'Straßenart': 'Road type',
    'Oberfläche': 'Surface',
    'Ebenheit': 'Smoothness',
    'Fahrradregelung': 'Bicycle designation',
    'Zugang': 'Access',
    'Breite': 'Width',
    'Beleuchtung': 'Lighting',
    'Weiteres Mapillary-Bild': 'Additional Mapillary image',
    'Auf Mapillary ansehen': 'View on Mapillary',
    'Netztyp Planung': 'Planned network type',
    'Netztyp Ziel': 'Target network type',
    'Auf OpenStreetMap ansehen': 'View on OpenStreetMap',
    'Link öffnen': 'Open link',
    'Weiterer Link': 'Additional link',
    'Ist-Zustand': 'Current state',
    'Forderungen und Netzplanung': 'Requests and network planning',
    'Weitere Links': 'Additional links',
    'Technische Angaben': 'Technical details',
    'Feedback': 'Feedback',
    'Feedback per E-Mail senden': 'Send feedback by email',
    'Keine E-Mail-App gefunden': 'No email app found',
    'grün': 'green',
    'gelb': 'yellow',
    'rot': 'red',
    'schwarz': 'black',
    'hervorragend': 'excellent',
    'gemütlich': 'comfortable',
    'durchschnittlich': 'average',
    'keine Aussage': 'no rating',
    'stressig': 'stressful',
    'sehr stressig': 'very stressful',
    'Unter allen Umständen vermeiden': 'avoid under all circumstances',
  };
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((value) => value.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
