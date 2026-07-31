import 'package:flutter/material.dart';

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
  String get routePlanning => isEnglish ? 'Route planning' : 'Routenplanung';
  String get routingAutomatic => isEnglish ? 'Automatic' : 'Automatisch';
  String get routingAutomaticDescription => isEnglish
      ? 'RadlNavi (Upper Bavaria) / BRouter (worldwide)'
      : 'RadlNavi (Oberbayern) / BRouter (weltweit)';
  String get routingBRouterEverywhere =>
      isEnglish ? 'BRouter everywhere' : 'BRouter überall';
  String get bRouterProfile => isEnglish ? 'BRouter profile' : 'BRouter Profil';
  String get bRouterTrekking =>
      isEnglish ? 'Trekking (default)' : 'Trekking (Standard)';
  String get bRouterFastBike =>
      isEnglish ? 'Road bike (fast)' : 'Rennrad (schnell)';
  String get bRouterShortest =>
      isEnglish ? 'Shortest route' : 'Kürzeste Strecke';
  String get routePlanningInfo => isEnglish
      ? 'Automatic uses RadlNavi for low-stress routes within Upper Bavaria '
          'and BRouter outside the region or when RadlNavi is unavailable.\n\n'
          '“BRouter everywhere” always uses BRouter worldwide.'
      : 'Automatisch nutzt RadlNavi für stressarme Routen innerhalb '
          'Oberbayerns und BRouter außerhalb der Region oder wenn RadlNavi '
          'nicht erreichbar ist.\n\n'
          '„BRouter überall“ nutzt weltweit immer BRouter.';
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
