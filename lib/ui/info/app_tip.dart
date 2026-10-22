import 'package:flutter/material.dart';

/// Permanent list and first-run selection share one set of tip content.
const orderedAppTips = [
  AppTip.savedPlaceMenu,
  AppTip.exploreMap,
  AppTip.reorderRoute,
  AppTip.foldPanel,
  AppTip.intermediateStops,
  AppTip.saveRoute,
  AppTip.importRoute,
  AppTip.favorites,
  AppTip.compareRoutes,
];

const firstRunAppTips = [
  AppTip.savedPlaceMenu,
  AppTip.exploreMap,
  AppTip.reorderRoute,
];

enum AppTip {
  savedPlaceMenu,
  exploreMap,
  reorderRoute,
  foldPanel,
  intermediateStops,
  saveRoute,
  importRoute,
  favorites,
  compareRoutes;

  IconData get icon => switch (this) {
        savedPlaceMenu => Icons.more_vert,
        exploreMap => Icons.touch_app_outlined,
        reorderRoute => Icons.swap_vert,
        foldPanel => Icons.expand_more,
        intermediateStops => Icons.add_location_alt_outlined,
        saveRoute => Icons.save_outlined,
        importRoute => Icons.file_download_outlined,
        favorites => Icons.star_border,
        compareRoutes => Icons.alt_route,
      };

  String title(bool english) => switch (this) {
        savedPlaceMenu =>
          english ? 'The three-dot menu' : 'Das Drei-Punkte-Menü',
        exploreMap => english
            ? 'Long press, discover more'
            : 'Lange drücken, mehr entdecken',
        reorderRoute => english
            ? 'Reorder your route'
            : 'Start, Zwischenziele und Ziel verschieben',
        foldPanel =>
          english ? 'More room for the map' : 'Mehr Platz für die Karte',
        intermediateStops => english
            ? 'Plan with intermediate stops'
            : 'Mit Zwischenzielen planen',
        saveRoute =>
          english ? 'Save a route for later' : 'Route für später speichern',
        importRoute => english ? 'Import a route' : 'Route importieren',
        favorites => english
            ? 'Reach favorite places quickly'
            : 'Lieblingsziele schnell erreichen',
        compareRoutes => english ? 'Compare routes' : 'Routen vergleichen',
      };

  String body(bool english) => switch (this) {
        savedPlaceMenu => english
            ? 'Under “Destination?”, tap the three dots next to a saved place or route to add favorites, change names or delete entries.'
            : 'Tippe unter „Wohin?“ auf die drei Punkte neben einem gespeicherten Ziel oder einer Route. Hier kannst du Favoriten festlegen, Namen ändern oder Einträge löschen.',
        exploreMap => english
            ? 'Long press a place on the map to plan a route there. For rated paths, you can also choose “Show details”.'
            : 'Halte einen Ort auf der Karte gedrückt, um dorthin zu planen. Bei bewerteten Wegen findest du außerdem „Details anzeigen“.',
        reorderRoute => english
            ? 'Under “Plan route”, long press an entry and drag it to the desired position. The three-dot menu also lets you move a selected place to the start or destination.'
            : 'Halte unter „Route planen“ einen Eintrag gedrückt und ziehe ihn an die gewünschte Stelle. Über die drei Punkte kannst du einen gewählten Ort auch als Start oder Ziel verschieben.',
        foldPanel => english
            ? 'Tap the grip on the route panel or drag it down. Drag up to show the information again. Navigation continues while the panel is folded.'
            : 'Tippe auf den Griff am Routenfenster oder ziehe es nach unten. Nach oben ziehst du die Informationen wieder auf. Die Navigation läuft auch bei eingeklapptem Fenster weiter.',
        intermediateStops => english
            ? 'Under “Plan route”, choose “Add intermediate stop” to visit a particular place along the way. Your route follows the order shown.'
            : 'Wähle unter „Route planen“ „Zwischenziel hinzufügen“, wenn du unterwegs einen bestimmten Ort anfahren möchtest. Die Route folgt der angezeigten Reihenfolge.',
        saveRoute => english
            ? 'Tap the save symbol in the route planner and give your route a name. You will find it later under “Destination?”.'
            : 'Tippe im Routenplaner auf das Speichern-Symbol und vergib einen Namen. Du findest die Route später unter „Wohin?“ wieder.',
        importRoute => english
            ? 'In “Plan route”, tap the import symbol. Choose a GPX file with one continuous track (max. 4 MB).\n\nFrom RadlNavi: plan a route there and open “Open in app / share”. In the MunichWays app, scan the QR code or paste the route link and tap “Load link”. Check the preview, then use the route with or without saving it.\n\nPure GPX tracks have no turn instructions or travel time.\n\nTo another app, such as komoot: choose “Export GPX” in the route planner, then import the file into the other app.'
            : 'Tippe unter „Route planen“ auf das Import-Symbol. Wähle eine GPX-Datei mit einem durchgehenden Track (max. 4 MB).\n\nAus RadlNavi: Plane dort eine Route und öffne „In App öffnen / teilen“. Scanne in der MunichWays-App den QR-Code oder füge den Routenlink ein und tippe auf „Link laden“. Prüfe die Vorschau und übernimm die Route mit oder ohne Speichern.\n\nReine GPX-Tracks enthalten keine Abbiegehinweise und Fahrzeit.\n\nIn eine andere App, zum Beispiel komoot: Wähle im Routenplaner „GPX exportieren“ und importiere die Datei in der anderen App.',
        favorites => english
            ? 'Save frequent destinations or routes as favorites using their three-dot menu. Up to three favorites are available directly on the home screen.'
            : 'Speichere häufige Ziele oder Routen über ihr Drei-Punkte-Menü als Favoriten. Bis zu drei Favoriten sind direkt auf dem Startbildschirm erreichbar.',
        compareRoutes => english
            ? 'When route alternatives are available, select a variant to view it on the map. Compare distance, duration and cycling comfort before setting off.'
            : 'Wenn Routenalternativen verfügbar sind, wähle eine Variante, um sie auf der Karte zu sehen. Vergleiche vor der Fahrt Strecke, Fahrzeit und Radl-Komfort.',
      };
}
