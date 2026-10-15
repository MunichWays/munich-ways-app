# Route per Link oder QR-Code importieren (#168)

Der Upload-Button in „Route planen“ öffnet zuerst die Auswahl der Importquelle:
Routenlink einfügen (auch per Zwischenablage-Button), QR-Code scannen oder GPX-Datei auswählen.
Anschließend folgt die bestehende Routenvorschau zum Prüfen, Übernehmen und Speichern.

Der Dialog nutzt auf Handys die verfügbare Breite mit 12 px Außenrand, auf größeren
Displays maximal 640 px. Der Inhalt bleibt bei Tastatur und großer Schrift scrollbar.
Kurze Fehlermeldungen erlauben erneute Versuche ohne erneutes Öffnen des Dialogs.

Nur HTTPS-Teilen-Links von radlnavi.munichways.de werden akzeptiert. Die Kamera
wird erst im Scanner geöffnet und vor der Rückkehr geschlossen. Abbrechen oder
fehlgeschlagene Downloads verändern die vorhandene Route nicht.

## Handytest

1. In RadlNavi eine Route mit Zwischenzielen teilen. In der App „Route planen“ →
   Upload-Symbol → „QR-Code scannen“ wählen und den QR-Code am PC scannen.
2. Vorschau prüfen, speichern, App neu starten: Strecke und Zwischenziele bleiben erhalten.
3. Alternativ den Teilen-Link kopieren, im Importdialog einfügen und laden.
4. GPX-Datei auswählen sowie Abbrechen, fehlende Internetverbindung und verweigerte
   Kamera-Berechtigung prüfen. Anschließend erneut importieren.

Die Kamera muss auf einem echten Android- und iOS-Gerät getestet werden.
Der iOS-Signierungsfix wurde separat in PR #266 erfolgreich auf macOS geprüft;
dieser Lauf enthält die neue Scanner-Funktion noch nicht.

## Technische Prüfung

- Gepinntes Flutter 3.47.6: statische Analyse ohne Befund.
- 39 gezielte Regressionstests erfolgreich.
- Vollständige Testsuite: 694 erfolgreich, 1 standardmäßig deaktivierter Live-API-Test.
- Lokaler Android-Testbuild: 69 (3.2.1+80).
- Neue Importfunktion auf Branch feature/gpx-link-qr-import, Handytest vom Nutzer erfolgreich abgeschlossen.