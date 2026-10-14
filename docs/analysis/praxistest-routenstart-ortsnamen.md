# Praxistest: Routenstart und Ortsnamen

Stand: 14. Oktober 2026. Änderungen in App und RadlNavi-Webprojekt auf
`feature/gpx-route-transfer`; Abschlussprüfung vor dem beauftragten Commit und Push.
Vorhandene GPX-Änderungen bleiben erhalten.

Der Startknopf war bei jedem festen Startpunkt ausgeblendet, auch bei aus
RadlNavi importierten Routen mit dem aktuellen Standort als Start. Er ist jetzt
auch für diese Routen verfügbar. Innerhalb von 30 Metern wird die vorhandene
Route direkt gestartet, ohne Netzwerkberechnung. Bei einem weiter entfernten
Start wird vom aktuellen Standort über den ursprünglichen Start als erstes
Zwischenziel und alle übrigen geplanten Punkte neu berechnet. Dabei kann sich
die berechnete Strecke zwischen den Punkten ändern; der gespeicherte
Original-Snapshot bleibt unverändert und kann erneut geöffnet werden.

Nur eine Startanfrage läuft gleichzeitig. GPS-Fehler und fehlende Berechtigung
lassen die Planung bestehen. Bei fehlgeschlagener Anfahrt wird die bisherige
Planung wiederhergestellt. Die vorhandene Route und ihre laufende
Komfortanalyse bleiben während der Berechnung erhalten. Eine inzwischen
beendete oder ersetzte Planung wird durch verspätete Antworten nicht gestartet.

RadlNavi übernahm den vollständigen Nominatim-Namen mit der gesamten
Verwaltungshierarchie. Start, Ziel und Zwischenziele verwenden nun strukturierte
Adressfelder: Name, Straße/Hausnummer und PLZ/Ort. GPX-Export und Speicherung
nutzen dieselbe Aufbereitung; Koordinaten und Routengeometrie bleiben erhalten.
Die App spricht bei Zwischenzielen auch aus älteren Importen nur die kurze
Bezeichnung. Hausnummern und Koordinatenbezeichnungen bleiben erhalten.

Automatische Prüfung:

- Dart-Format in der App und `git diff --check` in beiden Repositories erfolgreich.
- Vollständige Flutter-Analyse und Analysen der abschließend geänderten Dateien
  ohne Befund.
- Vollständige App-Testsuite: 669 bestanden.
- Ein opt-in RadlNavi-Livetest ohne `RADLNAVI_LIVE_TEST=true` nicht ausgeführt.
- Web: alle 50 Tests erfolgreich; Produktionsbuild erfolgreich mit bestehenden
  Lint- und Browserslist-Hinweisen.
- Bestehende Planertests an die bereits vorhandene GPX-Fensterhöhe angepasst;
  Verkleinern, Vergrößern, Schließen und sichtbare Komfortanzeige bleiben geprüft.

Handy- und Beta-Testschritte:

1. Eine RadlNavi-Route importieren, deren Start am aktuellen Standort liegt.
   Ohne Änderung im Planer auf **Starten** tippen: Navigation beginnt direkt;
   die Originalstrecke bleibt erhalten. Auch bei fehlendem Internet prüfen.
2. Eine Route mit einem deutlich entfernten festen Start importieren. Auf
   **Starten** tippen: zuerst Anfahrt berechnen, danach Navigation vom aktuellen
   Standort; der alte Start ist Zwischenziel 1. Alle übrigen Zwischenziele
   müssen in derselben Reihenfolge erhalten bleiben.
3. Für die Anfahrt Internet unterbrechen, dann wiederherstellen und erneut
   starten. Bei Fehler bleibt die alte Planung sichtbar; der nächste Versuch
   muss erfolgreich starten. Ebenso GPS und Standortberechtigung aus- und
   wieder einschalten.
4. Während einer langsamen Berechnung mehrfach starten oder die Route beenden.
   Es darf keine doppelte Navigation oder spätere Wiederöffnung geben.
5. In der lokalen aktualisierten RadlNavi-Webseite eine Adresse und einen POI
   mit Hausnummer auswählen, exportieren und importieren. Namen sollen ohne
   mehrfache Stadtviertel erscheinen. Auch einen alten langen Import testen:
   bei Erreichen des Zwischenziels kurze Ansage mit richtiger Nummer, Straße
   beziehungsweise POI. Deutsch/Englisch, Sprachansagen ein/aus, große Schrift
   sowie Hoch-/Querformat prüfen.

Android-Releasebuild mit R8 erfolgreich (Testbuild 65, App 3.2.1+79).
Der Nutzer hat den abschließenden Handytest erfolgreich bestätigt; Lauf beendet
und USB getrennt. iOS-Build und iPhone-Test sind weiterhin ausstehend.
Kein Hosting- oder Cloud-Deployment ausgeführt.

Zusätzliche Oberflächenkorrekturen: Überschrift „Route“, daneben Import-,
Export- und Speicher-Symbol im gleichen Layout (aktiv blau, inaktiv grau).
„Zielzugang: x m“ steht unter dem Zielort anstelle von „Ziel“ im Planer;
Restkilometer und Restminuten im blauen Navigationsfenster bleiben erhalten.

Der R8-Fehler entstand durch die vorzeitige Auswertung von :app, bevor dessen
Buildverzeichnis gesetzt war. Gradle setzt jetzt zuerst alle Buildverzeichnisse
und wertet anschließend :app aus; der erfolgreiche Releasebuild bestätigt den
korrekten Pfad zur Standard-ProGuard-Konfiguration.
