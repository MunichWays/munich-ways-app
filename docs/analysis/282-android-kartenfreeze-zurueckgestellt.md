# Android-Kartenfreeze – Build 88, Untersuchung vom 25.10.2026

Am 22.10.2026 auf Nutzerwunsch zurückgestellt, am 25.10. nach erneutem
kritischem Praxistestbefund wieder aufgenommen. Die aktuelle Korrektur umgeht
den durch Live-Protokolle eingegrenzten fehlerhaften Darstellungsweg.
Der Nutzer hat den anschließenden Praxistest als erfolgreich bestätigt.

## Gemeldeter Ablauf

- Auf Fairphone 4 und Samsung Flip3 nach Neuinstallation beobachtet, beim
  Flip3 ohne Regen. Standort sofort erlauben, erstes Ziel eingeben und
  Navigation starten: Startansage korrekt, Karte zunächst beweglich.
- Beim wiederholten Flip3-Test friert das Kartenbild genau an der Position
  ein, an der das Display ausgeschaltet wurde. Nach dem Einschalten laufen
  Ansagen korrekt weiter; Position, Karte und manuelle Gesten bleiben visuell
  eingefroren. Display aus/an ist damit ein konkret reproduzierter Auslöser.
- Beim früheren Fairphone-Test wurde laut Nutzer das Display nicht
  ausgeschaltet. Dieser Befund bleibt offen; er beweist keinen anderen
  Auslöser und ist durch den Flip3-Test nicht widerlegt.
- Mehrfache Neuberechnung, Standort-/Kompasstaste und Navigation beenden/neu
  starten halfen im ersten Test nicht; ein App-Neustart stellte die Funktion
  wieder her. Im Wiederholungstest erholte sich die Karte später auch ohne
  App-Neustart. Die konkrete auslösende Aktion dieser Erholung ist unbekannt.

## Belege während des Stillstands

Die nachgereichte Momentaufnahme wurde am 25.10.2026 um
`13:37:52.315287Z` (14:37:52 Winterzeit) **während** des Stillstands kopiert:

- Version `3.2.1+88`, Android, Release-Ausführung; „Testbuild 87“ ist der
  davon unabhängige lokale Testzähler, nicht die installierte App-Buildnummer.
- App-Lebenszyklus `resumed`, Kartenstil und Kartenkamera bereit.
- Alle **445 erfassten** nativen Aufrufe erfolgreich abgeschlossen,
  keine ausstehenden Aufrufe und keine erfassten Fehler.
- Standort-Zeichenlauf und Kameraänderung weder aktiv noch ausstehend.
- Frisches GPS (Genauigkeit 3,8 m); Position-Layer-Aufrufe werden weiterhin
  innerhalb weniger Millisekunden erfolgreich beantwortet.
- Native Kamerabewegung und Kameraende um 13:37:42 UTC, Karten-Leerlauf
  um 13:37:52 UTC: native Rückmeldungen laufen trotz eingefrorenem Bild weiter.
- Zu diesem Zeitpunkt bereits `NO_ROUTE`, Navigation nicht gestartet,
  Standortmodus `DISPLAY`. Der Stillstand besteht also auch nach Beenden der
  Navigation fort und ist kein bloß ausgeschalteter Folgemodus.

Die noch laufende App (PID 20555) wurde anschließend schreibgeschützt per ADB
untersucht. Der vollständige Logpuffer und Activity-, Display-, SurfaceFlinger-
und Grafikzustand wurden lokal gesichert:

- Um **14:32:59.853** meldet die Karten-ImageReader-Verbindung
  `connect: already connected (cur=1 req=1)`.
- Von **14:32:59.968 bis 14:38:47.822** folgen **3969** Meldungen
  `dequeueBuffer: BufferQueue has no connected producer` für denselben
  `ImageReader-1080x2640f22m7-20555-0`.
