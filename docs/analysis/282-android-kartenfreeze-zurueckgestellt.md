# Android-Kartenfreeze – zurückgestellt am 22.10.2026

Auf Wunsch des Nutzers vorerst keine weitere Fehlerbehebung.

## Gemeldeter Ablauf

- Korrekt auf der Route fahren, Android-Akkueinstellung auf Energiesparen.
- Display ausschalten; Tracking/Ansagen setzen aus, danach kommt die erwartete
  Warnung über fehlende Ansagen, mögliche Routenabweichung oder fehlendes GPS.
- Nach Einschalten des Displays sind die Ansagen wieder korrekt.
- Die gesamte Kartenfläche einschließlich blauem Positionspunkt bleibt am
  alten Standort eingefroren; auch Verschieben/Zoomen reagiert nicht mehr.
- Route neu berechnen hilft nicht; erst ein App-Neustart behebt den Zustand.

## Stand

Die Ursache ist nicht nachgewiesen. Insbesondere ist noch offen, ob native
Kartenaufrufe ausstehen oder der Android-Renderer trotz beantworteter Aufrufe
nicht mehr zeichnet. Keine Verhaltenskorrektur implementiert.

Diagnosehilfe: `map_render_diagnostics.dart` mit Einbindung
in `map_screen.dart` und eigenen Tests. Sie ergänzt Info → Diagnosedaten um
ausstehende/abgeschlossene Kartenaufrufe, Bereitschaftsflags und Zeitpunkte
nativer Kamera-/Karten-Rückmeldungen. Verlauf und Detailanzahl sind begrenzt;
keine Koordinaten oder nativen Fehlermeldungstexte werden dort aufgezeichnet.

Beim Zurückstellen waren Formatierung, `git diff --check`, statische Analyse
und 37 gezielte Tests erfolgreich. Der damalige lokale Release-Build für
Testbuild 79 wurde auf Wunsch des Nutzers abgebrochen.
Die Diagnosehilfe wird mit dem Abschlussstand des Branches gesichert; sie
behebt den Kartenfreeze nicht. Hilfe/Tipps und Routenimport gehören zu
separaten Änderungen im selben Branch.

## Bei Wiederaufnahme

Erst die Diagnosehilfe erneut prüfen und bei Bedarf bauen/installieren.
Beim nächsten Auftreten vor einem Neustart unter Info → Diagnosedaten
aktualisieren und kopieren; möglichst auch Android-Logs zum Display-Aus-/Ein-
Zeitpunkt sichern. Mit diesen Daten die Ursache reproduzieren, bevor das
Karten- oder Navigationsverhalten geändert wird.
