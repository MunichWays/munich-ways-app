# #281 – Luftbilder und weitere Kartenansichten

Stand: 01.11.2026. Ausgangsanalyse auf App-Commit `e400afc`, Version `3.2.2+89`.
Die anschließend beauftragte App-Umsetzung hat Version `3.2.2+90`.
Branch: `feature/281-kartenansichten-analyse`.
Auftrag: Optionen untersuchen, dokumentieren und Umfang abstimmen.
Kostenrahmen und Bedienung sind abgestimmt. Maßgeblich ist die zuletzt
präzisierte Ausrichtung am vom Nutzer beschriebenen Apple-Bedienprinzip:
Kartenwahl vor der Navigation über das Kartensymbol. Der Auftrag umfasst
seit der anschließenden Freigabe auch die Umsetzung für die App in
diesem Branch. Nach erfolgreichem Handytest wurden Abschlussprüfung,
Commit und Push beider Feature-Branches am 01.11.2026 beauftragt.

## Bestätigter Umfang vom 01.11.2026

Der Nutzer hat im Anschluss an die Analyse festgelegt:

- Luftbilder für München/Bayern genügen; kostenfreie amtliche Bilder bevorzugen.
- Erster Schritt: MunichWays-App mit **Standard** und **Luftbild Bayern**.
- Die reduzierte Ansicht wird ausschließlich für RadlNavi benötigt.
  RadlNavi folgt in einem eigenen Schritt.
- Keine laufenden Anbietergebühren; regionale Abdeckung ist akzeptabel.
- Kartenwahl vor der Navigation über das Kartensymbol auf der Karte.
  Das Symbol ist vor der Navigation standardmäßig sichtbar.
- Während laufender Navigation bleibt die vorher ausgewählte Kartenart bestehen;
  die Kartentaste wird ausgeblendet und ein manueller Kartenwechsel ist gesperrt.
- Kartendialog mit zwei beschrifteten Vorschaubildern und unabhängigen
  Netzschaltern. Menüeintrag „Karten“ bleibt ein zusätzlicher Zugang vor der
  Navigation; er darf die Wechselsperre während der Navigation nicht umgehen.
- Kartenart, Netzsichtbarkeiten und Tastensichtbarkeit nach Neustart beibehalten.
- Für den späteren RadlNavi-Schritt bleibt das gewünschte reduzierte Kartenbild
  im Stil von Positron mit Radwegen und wichtigen Namen die fachliche Grundlage.
  Seine technische Umsetzung ist wegen des anderen Renderers separat festzulegen.

Daraus folgt als konkrete Anbieterempfehlung: OpenFreeMap für die bestehende
Standardkarte und Bayern-WMTS `by_dop` für Luftbilder. Die kostenpflichtigen
Alternativen unten dienen dem Vergleich und gehören nicht zum ersten Schritt.
Eine zusätzliche originale OSM-Carto-Ansicht ist in den bestätigten zwei
Ansichten nicht enthalten. Online-Luftbilder ohne Gebietsdownload bleiben eine
technische Empfehlung; ein Downloadfeature wurde nicht beauftragt.

## Ergebnis und empfohlene technische Lösung

Technisch sinnvoll ist, MapLibre in der App beizubehalten und zwei
Hintergründe anzubieten: **Standard** und **Luftbild Bayern**.
Die Standardkarte verwendet weiter OpenFreeMap; für Luftbilder ist der amtliche
bayerische WMTS der bevorzugte Kandidat. Damit ist eine zusätzliche Ansicht
ohne laufende Anbietergebühren möglich. Die reduzierte Karte entfällt in der App.
Flüssigkeit, Speicherbedarf und Wiederherstellung müssen auf Geräten geprüft
werden; ein erreichbarer Kacheldienst allein beweist keine gute App-Performance.

Für weltweite Luftbilder sind Esri, Mapbox und MapTiler Alternativen mit
Gratis-Kontingenten. Diese sind keine Zusage dauerhaft kostenloser Nutzung.
Eigener Betrieb vermeidet gegebenenfalls Abrufgebühren, bringt aber Kosten
für Speicher, Datenverkehr, Aktualisierung und Betreuung mit sich.

## Gewünschtes Verhalten aus dem Issue

