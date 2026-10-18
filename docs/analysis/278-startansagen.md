# Startansagen (#278, Build 84)

Beim Navigationsstart unterdrückt die bestehende Startphase Abbiegeansagen,
bis mindestens 25 Meter Abstand zum Start erreicht sind. Ohne Kartenblick fehlt
dadurch anfangs die Orientierung. Diese Startphase bleibt unverändert; eine
zusätzliche Vorschau nennt einmalig die ersten zwei echten Richtungswechsel.

Die Vorschau verwendet die bereits für die Navigation bereinigten Manöver und
die Entfernung entlang der Route ab deren Start. Sie verändert weder den
Routenfortschritt noch die Merker für spätere Annäherungs- und Abbiegeansagen.
Abfahrt, Geradeausmeldungen, reine Namenswechsel und reine Wegtypwechsel werden
übersprungen. Kreisverkehre zählen einschließlich Ausfahrt als ein Manöver.
Bei einer Abbiegung wird nur diese genannt, ohne Abbiegungen bleibt die
Vorschau aus. Die zweite Abbiegung folgt mit „danach“, ohne zusätzliche Distanz
oder die Behauptung „sofort“. Himmelsrichtungen werden nicht angesagt.

Bekannte Straßen erhalten ihren Namen, bekannte Radwege den Hinweis „auf
Radweg“, auch ohne Wegtypwechsel. Unbekannte Wegtypen werden nicht erraten.
Die Vorschau funktioniert auf Deutsch und Englisch und benötigt keine neue
Netzwerkanfrage. Stumme Navigation und Routen ohne Abbiegeunterstützung erhalten
keine Vorschau. Wird Sprache beim ersten Start erst durch die neue
Mitteilungsberechtigung aktiviert, folgt die Vorschau nach der Freigabe.
Neuberechnungen und Fortsetzen lösen keine neue Startvorschau aus.

## Handy- und Betatest

1. Mit aktivierten Sprachansagen die vier Beispielrouten aus Issue #278 planen
   und jeweils **Starten** drücken. Noch im Stand die ersten zwei Abbiegungen
   hören: Schloßschmidstraße/Birketweg, Birketweg/Radweg,
   Radweg/De-la-Paz-Straße und Laimer Straße/Richildenstraße. Es dürfen keine
   Abfahrtsansage, Himmelsrichtung oder Geradeausmeldung dazwischenkommen.
2. Im Startbereich warten: die bestehende Startanzeige bleibt. Danach mehr als
   25 Meter vom Start wegfahren. Die normalen Ansagen einschließlich der
   vorangekündigten Abbiegungen müssen weiterhin am passenden Ort kommen.
3. Eine Route mit nur einer Abbiegung sowie eine gerade Route starten. Eine
   Abbiegung wird einmal vorab genannt; die gerade Route erhält keine Vorschau.
   Kreisverkehr prüfen: dessen Ausfahrt darf keine zweite Abbiegung verdrängen.
4. Ansagen ausschalten und erneut starten: keine Vorschau. Später wieder
   einschalten: normale aktuelle Navigationsansage. Pause/Fortsetzen und
   Neuberechnung dürfen die Startvorschau nicht wiederholen.
5. Eine bereits geladene Route ohne Internet starten: Vorschau und Navigation
   bleiben nutzbar, sofern eine lokale TTS-Stimme installiert ist. Eine Route
   ohne Abbiegeunterstützung erhält weiterhin nur den bisherigen Kartenhinweis.
6. Beim ersten Start die Mitteilungsberechtigung freigeben beziehungsweise
   ablehnen: Vorschau nur bei aktivierten Sprachansagen. Während einer Ansage
   pausieren oder beenden; danach erneut starten. Keine veraltete Ansage darf
   nachlaufen, und die nächste Navigation muss wieder sprechen können.
7. Deutsch/Englisch sowie die tatsächliche Wiedergabe am Android-Handy und
   iPhone prüfen; nach Unterbrechung durch einen Anruf erneut navigieren.

Die automatisierten Regressionstests decken die vier Beispiele, Filterung,
Kreisverkehr, Ein-/Zwei-Manövergrenze, normale Folgeansagen und den tatsächlichen
Startknopf mit aktivierter, stummer und nicht verfügbarer Sprachnavigation
sowie Erstfreigabe und Erholung nach einem TTS-Fehler ab. Native
Audiowiedergabe und Straßentest bleiben Geräteprüfungen.

## Automatische Prüfung

- Dart-Format und `git diff --check` erfolgreich.
- Vollständige Flutter-Analyse ohne Befund.
- 136 fokussierte Navigationstests erfolgreich.
- Vollständige Testsuite: 747 erfolgreich; ein opt-in RadlNavi-Livetest ohne
  `RADLNAVI_LIVE_TEST=true` übersprungen.
- Der Nutzer hat den erfolgreichen lokalen Handytest bestätigt; der Lauf ist
  beendet und das Handy abgezogen. Kein zusätzlicher APK-/iOS-Build durch den
  Agenten ausgeführt; ein iPhone-Test wurde nicht bestätigt.
- Umsetzung auf Branch `feature/278-startansagen`, Version `3.2.1+84`.
