# #245 – Erste Erweiterung der Adresssuche

Stand: 9. Oktober 2026. Branch: [`b74_Erweiterugen`](https://github.com/MunichWays/munich-ways-app/tree/b74_Erweiterugen).

## Umsetzung

Die vorhandenen Suchanbieter und der Standortbezug bleiben erhalten.
Die Originalschreibweise wird zuerst gesucht. Erst bei leeren Ergebnissen
werden Wortgrenzen in Schreibweisen wie `GreenCity` getrennt und Varianten der Vereinsform
`ev`, `e V` und `e.V.` nach einem Namen als `e.V.` vereinheitlicht.
Überzählige Leerzeichen werden für alle Anfragen bereinigt.
Hausnummern, Postleitzahlen, Umlaute, Bindestriche und Ortsangaben bleiben
Teil der gesendeten Adresse. Namen werden nicht pauschal ohne Leerzeichen
oder Sonderzeichen als Suchanfrage versendet.

Bei einem Namen aus genau zwei alphabetischen Wörtern gibt es höchstens
einen zusätzlichen Versuch mit zusammengeschriebener Schreibweise, sofern
nicht schon eine normalisierte Variante versucht wurde.
Er wird bei leeren oder nur unpassenden Treffern versucht, etwa bei einer
Mischung aus `Horn`, `Hornbach` und weiteren Vorschlägen für `Zürich Horn`.
Ein exakt passender Original- oder Alternativname und ein passender erster
Namensbestandteil (etwa die Straße in einer Straße-Ort-Suche) brauchen
diesen Versuch nicht. Nur exakt zum kompakten
Namen passende Treffer dürfen bestehende Ergebnisse ersetzen. Ein leerer,
unpassender oder fehlgeschlagener Zusatzversuch erhält die Originaltreffer.
Zusätzliche Anfragen können die Suchdauer erhöhen und müssen im Praxistest
beobachtet werden. Normale Straße-Ort-Suchen sollen keinen Zusatzversuch auslösen.

Nominatim wird als JSONv2 mit `namedetails=1` angefordert. Der Parser behält
die bisherige GeoCodeJSON-Kompatibilität. `alt_name`, `loc_name`, `short_name`,
`official_name` und `old_name` werden als alternative Namen übernommen, an
Semikola getrennt, dedupliziert und ohne doppelte Hauptnamen angezeigt.
Die Treffer zeigen den offiziellen Namen samt Adresse und darunter
„Auch bekannt als …“ beziehungsweise „Also known as …“. Die Zielkoordinate
wird nicht aus einem Alias abgeleitet. Favoriten und zuletzt verwendete
Ziele behalten die Namen beim Speichern; alte gespeicherte Daten laden weiter.

Suchergebnis und Anbieterzuordnung werden gemeinsam übernommen, erst wenn
die Suchanfrage noch aktuell ist. Abbruch, Schließen und neuere Anfragen
verhindern weitere Varianten und die Übernahme verspäteter Ergebnisse.
Eine leere Eingabe beendet den Ladezustand auch während einer alten Anfrage.

## Befunde aus echten Anfragen

Der bestehende Nominatim-Proxy fand am 9. Oktober 2026
`Marktplatz, 72070 Tübingen` als `Am Markt` mit `alt_name=Marktplatz` und
`loc_name=Marktplatz`. Die JSONv2-Antwort liegt unverändert in
`test/fixtures/nominatim/marktplatz_tuebingen.json`. GeoCodeJSON enthielt
diese Namensdetails trotz `namedetails=1` nicht.

`GreenCity e V` lieferte beim Proxy keinen Treffer, `Green City e.V.` dagegen
den Verein an der Lindwurmstraße 88 in München. `Zürich Horn` lieferte
Orte namens Horn im Kanton Zürich, `Zürichhorn` lieferte POIs in Zürich.
Das ist die Grundlage der eng begrenzten Schreibvarianten; die Ergebnisse
der Live-Dienste bleiben von Datenstand und Anbieter abhängig.

## Korrektur nach dem ersten Handytest

Der Handytest fand die Green-City-Varianten, aber weder
`Marktplatz, 72070 Tübingen` noch `Zürich Horn`. Die erneut abgefragten
Geoapify-Antworten reproduzierten beide Ursachen:

- Für den Marktplatz lieferte Autocomplete 15 Vorschläge anderer Städte mit
  anderen Postleitzahlen. Da die Liste nicht leer war, wurde Nominatim nie
  abgefragt. Bei einer vom Anbieter erkannten Postleitzahl werden jetzt
  Vorschläge mit einer ausdrücklich anderen Postleitzahl verworfen. Treffer
  ohne Postleitzahl bleiben zulässig. So greift der bestehende Fallback mit
  der unveränderten vollständigen Adresse und findet den Alternativnamen.
- Für Zürich Horn enthielt die Antwort neben Horn auch andere Namen und
  Adressen. Die bisherige Bedingung „alle Treffer heißen Horn“ verhinderte
  den Zusatzversuch. Unpassende gemischte Vorschläge erlauben ihn jetzt
  ebenfalls; nur genau zum zusammengesetzten Namen passende Ergebnisse
  ersetzen die alte Liste. Normale Straße-Ort-Treffer bleiben im schnellen Pfad.

Die aufgezeichneten Anbieterantworten liegen als JSON-Fixtures unter
`test/fixtures/geoapify/`. Vier zusätzliche Regressionstests scheiterten
vor der Korrektur und prüfen danach Postleitzahl-Auswahl, den vollständigen
Anbieter-Fallback einschließlich Alias und Koordinate sowie Zürichhorn mit
realistischen gemischten Vorschlägen.

## Korrektur für die Suche ohne Postleitzahl

Im Handylog vom 9. Oktober um 12:21:25 war die tatsächlich eingegebene
Anfrage `marktplatz tübingen`. Geoapify erkannte die Stadt Tübingen, lieferte
aber unter anderem Grosselfingen. Die reine Postleitzahlprüfung konnte
hier nicht greifen. Eine Kontrollanfrage an Nominatim fand auch ohne
Postleitzahl `Am Markt` mit dem Alternativnamen `Marktplatz`.

Die Auswahl berücksichtigt deshalb zusätzlich `query.parsed.city`.
Widersprechende Städte werden vor dem bestehenden Anbieter-Fallback
entfernt. Fehlende Ortsfelder bleiben zulässig. Gleiche Namen, Umlaute und
Umschreibungen (Tübingen/Tuebingen), Ortsteilnamen und bereits passende
Präfixe beim Tippen bleiben erhalten. Ein vom Anbieter vollständig
bestätigter Stadttreffer (`rank.confidence_city_level == 1`) bleibt auch bei
übersetztem Namen erhalten, etwa Munich/München. Die allgemeine Angabe
`full_match` reicht dafür ausdrücklich nicht aus.

Drei weitere echte Antworten decken die Suche ohne Postleitzahl und die
funktionierenden Vergleichssuchen `Am Markt Tübingen` und
`Marienplatz Munich` ab. Fünf zusätzliche Regressionstests prüfen die
Anbieter-Auswahl, den vollständigen Nominatim-Ablauf ohne Postleitzahl und
die genannten Schreibweisen beziehungsweise unvollständigen Ortsnamen.

## Noch offen

Ein POI-Präfix zusammen mit einem echten Straßen-Tippfehler wie
`GreenCity Lindurmstr 88` benötigt zusätzlich eine sichere Korrektur des
Adressanteils. Die bisherige Münchner Straßenkorrektur vergleicht die gesamte
Anfrage und kann das nicht zuverlässig lösen. Für unbekannte Aliase, die
kein Anbieter indexiert, ist ebenfalls ein eigener Datenbestand oder eine
Verbesserung des Suchdienstes nötig. Es gibt keine hartcodierte Zuordnung
`Marktplatz → Am Markt` oder appweite Liste einzelner POI-Ausnahmen.

Ein vollständiger München-POI-Cache ist in diesem Schritt nicht eingeführt.
Zunächst werden normale Anfrageergebnisse und die vorhandenen gespeicherten
Orte genutzt. Ein zusätzlicher Offline-Index braucht einen gepflegten Export
mit Namen, Aliasen, Adressen, OSM-IDs, Koordinaten, Lizenz und Aktualisierung;
die kleinen Trinkwasser-/Toiletten-/Reparaturdaten decken diese Suche nicht ab.

## Handytest

1. `Green City e.V.`, `GreenCity ev`, `GreenCity e.V.` und `GreenCity e V`
   tippen und sprechen. Adresse und Zielkoordinate des Vereins vergleichen.
2. `Marktplatz, 72070 Tübingen` und `Marktplatz Tübingen` suchen. Bei Nominatim-Treffern soll
   `Am Markt` mit dem Alternativnamen `Marktplatz` erscheinen. Auswählen,
   als Favorit speichern, umbenennen und die App erneut öffnen.
3. `Zürich Horn` und `Zürichhorn` vergleichen. Kein anderer Ort namens Horn
   darf allein wegen einer vermuteten Schreibweise als Zürichhorn ausgegeben werden.
4. Bestehende Straßen-/Hausnummernsuche, `Marienplatz München`, `Marienplatz Munich`, `Berlin`
   und Adressen außerhalb Münchens prüfen. Keine unnötigen Zusatzabfragen
   bei normalen Treffern; Hausnummern bleiben erhalten.
5. Während der Suche Text ändern, Suchfeld leeren oder Suche schließen.
   Alte Antworten dürfen keine neuere Trefferliste oder deren Quellenangabe ersetzen.
6. Netz unterbrechen und wiederherstellen. Ladeanzeige endet mit Ergebnis
   oder Fehler; die nächste Suche muss wieder funktionieren.

Der Benutzer hat den abschließenden Handytest am 9. Oktober 2026 als
erfolgreich bestätigt.

## Technische Prüfung

- Finale Formatprüfung: 169 Dart-Dateien unverändert; `git diff --check` erfolgreich.
- `flutter analyze --no-pub`: ohne Befund.
- 107 fokussierte Tests für Suchadapter, Namensvarianten, Suchzustände,
  Sprachsuche, Home-Suche und Speicherung bestanden.
- Finale Gesamtsuite: 448 Tests bestanden, ein optionaler RadlNavi-Live-Test
  ohne `RADLNAVI_LIVE_TEST=true` übersprungen.
- Automatische Testbuild-Vorbereitung, fortlaufender Zähler, Fehlerbehandlung
  und CLI-Weitergabe mit gepinntem SDK isoliert geprüft; zusätzlich beide
  Tests der Versionsanzeige mit der erzeugten Defines-Datei bestanden.

Im Abschlusslauf wurde keine neue APK gebaut. Die lokale `launch.json`
mit API-Schlüssel sowie die generierten `.local/`-Dateien bleiben Git-ignoriert.

## Quellen

- [User Story #245](https://github.com/MunichWays/munich-ways-app/issues/245)
- [Nominatim Search / namedetails](https://nominatim.org/release-docs/latest/api/Search/)
- [Geoapify Address Autocomplete](https://apidocs.geoapify.com/docs/geocoding/address-autocomplete/)