[#281](https://github.com/MunichWays/munich-ways-app/issues/281) beschreibt:

- Die Nebenfunktion bleibt im Menü erreichbar, ohne dauerhaft prominente Taste.
- „Fahrradnetz auswählen“ wird zu einem Kartendialog mit Hintergrundvorschauen;
  der aktive Hintergrund ist sichtbar ausgewählt.
- Fahrradnetze werden unabhängig davon durch An-/Aus-Schalter gesteuert.
- Optional lässt sich eine Kartentaste oberhalb der Zoomtasten einblenden.
- Weitere Wünsche: reduzierte Karte wie Positron, OSM-Standard in der App
  und das Kartenbild der App in RadlNavi.

Diese Punkte sind der ursprüngliche Wunschkatalog. Für den aktuellen Umfang
gelten die oben festgehaltenen Präzisierungen: zwei Ansichten in der App,
Auswahl vor der Navigation, reduzierte Karte nur im späteren RadlNavi-Schritt.

## Ausgangslage vor der Umsetzung

- `lib/ui/map/map_screen.dart` lädt den gebündelten Liberty-Stil über
  `vector_basemap_constants.dart`, erzeugt mit `dark_map_style.dart` die
  angepasste Fahrrad-/Nachtkarte und übergibt das JSON an `MapLibreMap`.
  Verwendet wird `maplibre_gl 0.27.1`.
- Hauptquelle ist `https://tiles.openfreemap.org/planet`. Stil-JSON liegt in
  der App; Kacheln, Schriftzeichen und Symbole werden teilweise aus dem Netz
  geladen. Ein gebündelter Stil ist **keine gebündelte Offline-Grundkarte**.
  Es wurde kein eigener Downloadablauf für Offline-Kartenregionen gefunden.
- `assets/map/openfreemap_positron_style.json` ist bereits vorhanden.
  Es ist keine integrierte auswählbare Ansicht und wird für diesen App-Schritt
  nicht benötigt. Insbesondere fehlt der aktuell verwendete Layeranker
  `housenumber`; eine spätere Übernahme in RadlNavi wäre gesondert zu prüfen.
- Route, Bewertungen, Abdeckung, eigener Positionspunkt und POIs werden nach
  dem Stilaufbau separat hinzugefügt. Zahlreiche Overlays setzen den festen
  Anker `housenumber` voraus. Ein beliebiges fremdes Stil-JSON reicht deshalb
  für einen sicheren Wechsel nicht aus.
- Bei Hell-/Dunkelwechsel wird die native Karte absichtlich über eine neue
  Stilgeneration neu erstellt. Das verhindert konkurrierende native
  Stiloperationen. Bisherige Controller und Overlayzustände werden verworfen
  und anschließend aufgebaut. Neue Kartenarten müssen diesen Schutz erhalten.
- Die Startkamera verwendet `_savedInitialCamera`; für einen Wechsel muss
  der **aktuelle** Ausschnitt einschließlich Zoom, Richtung und Neigung
  explizit übernommen werden. Sonst droht ein Sprung zu einem älteren Zustand.
- Menüweg: `SettingsSheetContent` → `BikenetSelectionSheet` → bestehende
  Netzschalter im `MapScreenViewModel`. Die beiden Netzsichtbarkeiten sind
  aktuell flüchtig. Kartentyp und konfigurierbare Kartentaste wären neue Einstellungen
  im vorhandenen `SettingsStore`, mit verträglichen Standardwerten bei Updates.
- `MapSideActionButtons` enthält Zoom-, Kompass- und Standorttaste und folgt
  der gewählten Bildschirmseite. Eine Kartentaste muss auch bei ausgeblendeten
  Zoomtasten erreichbar bleiben.
- `MapAttribution` enthält derzeit feste OpenFreeMap-/OSM-/OpenMapTiles-Angaben
  und kann ausgeblendet werden. Neue Quellen benötigen passende, im Kartenbild
  zugängliche Angaben; für den Bayern-WMTS sind sie bei jeder Darstellung
  vorgeschrieben. Die native Attribution ist derzeit außerhalb des Bildes.

Relevante vorhandene Tests: `vector_basemap_style_test.dart`,
`dark_map_style_test.dart`, `map_screen_model_test.dart`,
`map_screen_layout_test.dart`, `map_overlay_accessibility_test.dart`,
`settings_sheet_content_test.dart`, `settings_data_test.dart` und
`map_attribution_test.dart`. Sie decken noch keinen neuen Kartentyp ab.

## Anbieter und Kosten

Alle Angaben sind am 01.11.2026 recherchiert; vor einer Einführung erneut prüfen.
Kostenfreiheit des Kartenanbieters umfasst weder Entwicklung noch Mobilfunkdaten.

| Option | Kosten / Bedingungen | Abdeckung und Eignung |
| --- | --- | --- |
| OpenFreeMap, Standard und reduziert | Öffentliche Instanz kostenlos, ohne Schlüssel und ohne Abrufkontingent; keine Verfügbarkeitsgarantie. | Weltweite OSM-Vektorkarte. Beste Wahl für zusätzliche Kartenstile; liefert hier keine hochauflösende Luftbildquelle. [Anbieter](https://openfreemap.org/), [Bedingungen](https://openfreemap.org/tos/) |
| Bayern-WMTS `by_dop` | Kostenfreier OpenData-Dienst; erforderliche Quellenangaben beachten. Keine garantierte ständige Verfügbarkeit. | Luftbilder für Bayern, vorkonfigurierte Rasterkacheln. Bevorzugte regionale Lösung. [Dienst](https://geodatenonline.bayern.de/geodatenonline/seiten/wmts_ba), [OpenData](https://www.geodaten.bayern.de/opengeodata/), [Nutzung](https://geodaten.bayern.de/odd/m/3/pdf/WMTS_Nutzungshinweise.pdf) |
| Bayern-WMS DOP20 | Kosten-/registrierungsfrei, CC BY 4.0. | Bayern; 20-cm-Orthophotos. EPSG:3857 unterstützt. Technische Alternative, falls der WMTS ungeeignet ist; dynamische Bildberechnung ist gegenüber fertigen Kacheln voraussichtlich ungünstiger. [Dienst](https://geodatenonline.bayern.de/geodatenonline/seiten/wms_dop20cm), [Einführung](https://geodaten.bayern.de/odd/m/3/pdf/newsletter_archiv/2024_04.pdf) |
| Esri ArcGIS Location Platform | 2 Mio. Basemap-Kacheln monatlich frei, darüber 0,15 USD/1.000. Konto/Authentifizierung und Attribution erforderlich. | Weltweite Bilddaten als Kandidat; genaue Bildquelle, Cache-/Offline-Rechte und Kontingentbegrenzung vor Auswahl prüfen. Kein kostenloser Direktzugriff allein aufgrund einer öffentlich erreichbaren World-Imagery-URL. [Preise](https://developers.arcgis.com/pricing/), [MapLibre-Anbindung](https://developers.arcgis.com/maplibre-gl-js/data/add-a-map-tile-layer/) |
| Mapbox Raster Tiles API | 750.000 Rasterkacheln monatlich frei; danach zunächst 0,25 USD/1.000, weitere Mengenstaffeln. Token und Anbieterbedingungen erforderlich. | Weltweite Satellitenquelle; Raster-Tile-API separat vom Mobile-SDK-Tarif kalkulieren. [Preise](https://www.mapbox.com/pricing), [Raster-API](https://docs.mapbox.com/api/maps/raster-tiles/) |
| MapTiler Cloud | Free: 100.000 API-Requests/Monat, nicht kommerziell bzw. Entwicklung; Logo erforderlich. Flex: ab 30 USD/Monat, 500.000 Requests, Mehrabrufe 0,15 USD/1.000; ohne MwSt. | Weltweite Satellitenkarte. Bei MapLibre nicht die beworbenen SDK-Sessions als App-Nutzung ansetzen. Ob MunichWays unter Free fällt, ist vor Auswahl zu klären. [Preise](https://www.maptiler.com/cloud/pricing/), [Bedingungen](https://www.maptiler.com/terms/cloud/) |
| Originaler OSM-Standard, OSMF-Server | Keine Abrufrechnung für regelkonforme interaktive Nutzung, aber begrenzte Infrastruktur, kein SLA, Sperren möglich. | Originales OSM-Carto-Bild weltweit. Identifizierbarer Client, sichtbare Attribution und HTTP-Cache nötig. Keine Offline-Downloads oder Gebiets-Vorabrufe. [Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/) |
| Eigene Luftbildkacheln aus OpenData | Daten können kostenfrei sein; Hosting, Verarbeitung, Aktualisierung und Betrieb kosten Geld/Zeit. | Für ein begrenztes Gebiet möglich, für diese Nebenfunktion zunächst unverhältnismäßiger Betriebsaufwand. |

Rechenbeispiel zur Größenordnung, **keine Nutzungsprognose**: 1.000 Nutzer ×
4 Luftbildnutzungen pro Monat × 100 neue Kacheln pro Nutzung = 400.000 Abrufe.
Das übersteigt MapTiler Free; es liegt innerhalb der genannten Esri-/Mapbox-
Kontingente. Fahrtdauer, Zoomwechsel, Bildschirmgröße, Cachetreffer und zusätzliche
Beschriftungskacheln verändern die Zahl erheblich. Ohne Messung ist eine belastbare
Kostenschätzung nicht möglich. Ein lokaler Zähler je Handy begrenzt kein gemeinsames
Anbieterkonto; eine harte Kostenobergrenze muss beim Anbieter oder zentral gelten.

## Technische Prüfung des Bayern-WMTS

Die [Capabilities](https://geoservices.bayern.de/od/wmts/geobasis/v1/1.0.0/WMTSCapabilities.xml)
wurden am 01.11.2026 direkt gelesen. `by_dop` liefert JPEG, Matrixsatz `smerc`
verwendet EPSG:3857, 256 × 256 Pixel und Zoomstufen 0–19 mit üblicher
XYZ-Matrixgröße. Ein aus den Metadaten abgeleitetes URL-Muster ist:

```text
https://wmtsod1.bayernwolke.de/wmts/by_dop/smerc/{z}/{x}/{y}
```

Genau eine Münchner Kachel (`16/34873/22743`) antwortete mit HTTP 200,
`image/jpeg`, 20.613 Byte und `Cache-Control: public, max-age=86400`.
Der Einzelabruf dauerte 207 ms aus dieser Arbeitsumgebung. Das ist ein
Erreichbarkeitsbeleg, kein Geräte-, Mobilfunk- oder Performance-Benchmark.
Weitere Hostnamen sind in den Capabilities vorhanden; zusätzliche parallele
Abrufe über alle Hosts sind für die erste Umsetzung nicht erforderlich.

Der Layer kombiniert regionale Orthophotos bei hohen Zoomstufen mit
Satellitenbildern bei niedrigen Zoomstufen. Es sind keine Livebilder.
Die Quellenangaben umfassen BVV, EU/Copernicus und BKG und müssen entsprechend
der verlinkten Nutzungshinweise übernommen werden. Die Metadaten-Boundingbox
ist ein Rechteck, keine exakte bayerische Abdeckungsmaske. Die App zoomt bis 22;
oberhalb Quellzoom 19 wären vorhandene Bilder zu vergrößern, ohne neue Details.

MapLibre kann [Rasterquellen](https://maplibre.org/maplibre-style-spec/sources/)
darstellen; auch das Flutter-Plugin bietet
[RasterSourceProperties und Rasterlayer](https://github.com/maplibre/flutter-maplibre-gl/blob/main/website/docs/layers/various-sources.md).
Ein neuer Kartenrenderer ist dafür nicht nötig. Die funktionierende Einbindung
in genau diese Android-/iOS-App steht dennoch aus.

## Umsetzungsmöglichkeiten und Aufwand

Die folgenden Aufwände sind relative Einschätzungen, keine Terminzusagen.

| Variante | Nutzen | Aufwand / Risiko |
| --- | --- | --- |
| App: Standard + Luftbild Bayern, Wahl vor der Navigation | Bestätigter Umfang, regional ohne Anbietergebühren. | Rasterquelle, Beschriftung, Abdeckung, Attribution, Speicherung und zuverlässige Wechselsperre. Gerätetests für Navigation mit beiden Hintergründen bleiben erforderlich. |
| RadlNavi: reduzierte Karte | Bewertungen und Vorrangnetz leichter erkennen. | Eigener späterer Schritt; Darstellung und Integration für Leaflet prüfen. |
| Weltweites Luftbild | Einheitliche Auswahl über Bayern hinaus. | Vergleichsoption außerhalb des aktuellen Umfangs: zusätzlich Konto, Kostenkontrolle, Rechte und Anbieterintegration. |
| Original-OSM und App-Kartenbild in RadlNavi | Weitere Wünsche aus dem Issue. | Zusätzliche Umfänge über zwei Repositories und unterschiedliche Renderer; getrennte Abnahmen sinnvoll. |

Für die App ist keine reduzierte Variante zu implementieren. Der vorhandene
Positron-Stil bleibt unberührt. Für RadlNavi dient Positron später als optische
Referenz: Radwege und wichtige Namen erhalten, störende Flächen/POIs reduzieren.
Weniger gezeichnete Details können Renderaufwand senken, verkleinern aber bei
gleicher Quelle nicht automatisch die Vektorkacheln. Ein MapLibre-Stil lässt
sich wegen des Leaflet-Renderers nicht direkt als RadlNavi-Hintergrund einsetzen.

Luftbilder sollten als einzelne Rasterquelle mit sparsamem Beschriftungssatz
laufen. Helle Konturen müssen Route und Netzfarben vom Bild abheben. Ein
zusätzlicher amtlicher Beschriftungslayer wäre möglich, würde aber weitere
Kacheln und eigene Quellenangaben benötigen. Für den ersten Schritt sind
ausgewählte vorhandene Vektorlabels vorzuziehen, sofern Gerätetests ihre
Lesbarkeit bestätigen.

Für Kartenarten den bestehenden Stilwechsel mit Generation und Neuaufbau
verwenden; vorher die aktuelle Kamera sichern. Dynamisches Austauschen von
Layern könnte später Wechsel beschleunigen, würde aber die absichtlich vermiedenen
Konkurrenzprobleme neu öffnen. Mehrere gleichzeitig laufende native Karten für
Vorschauen erhöhen Speicher- und Renderbedarf; statische, lokal gespeicherte
Vorschaubilder mit korrekten Quellenangaben sind einfacher.

## Bestätigte Bedienung

- Vor der Navigation öffnet das standardmäßig sichtbare Kartensymbol auf der
  Karte den Kartendialog. Position: oberhalb der Zoomgruppe auf der gewählten
  Bildschirmseite, auch bei ausgeblendeten Zoomtasten erreichbar.
- Dialog mit zwei beschrifteten Vorschaubildern „Standard“ und „Luftbild Bayern“;
  genau ein Hintergrund ist aktiv. Darunter unabhängige Netzschalter.
- Menüeintrag „Karten“ öffnet vor der Navigation denselben Dialog. Eine vorhandene
  Einstellung „Kartentaste anzeigen“ kann die Taste weiterhin optional verbergen;
  der Standardwert wird sichtbar. Der Menüweg hält die Auswahl erreichbar.
- Kartenart, beide Netzsichtbarkeiten und Tastensichtbarkeit speichern und nach
  Neustart wiederherstellen.
- Nach Navigationsstart die gewählte Kartenart beibehalten und Kartensymbol
  ausblenden. Während der Navigation über keinen Zugang manuell wechseln.
  Eine Pause gibt die Auswahl nicht wieder frei; nach vollständigem Beenden
  der Navigation wird sie erneut verfügbar.
- Die Sperre gilt für die Auswahl des Hintergrunds. Ein systembedingter
  Hell-/Dunkelwechsel darf die ausgewählte Kartenart nicht zurücksetzen.

## Technische Empfehlungen für Darstellung, Ausfälle und Offline-Verhalten

Die folgenden Details konkretisieren die Lösung als technische Empfehlungen:

- Auswahl durch Text und Symbol kenntlich machen, zusätzlich farbig umranden.
  Dialog bei großer Schrift und im Querformat scrollbar halten.
- Unbekannte gespeicherte Kartenart fällt bei App-Updates auf Standard zurück.
  Für alte Einstellungsdateien gilt bei fehlenden Werten: Standardkarte,
  beide Netze an, Kartentaste sichtbar. Bereits gespeicherte Werte erhalten.
- Luftbilder bei Nacht als Luftbilder belassen; Bedienelemente und Beschriftungen
  dem Thema anpassen. Ein Abdunkeln der Fotos wäre eine zusätzliche Option.
- Standardkarte außerhalb des Luftbildgebiets sichtbar halten, wo deren Daten
  verfügbar sind; regionale Beschränkung im Dialog nennen. Rechteckige Grenzen
  allein reichen an der Landesgrenze nicht für eine sichere Verfügbarkeitsprüfung.
- Fehler einzelner Kacheln nicht mit einem kompletten Stil-Ausfall verwechseln.
  Vor der Navigation bleibt die Rückkehr zu Standard möglich. Während der
  Navigation darf ein Quellfehler Ansagen, Route, GPS oder Neuberechnung nicht
  blockieren. Er begründet keinen zusätzlichen manuellen Kartenwechsel.
  Keine endlosen automatischen Stilwechsel; normale Kachelwiederherstellung nach
  Netzwiederkehr bleibt von der gesperrten Kartenwahl unabhängig.
- Vor Navigationsstart gewählten Hintergrund vollständig übernehmen. Wird bei
  offenem Kartendialog Navigation gestartet, den Dialog schließen und veraltete
  Auswahlaktionen verwerfen. Ein laufender Stilaufbau darf nicht durch einen
  zweiten Kartenwechsel überholt werden. Verspätete Antworten der vorherigen
  Stilgeneration dürfen die neue Karte nicht verändern. Während Navigation die
  Kartenauswahl im zuständigen Zustand sperren, nicht nur die Taste verstecken.
- Zunächst Online-Luftbilder mit gewöhnlichem Cache, ohne Gebietsdownload.
  Ein Cache garantiert keine vollständige Offline-Karte. Auch die Standardkarte
  kann ohne vorher geladene Kacheln offline unvollständig sein; Netz-/Routendaten
  und ihre vorhandenen lokalen Rückfälle bleiben davon unabhängig.

OpenFreeMap erlaubt aktuell Offline-Downloads bis „3.000 Kacheln oder 50 MB“
je Download, höchstens vier parallele Requests und einen eigenen User-Agent;
größere Downloads erfordern Kontakt. Die genaue Grenzanwendung vor einem
Downloadfeature klären. Das ist kein Bestandteil des vorgeschlagenen ersten
Schritts. [Quick Start](https://openfreemap.org/quick_start/),
[Bedingungen](https://openfreemap.org/tos/).

## Besonderheit RadlNavi

Die reduzierte Ansicht gehört nach der Präzisierung ausschließlich in diesen
späteren Produktumfang. Der App-Schritt enthält dafür keine Stiländerung.

Der zusätzlich gelesene Stand im
[separaten Repository](https://github.com/MunichWays/munichways-radlnavi)
verwendet laut `frontend/package.json` React-Leaflet 4.2.1 mit Leaflet-Rotate.
`frontend/src/App.tsx` bindet OSM-Standard als Raster-`TileLayer` ein.
Das Kartenbild der App ist dagegen ein MapLibre-Vektorstil und kann nicht
direkt als Leaflet-Raster-URL eingesetzt werden.

Amtliche Luftbildkacheln wären als weiterer Leaflet-Hintergrund grundsätzlich
einfacher ergänzbar. Für das App-Kartenbild kommen infrage:

1. MapLibre über eine Leaflet-Integration ergänzen; Drehung, Gesten, Überlagerungen
   und zusätzliche Renderkosten eigens prüfen.
2. Den Hintergrund auf MapLibre umstellen; größerer Umbau mit Abnahme der
   bestehenden RadlNavi-Funktionen.
3. Den App-Stil serverseitig zu Rasterkacheln rendern; zusätzlicher Betrieb.

Die [OpenFreeMap-Anleitung](https://openfreemap.org/quick_start/) nennt eine
Leaflet-Integration. Daraus folgt noch keine Kompatibilität mit der vorhandenen
Drehfunktion. Empfehlung: RadlNavi als getrennten Umsetzungsschritt behandeln.
Für mögliche gemeinsame Browserquellen sind außerdem CORS und Browsercache
zu prüfen; ein erfolgreicher nativer HTTP-Abruf bestätigt das nicht.

## Ergebnis der Detailabstimmung

Maßgeblich ist die anschließende Präzisierung vom 01.11.2026. Die vorherige
Abstimmung zu drei App-Ansichten und zum Wechsel während der Navigation wird
dadurch ersetzt:

1. App mit Standard und Luftbild Bayern. Reduzierte Ansicht nur für RadlNavi.
2. Auswahl vor der Navigation über das Kartensymbol; während der Navigation
   keine manuelle Umschaltung, auch nicht über das Einstellungsmenü.
3. Auf ausdrückliche Nachfrage bestätigt: Kartensymbol vor der Navigation
   standardmäßig sichtbar; während der Navigation ausgeblendet.
4. Die Speicherung von Kartenart, Netzsichtbarkeiten und konfigurierter
   Tastensichtbarkeit bleibt Bestandteil des Konzepts.

Die für den ersten Schritt abgefragten Produktentscheidungen sind damit geklärt.
Die App-Umsetzung wurde danach ausdrücklich in diesem Branch und ohne Commit
beauftragt. Sie enthält Straßennamen auf Luftbildern, gewöhnlichen Kachelcache
ohne Offline-Gebietsdownload und die Standardkarte unter der regionalen
Luftbildquelle. Eine vollständige Offline-Karte ist nicht zugesagt.

Für einen späteren Schritt bleibt zu klären, ob „OSM Standard“ das originale
OSM-Carto-Kartenbild meint. Die App nutzt bereits OSM-Daten; Original-OSM
und die Übernahme des App-Kartenbilds in RadlNavi sind zusätzliche Umfänge.

## Abnahme nach einer späteren Umsetzung

Am Handy vor Navigationsstart: Kartendialog über das standardmäßig sichtbare
Kartensymbol öffnen, beide Ansichten auswählen und mehrfach wechseln;
derselbe Ausschnitt, Route, Zwischenziele, Bewertungen, POIs und Position bleiben
erhalten. Beide Netze einzeln und gemeinsam ein-/ausschalten. App neu starten,
Hell/Dunkel wechseln, große Schrift, Screenreader, Querformat, Tasten links/rechts
und ausgeblendete Zoomtasten prüfen.

Mit schlechtem Netz und Flugmodus vor der Navigation testen: nach vorheriger
Nutzung und nach frischem Start; Dialog und Rückkehr zu Standard bleiben bedienbar, vorhandene
lokale Netz-/Routendaten bleiben erhalten. Netz wieder einschalten und Luftbild
erneut wählen. Auch Karten außerhalb Bayerns, Randbereiche, Zoom 19–22 und
Quellfehler prüfen. Eine weiterhin leere Kachel darf die App nicht blockieren.

Je eine Navigation mit vorher gewählter Standardkarte und mit Luftbild starten.
Kartensymbol muss verschwinden; über das Menü darf kein manueller Wechsel
möglich sein. Pause/Fortsetzen, Neuberechnung und Hell-/Dunkelwechsel dürfen die
gewählte Kartenart nicht ändern. Kartenverfolgung und Ansagen prüfen; Display
aus/an, Hintergrund/Vordergrund sowie Netzausfall und Netzwiederkehr wiederholen.
Auch mit weiterlaufenden Ansagen bei fehlenden Luftbildkacheln muss sich die App
nach Netzwiederkehr normal erholen. Navigation vollständig beenden: Kartensymbol
erscheint entsprechend der gespeicherten Tasteneinstellung und Auswahl ist
wieder möglich. Android insbesondere auf den von #282 betroffenen Geräten
sowie ein iPhone prüfen.

Performance im Profilmodus gegen dieselbe Fahrt mit Standardkarte vergleichen:
Kalt-/Warmstart, Zeit bis zum ersten nutzbaren Kartenbild, Wechselzeit,
Gestenflüssigkeit, Speicher, Datenverbrauch, Erwärmung und längere Navigation.
Erst danach eine Aussage zu flüssiger Nutzung oder Kostenerwartung treffen.

Technisch: Regressionstests für Auswahl/Persistenz, alte Einstellungsdateien,
Wechselsperre während Navigation einschließlich Pause und alternativer Zugänge,
Dialogschließen bei Navigationsstart, erneute Freigabe nach Navigationsende,
Layerreihenfolge/Anker, verspätete Stilantworten, Kameraerhalt und Fehlererholung
ergänzen. Danach geändertes Dart formatieren, `git diff --check`, sequenziell
`flutter analyze --no-pub` und fokussierte Tests; vor einem beauftragten Push
vollständige Testsuite. Keine parallelen Flutter-Befehle oder Checks während
eines aktiven Handylaufs.

## Lokale App-Umsetzung

Die Standardkarte erhält für die gewählte Luftbildansicht eine zusätzliche
Rasterquelle aus dem Bayern-WMTS, unterhalb der unveränderten Anker für Route,
Netze und Beschriftung. Lesbare Textkonturen werden angepasst. Die Standardkarte
bleibt darunter erhalten, auch wenn Luftbildkacheln noch nicht geladen sind.
Die Quellgrenze folgt der veröffentlichten rechteckigen Boundingbox; sie ist
keine exakte Landesgrenze. Randbereiche und die tatsächliche Wiederherstellung
nach Netzausfall sind deshalb ausdrücklich am Gerät zu prüfen.

Der vorhandene sichere Stil-Neuaufbau wird weiterverwendet, mit übernommenem
aktuellem Kameraausschnitt und Schutz vor überholten Ladeantworten/Kameracallbacks.
Kartenwahl wird im ViewModel bei laufender Navigation, Pause und ausstehendem
Navigationsstart abgewiesen. Der Dialog schließt bei Navigationsstart; der
Menüzugang verwendet dieselbe Sperre. Nach Navigationsende ist die Auswahl frei.

Kartenart, beide Netzsichtbarkeiten und Tasteneinstellung werden im vorhandenen
SettingsStore gespeichert. Frühe Änderungen dürfen durch verspätet geladene
Einstellungen nicht überschrieben werden; andere gespeicherte Kartenoptionen
werden dabei erhalten. Die Kartentaste ist standardmäßig sichtbar, unabhängig
von der Sichtbarkeit der Zoomtasten. In kurzen Fenstern werden die zusätzlichen
Bedienelemente kompakt angeordnet, ohne die 56-Pixel-Tastflächen zu verkleinern.

Der Dialog verwendet eine lokal gezeichnete schematische Standardvorschau und
die lokal gespeicherte amtliche Luftbildkachel
`images/map_preview_aerial.jpg` (Quelle: oben dokumentierter Einzelabruf,
`16/34873/22743`). Er startet keine weiteren Kartenrenderer oder Vorschauabrufe.
Die amtliche Quellenangabe bleibt als horizontal lesbare Zeile im Dialogkopf
sichtbar und wird auch auf der Luftbildkarte bei geschlossenen Quellendetails
eingeblendet. Große Schrift verdrängt dadurch nicht die Kartenbedienung.

Buildnummer auf `3.2.2+90` erhöht; keine neue Abhängigkeit, keine Änderung an
RadlNavi. Regressionstests ergänzen Speicherung, Schreibfehler-Erholung,
verzögertes Laden, Kartenstil/Anker, Navigationssperre, Kameraerhalt,
Themenwechsel, Querformat und große Schrift.

## Verifikation der lokalen Umsetzung

- Geänderte Dart-Dateien mit dem gepinnten SDK formatiert; `git diff --check`
  ohne Befund.
- `flutter analyze --no-pub` mit Flutter 3.47.6: keine Befunde.
- 79 fokussierte Tests erfolgreich, darunter Kameraerhalt, überholte
  Kartenantworten, große Schrift/Querformat, Navigation einschließlich Pause,
  Erholung nach Schreibfehlern und Zusammenführung verzögert geladener Optionen.
- Vollständige Suite: 876 Tests erfolgreich, ein standardmäßig deaktivierter
  optionaler RadlNavi-Livetest übersprungen.
- Doppeltipp auf Start löste im ergänzten Test eine doppelte Startansage aus;
  der Startknopf weist einen erneuten Start einer bereits begonnenen Navigation
  nun ab. Bestehende Fortsetzen-/Neuberechnungswege bleiben eigenständig und
  sind mit der Suite geprüft.
- Kein APK-/iOS-Build erstellt, keine Installation und keine nativen Geräte-,
  Leistungs- oder Mobilfunkprüfungen ausgeführt. Die obige Handycheckliste bleibt
  deshalb erforderlich; Widgettests ersetzen keinen nativen Kartenrenderer.

Der Nutzer meldete den Handytest am 01.11.2026 als erfolgreich beendet.
Der genaue Umfang der einzelnen Geräteszenarien wurde dabei nicht protokolliert.
Ein neuer automatisierter APK-/iOS-Build ist nicht Teil der Abschlussprüfung.

## Anschließend bestätigter RadlNavi-Umfang

Im separaten Repository wurde `feature/281-reduced-basemap` mit Frontend-Version
`2.4.0` umgesetzt: Kartenlayer-Symbol rechts oben zwischen Zoom und Legende,
Auswahl **Standard** und **Dezent**, Speicherung der Auswahl im Browserspeicher.
Der Nutzer hat ausdrücklich die einfache Variante Dezent bestätigt: vorhandene
OSM-Grundkarte aufhellen und entsättigen, Bewertungen und Route farbig lassen.
Beschriftungen werden nicht entfernt; es ist kein Positron-Stil und keine neue
Kartenquelle. Keine zusätzlichen Kachelabfragen oder Anbietergebühren.
Die frühere Positron-Empfehlung ist für diesen Schritt damit ersetzt.

RadlNavi-Implementierung und konkrete Browsertestschritte stehen in
`frontend/README.md` des separaten Branches. Eine manuelle Browserabnahme
steht noch aus; die erfolgreiche Handyabnahme betrifft die Flutter-App.

## Abschlussprüfung vor Commit und Push

Am 01.11.2026 erneut geprüft: 14 geänderte Dart-Dateien formatkonform,
`git diff --check` sauber, Flutter 3.47.6 Analyse ohne Befund, 38 fokussierte
Tests und vollständige Suite mit 876 erfolgreichen Tests. Ein optionaler
RadlNavi-Livetest bleibt standardmäßig deaktiviert. Alle 16 Python-Tests des
CI-Versionsschutzes sind nach Einrichtung der isolierten lokalen Testumgebung
erfolgreich.

RadlNavi: TypeScript-Prüfung, Lint der neuen Dateien und bestehender
Detailmodule erfolgreich; 103 Frontend- und vier Datenaufbau-Tests erfolgreich.
Produktionsbuild erfolgreich mit bestehenden Warnungen in `App.tsx` und
`routeTransfer.ts` sowie veralteter Browserslist-Datenbank. Kein Deployment.