- SurfaceFlingers CompositionEngine meldet für `flutter-vd#0` zeitgleich
  `ANativeWindow::dequeueBuffer failed ... error: -19` und verwirft Frames.
- Die App bleibt als Vordergrund-Activity vorhanden. Fehlgeschlagene
  Schrift-/Sprite-Netzabrufe sind ebenfalls sichtbar, erklären die getrennte
  Bildpuffer-Verbindung aber nicht.

Damit ist der Fehler auf die Bildübergabe des SurfaceView-/VirtualDisplay-
Pfads eingegrenzt. Ein dauerhaft blockierter erfasster Dart-Kartenaufruf passt
nicht zu dieser Momentaufnahme. Welche konkrete Reihenfolge beim nativen
Wiederanschließen den Fehler auslöst, ist nicht abschließend nachgewiesen.

## Zusammenhang und Korrektur

Der offene [Flutter-Bericht #172641](https://github.com/flutter/flutter/issues/172641)
beschreibt SurfaceView in VirtualDisplay nach Bildschirm-Sperren/Entsperren
mit denselben BufferQueue-/CompositionEngine-Meldungen; dort ist auch ein
MapLibre-Fall mit Flutter 3.44 dokumentiert. Das Projekt und seine Handy-
Startskripte verwenden gepinntes Flutter 3.47.6, MapLibre GL 0.27.1.
Die übereinstimmenden Protokolle stützen die Zuordnung zum selben Fehlerbild.

`main.dart` setzt vor der ersten Karte
`MapLibreMap.useHybridComposition = true`. Trotz des API-Namens wählt diese
Option in MapLibre GL 0.27.1 **TextureView** statt GLSurfaceView. Flutter kann
TextureView direkt als Texture-Layer zusammensetzen und benötigt dafür den
betroffenen VirtualDisplay-Pfad nicht. Siehe
[MapLibre-Architektur](https://maplibre.org/flutter-maplibre-gl/concepts/architecture/#platform-view-mode-android)
und die Paketimplementierung (`MapLibreMapBuilder.setUseHybridComposition`,
`MapLibreMethodChannel.buildView`). Die Option wird auf iOS/Web ignoriert.

Die Änderung bleibt auf die initiale Android-Darstellung beschränkt. Sie fügt
keine Wiederholungen, Remounts oder Timeouts hinzu. GPS, Ansagen, Routenstatus
und native Lebenszyklusverwaltung behalten ihre bisherige Zuständigkeit.
TextureView hat einen höheren Darstellungsaufwand; flüssige Gesten, Lesbarkeit,
Overlays und Verhalten auf kleineren Android-Geräten sind deshalb Teil des
Praxistests. Die native Bildübergabe lässt sich durch Desktop-Widgettests mit
ersetzter Kartenplattform nicht verifizieren.

## Reproduktion, Erholung und Nebenwirkungen prüfen

1. Neuinstallation, Standort sofort erlauben, erste Route starten und zunächst
   mit dauerhaft eingeschaltetem Display fahren: Position, Karte und Gesten
   müssen weiter funktionieren.
2. Mehrfach manuell sperren/entsperren, auch länger gesperrt lassen. Nach jeder
   Rückkehr müssen aktueller Positionspunkt, Karte und Verschieben/Zoomen
   sofort sichtbar reagieren; Ansagen müssen weiterlaufen.
3. Ebenso App wechseln/zurückkehren, Navigation beenden/neu starten und
   Neuberechnung prüfen. Bestehende Installation, Hell-/Dunkelmodus,
   Energiesparen sowie Flip3/Fairphone und ein weiteres Android-Gerät abdecken.
4. Kartenknöpfe, Positionspunkt, Route, Netzüberlagerungen, POIs, Darstellungs-
   flüssigkeit und Erwärmung beobachten. iPhone als Kontrolltest für Navigation
   und Bildschirm aus/an einbeziehen.
5. Bei erneutem Stillstand vor Neustart Info → Diagnosedaten kopieren, lokale
   Uhrzeit notieren und Android-Logs sichern. Auch spontane Erholung und die
   unmittelbar vorherige Aktion dokumentieren.

## Frühere Protokolle und Historie

Im ersten Flip3-Test lag der Stillstand nach Schätzung des Nutzers gegen
13:30 Uhr Winterzeit (12:30 UTC). Android verzeichnet manuelles Beenden um
13:41:37.961 und Prozessneustart um 13:41:41.794. Beim späteren Anschluss
funktionierten Karte und Gesten wieder. Der damalige `main`-Puffer begann
erst um 13:48:28.647; direkte App-Meldungen des Fehlerzeitraums waren bereits
überschrieben. Die noch älteren Systemmeldungen allein erlaubten keine
Ursachenbestimmung.

Am 22.10. war ein ähnlicher Stillstand nach Display aus/an im Energiesparmodus
gemeldet worden: Ansagen erholten sich, das Kartenbild einschließlich Gesten
erst nach App-Neustart. Die damals eingeführte begrenzte In-Memory-Diagnose
(`map_render_diagnostics.dart`) machte die aktuelle Unterscheidung möglich.
Beim damaligen Zurückstellen bestanden Formatierung, Diff-Prüfung, Analyse
und 37 gezielte Tests; der lokale Release-Build für Testbuild 79 wurde auf
Nutzerwunsch abgebrochen. Das sind historische Ergebnisse, keine Verifikation
der jetzigen TextureView-Umstellung.

## Ergebnis des Praxistests

Nach der TextureView-Umstellung meldete der Nutzer am 25.10.2026 einen
erfolgreichen Praxistest. Der Handylauf wurde anschließend beendet. Damit
liegt eine praktische Bestätigung der Korrektur im gemeldeten Ablauf vor.
Eine vollständige Bestätigung aller Geräte, Leistungsmerkmale sowie der
Radius- und Ansageszenarien ist aus dieser Rückmeldung nicht ableitbar;
die oben aufgeführte Checkliste bleibt für die Betatests relevant.

Rohprotokolle liegen ausschließlich unter `.local/freeze-diagnostics/`
(durch Git ignoriert). Sie werden nicht ins Repository oder in die Story
übernommen.

## Technische Verifikation des gemeinsamen Build-88-Standes

- Formatprüfung aller acht geänderten/neuen Dart-Dateien mit dem gepinnten
  Dart: unverändert; `git diff --check` erfolgreich.
- Statische Analyse mit Flutter 3.47.6: keine Befunde. Ein vorheriger Aufruf
  mit dem älteren globalen SDK wurde abgebrochen und zählt nicht als Prüfung.
- 177 fokussierte Tests erfolgreich: Ersteinrichtung, Darstellung/Thema,
  Kartenlayout/-diagnose, Mitteilungsfreigabe, Sprachführung und Zwischenziele.
- Vollständige Suite: 846 Tests erfolgreich, ein standardmäßig deaktivierter
  optionaler RadlNavi-Livetest übersprungen.
- Prüfprozesse sind beendet; kein Handylauf, Flutter-Compiler oder Testworker
  aktiv. Der verbleibende Gradle-Daemon wartet ohne aktiven Build.
- Kein APK-/iOS-Build in diesem Durchlauf erstellt und keine Installation
  gestartet. Die Umstellung nutzt eine bestehende Plugin-Option ohne native
  Abhängigkeitsänderung. Der Nutzer hat den anschließenden Praxistest als
  erfolgreich gemeldet; weitere Geräte- und Leistungsprüfungen bleiben Teil
  der Betatests.
- Gemeinsamer Stand auf `fix/287-build-88-navigation`. Eigener AI-Kommentar in
  [#287](https://github.com/MunichWays/munich-ways-app/issues/287#issuecomment-6397297159)
  enthält den gemeinsamen Umfang und den Handy-/Betatestplan.
