# Neuinstallation: Beispielziele und spätere Einführung

## Schritt 1 – #217

Bei bisher leeren App-Daten fehlten Beispiele für Favoriten und letzte Ziele.
`RecentSearchesStore.load()` legte bei einer fehlenden Datei nur eine leere
Liste an. Ein eigener lokaler Karten-Layer für die Beispiele fehlte ebenfalls.

Neue Installationen erhalten einmal Green City e.V. und Unlock Escape als
Favoriten und letzte Ziele. Beide bleiben normale, umbenennbare und löschbare
Ziele; ein dritter Favoritenplatz bleibt frei. Es wird keine Route automatisch
berechnet oder gestartet. Die vorhandenen Such- und Auswahloberflächen bleiben
zuständig.

Die zwei Orte sind zusätzlich als beschriftete Stern-POIs ab Zoomstufe 12 auf
der Karte verfügbar, auch für bestehende Nutzer. Langer Druck und „Details
anzeigen“ öffnen die vorhandene Detailansicht mit Adresse, Webseite, OSM-Link
und „Route hierhin“. Löschen eines Favoriten entfernt den unabhängigen Karten-POI
nicht. Die Punkte benötigen keine Netzabfrage; Hintergrunddaten für Trinkwasser,
Toiletten, Servicestationen und Radlnetz bleiben unabhängig. Kartenkacheln und
Routenberechnung benötigen weiterhin ihre bisherigen Datenquellen.

### Daten und Update-Verhalten

- Vor dem Laden beziehungsweise Speichern von Einstellungen wird geprüft, ob
  bekannte Nutzerdaten existieren: Favoriten, letzte Ziele, gespeicherte Routen,
  aktuelle oder frühere Einstellungen. Auch leere oder beschädigte Dateien
  gelten als bestehende Installation und werden nicht überschrieben.
- `initial_places.json` speichert die Erststartentscheidung mit getrennten
  Feldern für die Vorbelegung und den Sicherheitshinweis. Die Ziel-Dateien
  bleiben die maßgebliche Quelle für die aktuellen Listen. Eine
  leere Liste oder fehlende Datei nach abgeschlossener Initialisierung führt
  nicht zur erneuten Vorbelegung.
- Bei einem abgebrochenen Erststart bleibt die Entscheidung als ausstehend
  gespeichert. Beim nächsten Versuch werden nur fehlende Dateien ergänzt;
  vorhandene Dateien bleiben unverändert. Schreiben erfolgt über eine temporäre
  Datei. Gleichzeitige Leser teilen sich denselben Initialisierungsvorgang.
- Speicherfehler werden protokolliert und verhindern den App-Start nicht. Ein
  späterer Listen-Zugriff versucht die Initialisierung erneut. Eine beschädigte
  Entscheidungsdatei löst vorsichtshalber keine neue Vorbelegung aus.
- Zurückgespielte App-Daten gelten als bestehende Installation. Eine Installation
  ohne jede erhaltene Nutzerdaten-Datei ist technisch nicht von einem wirklich
  neuen Nutzer unterscheidbar und erhält daher die Beispiele.

