# Komoot-Import: Nymphenburg-Datei mit 21 Wegpunkten

User Story: https://github.com/MunichWays/munich-ways-app/issues/288
App-Version: 3.2.1+86; Branch in beiden Repositories: `fix/288-b86-gpx-50-stops`.

Die gemeldete Datei hat 121062 Bytes, einen Track, ein Tracksegment, 860 Trackpunkte
und 21 benannte Wegpunkte. Abgewiesen wurde sie durch die bisherige Grenze von
20 Zwischenzielen. Die alte Dialogmeldung nannte pauschal einen Track und 4 MB.

App, RadlNavi und die Validierung geteilter Routen erlauben jetzt bis zu 50
Zwischenziele. Track, Reihenfolge, Namen und Wegpunktkoordinaten bleiben erhalten.
Die Grenze von 4 MiB und 100000 Trackpunkten bleibt bestehen. Mehrere Tracks oder
getrennte Tracksegmente werden weiterhin abgewiesen, ohne sie durch Luftlinien
zu verbinden.

Die App unterscheidet Datei zu groß, XML-Fehler, GPX-Version, Trackanzahl,
Segmentanzahl, ungültige Koordinaten und zu viele Wegpunkte. Der Importdialog
und das Öffnen aus anderen Apps zeigen den konkreten Grund in Deutsch/Englisch.

## Handytest

1. Geheimtipps Nymphenburg-komoot.gpx importieren: Die Vorschau zeigt 21
   Zwischenziele und die Originalstrecke.
2. Speichern, App neu starten, Route laden: Namen und Zwischenziele bleiben erhalten.
3. Als GPX exportieren und erneut importieren: Strecke und 21 Zwischenziele bleiben gleich.
4. Eine Datei mit mehreren Tracks bzw. mehr als 50 Wegpunkten wählen: Der konkrete
   Grund wird angezeigt; anschließend lässt sich eine gültige Datei importieren.

Für den Livebetrieb sind die App sowie RadlNavi-Frontend und -Backend zu
aktualisieren. Der Routing-Dienst wurde nicht geändert.
## Technische Prüfung

- Gepinntes Flutter 3.47.6: statische Analyse ohne Befund.
- 40 gezielte App-Tests einschließlich Importdialog und Tipps erfolgreich.
- Vollständige App-Suite: 810 erfolgreich; ein Live-API-Test standardmäßig deaktiviert.
- RadlNavi: 56 Frontend- und 92 Backend-Tests erfolgreich; Produktionsbuild erfolgreich.
- Android-Handytest mit App-Version 3.2.1+86 und RadlNavi-Live-Test vom Nutzer erfolgreich bestätigt.
- Umsetzung auf `fix/288-b86-gpx-50-stops` in beiden Repositories; Versionsstand und Prüfungen sind im jeweiligen PR dokumentiert.