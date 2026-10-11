# Issue #189: Restkilometer und Restminuten bis zum Ziel

Stand: 11. Oktober 2026. Ursprünglicher Auftrag: analysieren und dokumentieren.
Die anschließend beauftragte Umsetzung ist am Ende dieser Datei beschrieben.
Quelle: [Issue #189](https://github.com/MunichWays/munich-ways-app/issues/189)
einschließlich des Kommentars zu Komplexität, Neuberechnung und Tracking.
Untersuchter Commit: `805298dc2b76692973578be9f81f90efdeb17be9`, zusätzlich
der lokale Arbeitsstand auf `257-app-store-bewertungen`. Dort bestehen bereits
Änderungen zu #257, unter anderem in Karte und Navigationskopfzeile; sie wurden
für diesen Auftrag ausschließlich gelesen und bleiben erhalten.

## Ergebnis und Empfehlung

Restkilometer lassen sich aus Routengeometrie und zuverlässig zugeordnetem
Fahrfortschritt lokal bestimmen. Eine neue Routing-Anfrage alle 500 Meter ist
dafür nicht nötig. Restminuten lassen sich mit den aktuell gespeicherten Daten
nur schätzen: Es gibt Gesamtdauer, aber keine gespeicherte Zeitkurve entlang
der Route. Diese Schätzung bildet unterschiedliche Geschwindigkeiten auf
Steigungen, Schiebestrecken und einzelnen Abschnitten nicht genau ab.

Empfohlen wird eine kleine, rein lokale Anzeigeerweiterung mit konservativem
Verhalten bei unsicherer Position. Kein stilles `refreshRoute()`, kein weiterer
GPS-Stream, kein zusätzlicher periodischer Hintergrunddienst. Die Anzeige darf
weder Ansagen noch Routenwechsel oder automatische Neuberechnungen steuern.
Falls dafür eine umfassende Neuordnung des Navigationsmatchings erforderlich
wird, sollte #189 zurückgestellt werden: Der Zusatznutzen rechtfertigt keine
gefährdete Navigation. Die Umsetzung ist deshalb bedingt sinnvoll, kein
risikoloser Austausch zweier Zahlen in der Kopfzeile.

## Heutiger Daten- und Aktualisierungsfluss

1. `RadlNaviApi.route()` übernimmt Gesamtlänge und Gesamtdauer aus der Antwort.
   Schrittinformationen werden für Manöver und Darstellung ausgewertet;
   Abschnittszeiten werden nicht in `CycleRoute` gespeichert. Angeforderte
   Annotationen sind `nodes,distance`, keine Zeitannotation.
2. `BRouterApi.route()` übernimmt `track-length` und `total-time`. Beim
   Shortest-Fallback wird die Dauer bereits aus 16 km/h errechnet. Auch hier
   enthält das Modell keine Abschnittszeiten. 20 km/h aus dem Issue sind ein
   Rechenbeispiel und keine allgemeine Annahme der App.
3. `CycleRoute.distance` und `.duration` bleiben die Gesamtwerte der jeweiligen
   berechneten Route. `MapNavigationHeaderBar.build()` zeigt genau diese Werte,
   gerundet auf 0,1 km und ganze Minuten. Ein erneuter Widgetaufbau ändert die
   Werte nicht. Ursache ist die fehlende Anbindung an den Fahrfortschritt.
4. Der bestehende Geolocator-Stream führt über `_drainLocationUpdates()` und
   `_renderLocation()` zu `_refreshVoiceGuidance()`. Navigation verarbeitet nur
   ausreichend genaue Positionen (höchstens 50 m) und frische Fixes (höchstens
   15 s im Guidance-Pfad). Der Strom berücksichtigt den Energiesparmodus und
   wird für aktive Navigation auf Android/iOS im Hintergrund konfiguriert.
5. `VoiceGuidance.display()` aktualisiert den privaten `_routeProgress` auch
   bei ausgeschalteter Sprachausgabe. `update()` ergänzt gesprochene Hinweise.
   Die Projektion begrenzt den Fortschritt normalerweise auf ein Fenster von
   120 m voraus; Kontinuität und Mehrdeutigkeit werden berücksichtigt.
6. Die eigentliche Off-route-Neuberechnung nutzt
   `isOffRouteForRerouting()`: Nähe zur gesamten Route und kontinuierliches
   Guidance-Matching sind bewusst verschiedene Fragen. Timer, Bewegungs- und
   Frischeprüfung, Retry, Generationen und eine Pause nach drei aufeinander-
   folgenden Neuberechnungen schützen diesen kritischen Ablauf.

Quellstellen: [Routenmodell](../../lib/model/route.dart),
[RadlNavi-Parser](../../lib/api/radlnavi_api.dart),
[BRouter-Parser](../../lib/api/brouter_api.dart),
[Kopfzeile](../../lib/ui/map/map_overlay/map_navigation_header_bar.dart),
[Standort und Rerouting](../../lib/ui/map/map_screen.dart),
[Guidance](../../lib/ui/map/voice_guidance.dart),
[Routenverwaltung](../../lib/ui/map/map_screen_model.dart).

## Warum stilles Neurouting ungeeignet ist

`MapScreenViewModel.refreshRoute()` ist kein Statistik-Refresh. Während der
Navigation entfernt es erreichte Zwischenziele, verwirft Routenvarianten und
startet eine neue Routengeneration mit Standortauflösung und Netzwerkanfrage.
Eine neue `CycleRoute` setzt über `VoiceGuidance.setRoute()` den Guidance-Zustand
zurück. Der manuelle Aufruf setzt außerdem den Rerouting-Ablauf zurück und
startet nach Erfolg die Navigation erneut; der automatische Aufruf verwaltet
eigene Versuche, Statusmeldungen und Fehlererholung.

Ein zusätzlicher unsichtbarer Aufruf könnte eine andere Route liefern, mit
laufendem Rerouting konkurrieren und bei fehlendem Netz den bestehenden
Fehler-/Ladezustand auslösen. Das bloße Ausblenden der Ladeanzeige beseitigt
diese Seiteneffekte nicht. Bei 20 km/h wären 500 m alle 90 s erreicht; das
Intervall ist zugleich zu grob für eine Anzeige, die sich in 0,1 km verändert.

## Grenzen der vorhandenen Fortschrittsdaten

- `_routeProgress` ist kein fertiger, öffentlich nutzbarer Messwert: Er gehört
  zur Guidance, ist normalerweise monoton, kann bei Wiederaufnahme neu
  verankert werden und wird auch bei mehrdeutigen Projektionen fortgeführt,
  damit die Guidance später wieder normal arbeiten kann. Ein Getter allein
  liefert weder Zuverlässigkeit noch eine sichere Reststreckenanzeige.
- `display()` verändert Zustand. Die neue Anzeige darf es nicht zusätzlich
  aus `build()` aufrufen. Sie benötigt ein Ergebnis des bestehenden
  Positionsdurchlaufs mit Gültigkeit, Routenbezug und geometrischem Fortschritt;
  keine unabhängige zweite Fortschrittslogik und keinen Sprach-Lookahead.
- Ohne `supportsVoiceGuidance` bleibt `_trackingRoute` für Off-route-Erkennung
  erhalten, aber `display()`/`resumeAt()` haben keine aktive Guidance-Route.
  Die Fortschrittsanzeige funktioniert dort nicht automatisch durch Freigabe
  des bisherigen Feldes. Ein sicherer lokaler Geometrieweg oder eine deutlich
  gekennzeichnete fehlende Restschätzung muss ausdrücklich vorgesehen werden.
- `RoutePositionSnapper.snap()` liefert nur die nächste Koordinate, keinen
  Abschnittsindex oder zuverlässigen Fortschritt. An Kreuzungen und auf
  identischen Hin-/Rückwegen ist dies keine ausreichende Quelle für #189.
- Backendlänge und geometrisch summierte Länge können abweichen. RadlNavi
  trennt außerdem gegebenenfalls einen letzten Fußzugang in
  `destinationConnector` ab, während Gesamtwerte aus der Antwort bestehen
  bleiben. BRouter hängt ebenfalls einen Zielverbinder an. Ein allgemeines
  `route.distance - geometrischerFortschritt` kann deshalb falsch enden.
- `_drainLocationUpdates()` hängt derzeit von bereiter Karte, Stil und
  Controller ab. Hintergrundkonfiguration des GPS-Streams beweist deshalb
  keine durchgehende Ausführung der neuen Berechnung bei gesperrtem Bildschirm.
  Beim Zurückkehren muss der nächste gültige Fix die Anzeige aktualisieren.
- Die vorhandene Ankunftserkennung ist kein Nachweis für alle Rundwege ohne
  Zwischenziel: Vorzeitige Ankunft bei Start nahe Ziel muss separat geprüft
  werden. #189 darf aus Zielnähe allein keine neuen Nullwerte ableiten.

## Vorgeschlagene kleinste Ausbaustufe

Vor Navigation weiterhin Gesamtwerte anzeigen. Während aktiver Navigation
Restwerte ausschließlich aus demselben zuverlässigen Positionsabgleich
ableiten, den die Navigation ohnehin benötigt. Routenidentität und Gültigkeit
müssen zusammen mit dem Fortschritt vorliegen. Überlappung, unklare Position,
Off-route, Pause, veralteter Fix und laufender Routenwechsel dürfen keinen
scheinbar aktuellen Restwert erzeugen. Letzten Wert als nicht aktuell markieren
oder `—` anzeigen; das konkrete UI muss verständlich und barrierefrei bleiben.
Die automatische Neuberechnung bleibt unabhängig von dieser Anzeige.

Für einfache, vollständig zuordenbare Geometrien kann eine erste Schätzung
den noch verbleibenden Anteil verwenden:

```text
restanteil = clamp((geometrielänge - fortschritt) / geometrielänge, 0, 1)
restmeter ≈ backendGesamtmeter * restanteil
restsekunden ≈ backendGesamtsekunden * restanteil
```

Das ist ein Vorschlag, keine schon vorhandene Implementierung. Voraussetzung
sind positive, endliche Werte, dieselbe Distanzbasis und ein definierter Umgang
mit Zielverbindern. Für abgetrennte Fußzugänge ist die Formel allein ungeeignet;
diese Fälle brauchen eine eigene Zuordnung oder bleiben ohne Restschätzung.
Erst bei eindeutig bestätigter endgültiger Ankunft darf auf null gesetzt werden;
ein Zwischenziel beendet die Restberechnung nicht.

Minuten als geschätzte Restfahrzeit kommunizieren. Kein Herunterzählen nach
verstrichener Uhrzeit, kein Teilen durch momentane GPS-Geschwindigkeit: Beides
würde bei Stillstand oder unruhigem GPS irreführen. Genauere Abschnittszeiten
wären eine spätere, gesonderte Erweiterung beider Provider/Modelle.

Kein 500-m-Timer: vorhandene akzeptierte Standortupdates verwenden, sichtbare
Werte nur bei Änderung der gerundeten Anzeige veröffentlichen. Längen pro
Route einmal vorbereiten und vorhandenes Matching-Ergebnis wiederverwenden.
Die aktuelle Projektion durchsucht die Route; ein weiterer vollständiger
Durchlauf je GPS-Fix sollte vermieden werden. Das begrenzt Zusatzarbeit, ist
aber noch kein gemessener Nachweis für Akkuverbrauch oder Laufzeit.

## Risiko- und Abnahmematrix nach einer späteren Umsetzung

| Fall | Erwartetes Verhalten |
| --- | --- |
| Normale Fahrt, Ansagen ein/aus, Automatik ein/aus | Restwerte folgen der gefahrenen Route; keine zusätzliche Routing-Anfrage, Ansage oder Kartenbewegung. |
| Kurz verlassen und zurück vor Neuberechnung | Keine Fortschrittsverkürzung durch den Umweg; nach eindeutiger Rückkehr wieder aktuelle Werte und normale Hinweise. |
| Lange verlassen; automatische Neuberechnung | Bestehende Hinweise und Versuchsgrenzen bleiben; nach erfolgreichem Routenwechsel nur Werte der neuen Route. |
| Netzfehler bei Neuberechnung; Netz kehrt zurück | Keine behauptete aktuelle Restzeit; Retry und Guidance erholen sich wie bisher. |
| Tracking pausieren, GPS-Ausfall, schlechter Fix, Sprung über 200 m | Keine extrapolierten Werte; nach Fortsetzen und zuverlässiger Zuordnung Erholung ohne dauerhaften Stillstand. |
| Rundweg, Kreuzung, Brücke, Hin-/Rückabschnitt | Kein Sprung zum späteren Routenvorkommen, kein falsches null am Start; Unsicherheit sichtbar und später wieder auflösbar. |
| Zwischenziel, Rückkehr hinter bisherigem Fortschritt | Noch offene Ziele bleiben berücksichtigt; erlaubte Korrektur darf Restwerte wieder erhöhen. |
| Manueller Refresh, Variantenwechsel, Abbruch | Kein veraltetes Ergebnis nach Wechsel/Ende; vorhandene Zustände und Aktionen bleiben zuständig. |
| Zielverbinder, Schieben, BRouter ohne Manöver | Kein erzwungenes null am Ende verkürzter Geometrie; keine erfundene Präzision oder Guidance. |
| Offline mit vorhandener Route | Lokale Restberechnung bleibt ohne Netz nutzbar, sofern die Positionszuordnung zuverlässig ist. Neue Offline-Routen werden dadurch nicht möglich. |
| Sperrbildschirm, Energiesparen, App-Rückkehr | Keine zusätzlichen Standortanforderungen; nach Rückkehr aktuelle Anzeige, unveränderte Hintergrundnavigation. |
| Große Schrift, Screenreader, eingeklappte Kopfzeile | Werte bleiben lesbar; keine ständig wiederholten Live-Ansagen bei Zahlenänderungen. |

Handy-/Beta-Schritte: Eine längere Route starten, mindestens zwei angezeigte
Distanz- und Minutenänderungen beobachten und einen Halt einlegen. Dann kurz
und länger abweichen, die Route wieder erreichen, Tracking unterbrechen und
fortsetzen. Netz für eine echte Neuberechnung ausschalten und anschließend
wiederherstellen. Einen Rundweg und eine Strecke mit gemeinsamem Hin-/Rückweg
und Zwischenziel fahren. Jeweils Ansagen, automatische Neuberechnung und
Energiesparen variieren; Bildschirm sperren und wieder öffnen. Erwartet sind
plausible Restwerte oder erkennbare Unsicherheit, anschließend Erholung,
keine neuen Meldungen auf der regulären Route und keine vorzeitige Ankunft.
Android und iOS getrennt prüfen; Laufzeit und Akku bei vergleichbarer Strecke
und Bildschirmnutzung vor/nach Umsetzung vergleichen.

## Vorhandene Tests und fehlender Nachweis

Gelesen wurden insbesondere:

- `test/ui/map/voice_guidance_test.dart`: kurze Abweichung, Wiederaufnahme hinter
  dem Fortschritt, Genauigkeit, nahe Ebenen, Überlappung, Zwischen-/Endankunft.
- `test/ui/map/navigation_recovery_test.dart`: Bewegungsbestätigung,
  GPS-Lücken/Sprünge, abgelaufene Timer, Retry und Wiederherstellung.
- `test/ui/map/route_variants_test.dart`: Standortfehler, verbleibende Stopps,
  Routenwechsel und veraltete asynchrone Ergebnisse.
- `test/ui/map/route_position_snapper_test.dart`: rein räumliches Snapping.
- `test/ui/map/map_overlay_accessibility_test.dart`: Darstellung der bisherigen
  Gesamtwerte, Pause und Ankunftsaktionen.
- API-Tests zu RadlNavi, BRouter und Schiebestrecken: Gesamtwerte und Geometrie.

Diese Tests belegen keine Implementierung von #189. Künftige Regressionstests
müssen zusätzlich Restwertkorrektheit, gültig/ungültig/erneut gültig,
Routenidentität, fehlende Zeitdaten, Zielverbinder, Überlappung und unveränderte
Routing-Anfragezahlen prüfen. Grundlage der Geräteabnahme ist auch die
[Navigations-Checkliste](../../CONTRIBUTING.md#regression-checklist).

## Verifikation des ursprünglichen Analyseauftrags

Nur diese Analysedatei wurde hinzugefügt; kein Anwendungscode geändert.
`git diff --check` ist erfolgreich; die neue, noch unversionierte Datei wurde
zusätzlich mit `git diff --no-index --check -- NUL <Datei>` erfolgreich geprüft.
Keine Dart-Formatierung erforderlich. Flutter-Analyse, Tests
und Builds wurden nicht ausgeführt: Trotz abgezogenem Handy zeigte die
Prozessprüfung noch einen VS-Code-`flutter run --machine --release` für diesen
Workspace. Es wurde kein Prozess beendet und kein paralleler Flutter-Befehl
gestartet. Bestehende Test-/Build-Angaben zu #257 sind keine Verifikation für
#189. Kein Commit, Push oder Pull Request für diesen Auftrag.

Eine knappe Zusammenfassung mit Empfehlung und Handy-/Beta-Abnahme wurde als
[AI-Kommentar im Issue](https://github.com/MunichWays/munich-ways-app/issues/189#issuecomment-6107451908)
veröffentlicht. Titel, Beschreibung und Status des Issues bleiben unverändert.

## Ursprüngliche Umsetzung auf `189-reststrecke-restzeit`, Version `3.2.1+77`

Die erste Ausbaustufe übernimmt das Projektionsergebnis des vorhandenen
`VoiceGuidance.display()`-Durchlaufs. Die geometrische Gesamtlänge stammt aus
demselben vorhandenen Durchlauf wie die entlang der Route gefahrene Länge.
Es gibt keine zweite GPS-Projektion für die Anzeige und keinen zusätzlichen
Routing-Aufruf. Gesamtdaten in `CycleRoute` bleiben unverändert.

`NavigationRemaining` enthält nur auf 0,1 km und ganze Minuten gerundete
Anzeigewerte samt Routenidentität. Die Restdauer ist proportional zur
verbleibenden Strecke geschätzt, sichtbar mit `≈` gekennzeichnet. Bis zu einer
auch geometrisch plausiblen endgültigen Ankunft bleiben die Werte mindestens
bei 0,1 km und einer Minute. Zwischenziele setzen die Anzeige nicht auf null.

Die ursprüngliche erste Ausbaustufe zeigte bei diesen Routen während der Navigation bewusst
`— km` und `— Min`: fehlende Guidance-Unterstützung, Zielverbinder, wiederholte
Geometriesegmente sowie längere Rundwege (über 100 m) mit Ziel höchstens zwei
Ankunftsradien vom Start entfernt. Diese vorsichtige Begrenzung gilt für die
gesamte jeweilige Route. Das zugrunde liegende Guidance-/Ankunftsverhalten wird
nicht erweitert; insbesondere repariert #189 keine vorbestehenden Probleme
bei der Ankunftserkennung auf Rundwegen ohne Zwischenziele.

Auch bei mehrdeutiger/off-route Position, Pause und während echter
Neuberechnung bleibt die Restanzeige ungültig. Der erste Positionsabgleich
eines GPS-Updates ist maßgeblich; weitere Guidance-Aufrufe für Recovery im
selben Update dürfen die Anzeige nicht nachträglich als eindeutig markieren.
Nach einer erfolgreichen Wiederaufnahme liefert der nächste eindeutige Fix
wieder Werte, gegebenenfalls auch höhere Restwerte bei Rückkehr hinter den
bisherigen Fortschritt.

`NavigationRemainingController` hält ausschließlich diese Darstellung und
eine einmalige Ablaufzeit, keine Navigationsfortschrittslogik. Ein Wert wird
spätestens 15 Sekunden nach seinem Standortzeitstempel ungültig, auch bei
ausgeschalteten Ansagen. Die bestätigte endgültige Null bleibt dagegen bis
zum Ende/Wechsel der Navigation erhalten. Gleiche gerundete Werte erneuern die Ablaufzeit ohne
UI-Benachrichtigung. Nur die Kopfzeile hört auf Änderungen. Routenwechsel,
Navigationsende und Rückkehr der App verwerfen alte Werte; die Kopfzeile prüft
zusätzlich Routenidentität und Pause. Es gibt keinen periodischen Timer und
keine zusätzlichen Hintergrund- oder Standortanforderungen.

Vor Navigationsstart bleiben Gesamtwerte erhalten. Während der Navigation
benennen Tooltips und Screenreader die Reststrecke, geschätzte Restfahrzeit
oder fehlende Verfügbarkeit. Zahlenänderungen sind keine Live-Ansagen.
Deutsche/englische Darstellung und große Schrift werden berücksichtigt.

Die Tests in `navigation_remaining_test.dart` und
`navigation_remaining_header_test.dart` prüfen die Schätzung, Stillstand der
Anzeige bei unveränderten Rundungswerten, Frischeablauf und Wiederherstellung,
Off-route/Wiederverankerung, Zwischen-/Endankunft, Routenidentität,
ausgeschlossene Geometrien, Pause, Laden, Sprache und große Schrift.
Verifikation mit dem gepinnten Flutter 3.47.6: Formatprüfung der sieben
geänderten/neuen Dart-Dateien und `git diff --check` erfolgreich;
`flutter analyze --no-pub` ohne Befund. Die sieben fokussierten Testdateien
(`navigation_remaining`, `navigation_remaining_header`, `voice_guidance`,
`navigation_recovery`, `route_variants`, `map_overlay_accessibility`,
`map_route_start_panel`) bestehen gemeinsam mit 120 erfolgreichen Tests,
darunter 24 neue Tests. Das lokale Protokoll liegt unter
`.local/189-focused-tests.log` und gehört nicht in den Commit.

Die Layouttests haben einen Überlauf durch das zusätzliche Schätzzeichen auf
schmalen Displays aufgedeckt. Die Werte können nun bei Bedarf umbrechen oder
untereinander stehen. Der bestehende Test für Ein-/Ausklappen prüft während
Navigation ohne Standort jetzt die nicht verfügbaren Restwerte statt der alten
Gesamtwerte. Die Tests der Guidance, Recovery und Routenvarianten bleiben
inhaltlich unverändert und erfolgreich.

Die vollständige Suite und Plattform-Builds wurden für diesen lokalen
Dart/UI-Umfang nicht ausgeführt; vor einem angeforderten Push bleibt die volle
Suite erforderlich. Handy-/Beta-Abnahme, iOS/Android-Hintergrundverhalten und
vergleichbare Akku-/Laufzeitmessungen bleiben offen. Die abschließende
Prozessprüfung zeigt keinen aktiven Flutter-Run, Analyse-, Test- oder
Gradle-Aufruf; nur ein langfristiger Java-Hintergrunddaemon ohne Workspacebezug
ist verblieben. Die Änderungen sind lokal; kein Commit, Push oder Pull Request.

### Verbesserung nach erfolgreichem Handytest

Der Nutzer hat den Test der ersten Ausbaustufe beendet und das erwartete
Verhalten bestätigt. Die anschließende Verbesserung ersetzt das Routensymbol
vor den Kilometern durch eine Zielfahne und hebt die pauschalen Ausschlüsse
oben auf. Reststrecke und geschätzte Restzeit beziehen sich auf das Ende der
berechneten Route. Ein anschließender Zielverbinder wird separat als
„Zielzugang: … m“ dargestellt; Tooltip und Screenreader benennen das Routenende.
Der Zielzugang ist eine geometrische Länge, keine neu berechnete Gehroute.

BRouter-Gesamtwerte beschreiben bereits die berechnete Route. RadlNavi/OSRM
enthält gegebenenfalls einen abgeschnittenen letzten Geh-/Schiebeabschnitt:
dessen Schrittstrecke und -zeit werden für die Navigationswerte abgezogen.
Fehlen diese optionalen Schrittmetriken, dient der geometrische Anteil als
Schätzung. Die Gesamtwerte der Routenplanung bleiben unverändert.

Auch ohne Sprachhinweise wird die vorhandene Geometrie mit derselben
Fortschrittsprojektion ausgewertet. Rundwege und wiederholte Segmente werden
nicht insgesamt ausgeblendet. Nur eine tatsächlich mehrdeutige/zu weit entfernte
oder veraltete Position, fehlende gültige Routendaten, Pause oder laufendes
Rerouting verhindern eine belastbare Angabe. Null bedeutet Erreichen des
gematchten Routenendes; das tatsächliche Ziel hinter dem Zugang wird dadurch
nicht als erreicht gemeldet. Endankunft an einer früheren Geometrie-Occurrence
wird nicht mehr allein durch die räumliche Nähe ausgelöst.

Die bereits bestätigte Geräteabnahme bezieht sich auf die erste Ausbaustufe.
Für die Verbesserung bitte RadlNavi mit finalem Geh-/Schiebezugang und BRouter
mit versetztem Ziel sowie ohne Sprachhinweise prüfen: Werte sinken bis zum
Routenende, Zugang bleibt separat, kein vorzeitiges „Ziel erreicht“. Zusätzlich
Rund-/Rückweg, GPS-Unterbrechung und anschließende Wiederaufnahme prüfen.

Verifikation der Verbesserung: Formatprüfung und `git diff --check` ohne
Befund; `flutter analyze --no-pub` ohne Befund. Die neun betroffenen Testdateien
bestehen mit 148 Tests. Die vollständige Suite besteht mit 624 erfolgreichen
Tests; nur der ausdrücklich zuschaltbare Live-API-Test
(`RADLNAVI_LIVE_TEST=true`) ist übersprungen. Protokolle liegen lokal unter
`.local/189-improvements-tests.log` und `.local/189-full-tests.log`.

Die erste Testausführung zeigte, dass ein GPS-Sprung ans Ziel trotz veraltetem
Fortschrittsfenster weiterhin als Ankunft erkannt werden muss. Der zusätzliche
globale Abgleich erfolgt nur im Ankunftsfall und bewahrt dieses Verhalten,
während eine frühere Ziel-Occurrence abgelehnt wird. Die vorhandenen Tests dazu
bleiben erhalten. Der Test der Beenden-Schaltfläche prüft deren Zielfahne nun
gezielt innerhalb des Buttons, da die Restanzeige dasselbe Symbol verwendet.

Keine Plattform-Builds und kein Live-API-Aufruf für diese Dart/UI-Änderung;
die neue Geräte-/Beta-Abnahme steht aus. Dokumentation und eigener AI-Kommentar
im Issue sind aktualisiert. Änderungen weiterhin uncommitted und ungepusht.

Die abschließende Prozessprüfung bestätigt: keine aktiven Flutter-Run-,
Analyse-, Test-, Build- oder Gradle-Client-Prozesse für diesen Workspace.
Verblieben sind Editor-/Hintergrunddienste ohne Workspacebezug.

### Rückmeldung vor dem angeforderten Commit/Push

Der Nutzer hat auch den Test der Verbesserung beendet und Commit/Push
angefordert. Zusätzlich wurden zwei Korrekturen gemeldet: Die Zielzugangszeile
verdeckt den Kompass teilweise, und Pause soll die bisherigen Zahlen behalten.

Ursache der Überdeckung ist der feste Abstand der seitlichen Bedienelemente.
Im Hochformat wird nun die tatsächliche Höhe des gesamten Routenpanels gemessen;
die Bedienelemente liegen oberhalb seiner Oberkante. Größenänderungen durch
Zielzugang, Schriftgröße und Ein-/Ausklappen werden berücksichtigt. Die bisherige
Querformatbegrenzung bleibt erhalten, um die Bedienelemente dort nicht aus dem
Bildschirm zu schieben. Stattdessen reserviert das Panel im Querformat seitlich
Platz für die Bedienelemente auf der jeweils gewählten Seite.

Pause friert die vorhandenen Anzeigewerte und deren Ablaufzeit ein. GPS-Updates
und schlechte Positionswerte überschreiben die eingefrorene Anzeige nicht.
Nach Fortsetzen gilt wieder die Standort-Frischeprüfung; ein neuer gültiger Fix
aktualisiert die Anzeige. Routenwechsel und Navigationsende löschen weiterhin
auch eingefrorene Werte. Regressionstests für Pause/Erholung und Panelwachstum
mit sichtbarem Kompass sind vorbereitet.

Beim vorherigen Versuch wurde der Analyseaufruf vor Commit/Push nicht ausgeführt: Die automatische
Freigabeprüfung meldete ein ausgeschöpftes Nutzungslimit. Die oben genannten
624 erfolgreichen Tests gehören zum vorherigen Stand und verifizieren diese
letzten Korrekturen nicht. Erneute Analyse und Tests, Commit und Push standen
zu diesem Zeitpunkt aus.

### Abschließende Verifikation vor Commit/Push

Der Nutzer hat den Handytest auch nach den letzten Korrekturen beendet,
das erwartete Verhalten bestätigt und Checks, Commit und Push beauftragt.
Das zuvor blockierende Nutzungslimit verhindert die Prüfungen nicht mehr.

Mit dem gepinnten Flutter 3.47.6 ist die Formatprüfung aller 14 geänderten/neuen
Dart-Dateien erfolgreich; `git diff --check` ist ohne Befund. Die statische
Analyse ist ohne Befund. Alle zehn betroffenen Testdateien bestehen gemeinsam
mit 151 Tests. Die vollständige Suite besteht mit 627 erfolgreichen Tests;
der ausdrücklich optionale Live-API-Test bleibt übersprungen. Lokale Protokolle:
`.local/189-commit-focused-tests.log` und `.local/189-commit-full-tests.log`.

Die neuen Tests verifizieren Pause über zwei Minuten, ausbleibende Updates in
Pause, Ablauf/Wiederaufnahme nach Fortsetzen und Löschen beim Routenende/-wechsel.
Der Layouttest verifiziert Panelwachstum und Einklappen im Hochformat sowie
freien Kompass auf beiden gewählten Seiten im Querformat. Der Testaufbau setzt
dafür sowohl die Viewgröße als auch die MediaQuery-Orientierung korrekt; der
Timer-Test lässt den nächsten Ereignistakt tatsächlich verstreichen. Die
bestehende Querformat-Erwartung berücksichtigt den reservierten Bedienbereich.

Keine Plattform-Builds und keine Live-API-Abfrage in diesem Auftrag. Die
bestätigte lokale Handyabnahme ersetzt keine gesonderten iOS-/Beta- oder
vergleichbaren Akku-/Laufzeitmessungen. Geprüfter Branch:
`189-reststrecke-restzeit`, Version `3.2.1+77`.