Quellen, geprüft am 09.10.2026:
[Issue #217](https://github.com/MunichWays/munich-ways-app/issues/217),
[Green City Kontakt](https://www.greencity.de/Kontakt/),
[Unlock Escape Kontakt](https://unlock-escape.de/kontakt/).
Die Koordinaten stammen aus dem von der App verwendeten Nominatim-Proxy:
[Green City, OSM-Knoten 1028507760](https://www.openstreetmap.org/node/1028507760)
und [Unlock Escape, OSM-Knoten 12163409668](https://www.openstreetmap.org/node/12163409668).
Listen und Karten-Layer verwenden dieselbe gebündelte Definition.

### Kartenkorrektur nach dem ersten Handytest

Die Favoriten wurden auf dem Handy bestätigt; die Karten-POIs waren nicht
sichtbar. Der neue Symbol-Layer kombinierte Stern und Namen, ohne `text-font`
festzulegen. MapLibre Native fordert dadurch den Standard-Fontstack
`Open Sans Regular,Arial Unicode MS Regular` an. Am Glyph-Server der aktiven
Karte lieferte dessen Datei `0-255.pbf` bei der Prüfung am 09.10.2026 HTTP 404;
`Roboto Regular`, das die Basiskarte bereits verwendet, lieferte HTTP 200.
Die verwendete Plugin-Version dokumentiert in ihrem Annotation-Manager, dass
fehlgeschlagene Glyph-Abfragen die Anordnung des gesamten Symbol-Layers
einschließlich Icon verhindern können.

Stern und Beschriftung bekommen deshalb getrennte Layer. Der Marker enthält
keine Text-Eigenschaften und benötigt keine Schriftdateien. Die Beschriftung
verwendet ausdrücklich `Roboto Regular`. Damit bleiben lokale Sterne auch
bei einer fehlenden oder noch nicht geladenen Schrift unabhängig sichtbar;
die Namen benötigen weiterhin geladene beziehungsweise zwischengespeicherte
Kartenschriften. Die Zoomgrenze 12 und der bisherige Detail-/Routingablauf
bleiben erhalten. Eine erneute Sichtprüfung auf dem Handy ist erforderlich.

## Schritt 2 – Sicherheitshinweis #209

Nach dem ersten Handytest gekürzte deutsche Fassung:

> **Entspannt unterwegs – mit offenen Augen**
>
> Achte auf dich und den Verkehr. Unsere Navigation kann Fehler enthalten.
> Beachte die Situation vor Ort und die Verkehrsregeln.
>
> [Nutzungsbedingungen](https://www.munichways.de/nutzungbedingungen-app/)
>
> **Los geht’s**

Für Englisch gibt es eine sinngemäße Übersetzung. Die Karte bleibt hinter dem
blickdichten Hinweis eingebunden und lädt Stil, Kacheln und Bewertungen bereits
während der Lesezeit. Beim Schließen wird diese Karteninstanz freigegeben;
es beginnt kein zweiter Kartenstart. Standortabfragen, Wiederaufnahme der
Standortsuche und die Meldung zur Bewertungsaktualisierung warten bis dahin.
Verdeckte Kartenaktionen sind für Touch, Fokus und Barrierefreiheit gesperrt.
Der Hinweis selbst benötigt weder GPS noch Netz. Titel, Text und Link scrollen
bei wenig Platz; Kreuz und Hauptaktion bleiben erreichbar.

Die vorhandene Erststarterkennung setzt für eine neue Installation zusätzlich
`safetyNoticePending: true`. Die Vorbelegung der Listen beendet nur ihr eigenes
Feld `pending`, nicht den Hinweis. Ältere oder bestehende Installationen ohne
das neue Feld erhalten den Hinweis bei einem normalen Update nicht nachträglich.
Kreuz, „Los geht’s“ und Android-Zurück beenden den Hinweis und speichern sein
Abschlussfeld. Dieser Speichervorgang blockiert das Öffnen der Karte nicht.
Bei einem Schreibfehler bleibt das gespeicherte Feld ausstehend; ein nächster
Start kann den Hinweis erneut zeigen. Ein App-Abbruch ohne Schließen, Wechsel
in den Hintergrund oder Öffnen des Links zählt nicht als Abschluss.

Die Nutzungsbedingungen öffnen im externen Browser. Kann das System den Link
nicht öffnen, erscheint eine kurze Fehlermeldung; der Link bleibt erneut
bedienbar. Ob die Webseite online erreichbar ist, entscheidet der Browser.
Es wird keine rechtliche Zustimmung erfasst: Die Aktionen schließen einen
Sicherheitshinweis.

Die bisherigen Handytests haben Favoriten, Karten-POIs, Detailansicht und den
Sicherheitshinweis bestätigt. Der Nutzer meldet den letzten Test als erfolgreich.
Danach wurde das bestehende MunichWays-Logo im Kopf des Hinweises ergänzt;
im Dunkelmodus werden wie im Infofenster die Buchstaben hell dargestellt.
Den anschließenden Handytest mit Logo hat der Nutzer ebenfalls als erfolgreich
bestätigt; der Testlauf ist beendet und USB abgezogen.

In „Legende & Tipps“ endet die Erklärung zur Zielauswahl jetzt mit „Die Route
wird berechnet.“ Der unzutreffende Zusatz zum sofortigen Navigationsstart
wurde auch in der englischen Fassung entfernt.

### Langsames Netz und erneutes Laden

Beim gemeldeten Fehler waren beide öffentlichen Dateien vom Rechner erreichbar;
der vollständige Bewertungsdownload (9,7 MB) dauerte 15,6 Sekunden. Das ist länger
als der bisherige Neuladen-Timeout von 6 Sekunden. Der erste App-Start erlaubte
30 Sekunden. Handylogs zeigten außerdem Timeouts für Kacheln, Schriften und
Kartensymbole; der Release-Lauf enthielt keine Dart-Logs für den Bewertungsfehler.
Ein Wechsel vom WLAN zu mobilen Daten löste den Fehler laut Nutzer nicht.
Die genaue Ursache auf dem Handy ist dadurch noch nicht vollständig belegt.

Start und Neuladen erlauben nun 90 Sekunden ohne weiteren Download-Fortschritt.
Fortschritt erneuert diese Wartezeit auch beim Aktualisieren eines vorhandenen
Cache-Eintrags. Lokale Asset-Daten und das Parsen fertiger Dateien bleiben
unabhängig von dieser Netz-Wartezeit. Auch langsame Downloads dürfen insgesamt
länger dauern, solange Daten ankommen. Ein vollständiger Verbindungsstillstand
endet weiterhin mit einer bedienbaren Karte und einer Möglichkeit zum Neuladen.

Neuladen validiert den vorhandenen Cache erneut, statt ihn vorher zu löschen.
Ein bereits laufender Ladevorgang wird gemeinsam abgewartet; es entstehen keine
konkurrierenden Bewertungsdownloads. Sind lokale Bewertungen verfügbar, meldet
die App nur die fehlgeschlagene Online-Aktualisierung. Speicherfehler, Offline-
Fallback und ein erneuter erfolgreicher Versuch dürfen die Karte nicht blockieren.

## Weiterführende Grobanalyse – Tutorial #144

Das Tutorial ist noch nicht implementiert. `main()` lädt lokale Einstellungen;
`MapScreen` erstellt Karte und Startfenster. Kartenstil, Standort und optionale
POI-Daten werden unabhängig geladen. Der Start nutzt bereits asynchrone Abläufe,
einschließlich einer verzögerten Kartenerstellung auf iOS. Eine Einführung sollte
deren Bereitschaft beobachten und keine zweite Karten- oder Navigationssteuerung
einführen.

Empfohlene Reihenfolge für die weitere Einführung:

1. Den in Schritt 2 implementierten Sicherheitshinweis beibehalten. Die Karte
   lädt bereits verdeckt; Standortabfragen warten bis zu seinem Schließen.
2. Danach ein kurzes, ausdrücklich überspringbares Tutorial anbieten. Beispiele:
   Ziel über einen vorbelegten Favoriten wählen, Suche und letzte Ziele öffnen,
   Route planen, Radl-Komfort erklären, Navigation und Einstellungen zeigen.
   Auswahl und Navigation bleiben echte Nutzeraktionen; das Tutorial startet
   keine Fahrt und benötigt keinen Standortzugriff auf Vorrat.
3. Tutorial über Hilfe/Info erneut erreichbar machen. Fehlende oder bereits
   gelöschte Beispiel-Favoriten mit einer neutralen Suchanleitung abfangen;
   keine Beispiele nachträglich wieder in Nutzerlisten einsetzen.

Hinweis und Tutorial brauchen getrennte persistente Abschlüsse. Die Vorbelegung
darf keinen der beiden Schritte als erledigt markieren. Ein gemeinsamer
Oberflächen-Koordinator verhindert überlappende Dialoge und führt nur aktive
Schritte fort. Wechsel in den Hintergrund, Schließen, Ablehnen einer Berechtigung,
Stilwechsel und Wiederaufnahme müssen definierte Übergänge behalten. Großschrift,
TalkBack/VoiceOver und kleine Displays sprechen für wenige Schritte mit klaren
Weiter-/Überspringen-Aktionen statt einer langen Folge automatisch wechselnder
Hervorhebungen.

Vor der Tutorial-Umsetzung klären: Umfang und angebotener Einstieg für
Bestandsnutzer. Allein das Fehlen eines neuen Tutorial-Flags darf bestehende
Nutzer nicht als Neuinstallation behandeln.
Die verlinkten Nutzungsbedingungen werden hier nur als Anforderung aus #209
übernommen; ihr rechtlicher Inhalt wurde nicht bewertet.

## Handy- und Betatest für Schritt 1

1. Mit wirklich leeren App-Daten starten, auch einmal im Flugmodus. Green City
   und Unlock Escape stehen im Startfenster als Favoriten und nach Öffnen der
   Suche unter „Letzte Ziele“. Nach Schritt 2 zuvor den Sicherheitshinweis schließen.
2. Online jeden Favoriten wählen, Route prüfen und Navigation bewusst starten.
   Zielpunkte liegen an Lindwurmstraße 88 beziehungsweise Westenriederstraße 41.
3. Zu beiden Orten auf der Karte zoomen; Sterne, Namen und Details prüfen.
   „Route hierhin“ führt zum gleichen Ziel wie der zugehörige Favorit. Bei einem
   ersten Offline-Start kann der Kartenhintergrund fehlen; die lokalen Ziele
   müssen dennoch auswählbar bleiben.
4. Einen Favoriten umbenennen, den anderen löschen und den Suchverlauf leeren.
   App vollständig beenden und erneut öffnen: Änderungen bleiben erhalten,
   gelöschte Beispiele kommen nicht zurück. Der Karten-POI bleibt verfügbar.
5. Update mit vorhandenen Favoriten und letzten Zielen testen, danach auch mit
   vorher bewusst geleerten Listen. Keine Beispiele werden hinzugefügt und
   vorhandene Einträge behalten Namen, Reihenfolge und Koordinaten.
6. Offline starten, Netz wieder einschalten und normal suchen beziehungsweise
   eine Route planen. Kein zusätzlicher Start ist zur Erholung erforderlich.
7. Hell/Dunkel wechseln und Hintergrund/Wiederaufnahme testen. Beispiel-POIs
   bleiben vorhanden. Startfenster und Detailansicht auf kleinem Display,
   mit 200 % Textgröße und TalkBack prüfen.

## Handy- und Betatest für Schritt 2

1. Mit wirklich leeren App-Daten online und im Flugmodus starten: zuerst erscheint
   genau der oben angegebene Hinweis. Karte und Bewertungen laden bereits im
   Hintergrund. Vor dem Schließen erscheint keine Standortberechtigungsabfrage,
   auch nicht nach einem Browserbesuch oder Hintergrundwechsel.
   „Los geht’s“ zeigt die bereits gestartete Kartenansicht
   mit den beiden vorbelegten Favoriten; die Standortabfrage folgt wie bisher.
2. App beenden und erneut starten: der geschlossene Hinweis erscheint nicht mehr.
   Ein normales Update mit bestehenden App-Daten darf ihn ebenfalls nicht zeigen.
3. Auf einer weiteren frischen Installation alternativ das Kreuz und Android-
   Zurück verwenden: beide öffnen die Karte und verhindern die Wiederholung.
4. Vor dem Schließen die App in den Hintergrund schicken, zurückkehren und dann
   vollständig beenden. Beim nächsten Start bleibt der noch nicht geschlossene
   Hinweis ausstehend; bloßes Anzeigen zählt nicht als Abschluss.
5. Den Link öffnen und vom Browser zurückkehren: der Hinweis bleibt sichtbar.
   Auch offline kann er unabhängig vom Browserergebnis mit „Los geht’s“ oder
   dem Kreuz geschlossen werden.
6. Deutsch/Englisch, Hell/Dunkel, Querformat, 200 % Text und TalkBack prüfen.
   Der Text ist scrollbar, beide Schließen-Aktionen bleiben erreichbar. Danach
   Standortzugriff erlauben oder ablehnen und die üblichen Such-/Routenaktionen
   ausprobieren; die App muss normal bedienbar bleiben.
7. Mit langsamer Verbindung und leerem Download-Cache starten. Hinweis eine
   Weile offen lassen und schließen: die Karte startet nicht erneut, lokale
   Bewertungen bleiben nutzbar und die Online-Ergänzung darf länger als
   30 Sekunden laden. Auch mehr als 90 Sekunden Gesamtdauer sind erlaubt,
   sofern fortlaufend Daten ankommen. Standort- und Suchaktionen bleiben nutzbar.
8. Verbindung während des Downloads unterbrechen, nach Ablauf der Wartezeit
   wiederherstellen und „Neu laden“ wählen. Lokale Bewertungen bleiben sichtbar;
   nach erfolgreicher Aktualisierung erscheinen die vollständigen Daten wieder.
   Mehrfaches Neuladen während eines laufenden Downloads erzeugt keine weiteren
   konkurrierenden Ladevorgänge. Mit vorhandenem Download-Cache auch offline
   neu starten und erneut laden: Cache und lokale Bewertungen bleiben nutzbar.
