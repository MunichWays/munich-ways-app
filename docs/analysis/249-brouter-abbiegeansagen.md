# #249 – BRouter-Abbiegeansagen mit Zwischenzielen

Stand: 9. Oktober 2026. Branch: `249_brouter-abbiegeansagen`.

Die BRouter-Anfrage aktiviert `timode=2`. Der Adapter übersetzt `voicehints`
in vorhandene `RouteManeuver`-Objekte. Deutsche/englische Ansagen, TTS,
GPS-Fortschritt und Neuberechnung bleiben im bestehenden Navigationsfluss.

Unterstützt sind geradeaus, links/rechts einschließlich leichter/scharfer
Abzweige, Gabelungen, Wenden, Kreisverkehre mit Ausfahrtnummer und Ausfahrten.
Straßennamen und Radweg/Straßenwechsel liefert das kompakte Hinweisformat nicht.

## Zwischenziele

BRouter liefert eine zusammenhängende LineString-Geometrie mit globalen
Hinweisindizes, aber keine Leg-Grenzen oder Ankunftsmanöver. Der Adapter ordnet
jedes Zwischenziel dem nächsten Geometriepunkt zu und fügt Zwischenankünfte
und die endgültige Ankunft in die Manöverreihenfolge ein. Die angeforderte
Zielposition bleibt für die Ankunftserkennung erhalten.

Ein Zwischenziel muss höchstens 20 Meter vom nächsten Routenpunkt entfernt sein,
passend zum bestehenden Ankunftsradius. Die Indizes müssen streng aufsteigen
und innerhalb der Route liegen. Liegt ein weiterer, nicht benachbarter
Routenpunkt höchstens einen Meter weiter entfernt als der nächste, ist die
Zuordnung mehrdeutig und die Route bleibt ohne Ansagen. Das betrifft zum
Beispiel mehrfach besuchte Zwischenpositionen. Ein eindeutiger Wendepunkt mit
Rückkehr zum Start ist dagegen möglich. Fehlende, leere oder ungültige
Abbiegehinweise sowie unbekannte Codes deaktivieren weiterhin alle Ansagen
dieser Antwort, ohne die nutzbare Kartenroute zu verwerfen. Eine spätere
gültige Antwort aktiviert Ansagen wieder.

Die bestehende VoiceGuidance übernimmt Nummer/Namen, einmalige Zwischenansage,
Weiterfahrt und endgültige Ankunft. Es bleibt bei einer BRouter-Anfrage mit
allen Koordinaten. Geometrie, Profilwahl, Retry und Timeout werden nicht
in Teilstreckenanfragen aufgeteilt. Direkt behält Fastbike, Trekking seinen
bisherigen Shortest-Fallback.

## Handy-Praxistest

1. Außerhalb Oberbayerns eine BRouter-Route mit einem, dann zwei Zwischenzielen
   direkt auf befahrbaren Wegen planen. Zwischenziele in Reihenfolge abfahren:
   „Zwischenziel 1/2 erreicht“ mit Namen, falls vorhanden, jeweils einmal.
   Danach müssen Abbiegeansagen weitergehen. Nur am letzten Ziel darf
   „Ziel erreicht“ kommen. Auch auf Englisch prüfen.
2. Eine Rundroute mit eindeutigem Wendepunkt und Start gleich Ziel testen:
   keine Zielankunft beim Start, Zwischenansage am Wendepunkt, Zielankunft
   erst nach der Rückkehr. Überlappende Abschnitte behalten das bestehende
   Kartenverhalten.
3. Nach dem ersten Zwischenziel von der Route abweichen und neu berechnen:
   erreichte Stopps dürfen nicht erneut angefahren werden. Die übrigen
   bleiben erhalten und werden danach angesagt.
4. Ein Zwischenziel weit neben den Weg oder auf einen mehrfach besuchten
   Abschnitt setzen. Bei mehrdeutiger Zuordnung zeigt die App den Hinweis
   auf fehlende Ansagen und bietet die Kartenroute weiter an.
5. Standard/Direkt und RadlNavi innerhalb Oberbayerns erneut prüfen. Eine
   Route mit Kreisverkehr wählen und die Ausfahrtnummer vergleichen.
6. Bildschirm aus, Bluetooth und Unterbrechung durch Medien/Anruf prüfen.
   Netz vorübergehend verlieren und wiederherstellen: geladene Route bleibt
   nutzbar; erneutes Routing muss sich erholen.

## Beobachtungen und Quellen

Kurztest des Nutzers am 9. Oktober: BRouter-Ansagen hörbar; normale Ansagen
in München funktionieren weiterhin. Auch den anschließenden Handytest der
Zwischenziel-Erweiterung meldet der Nutzer als erfolgreich.

Die Fixture `test/fixtures/brouter/berlin_multistop.json` wurde am 9. Oktober 2026
mit BRouter 1.7.10 aufgezeichnet: Start 13.3777,52.5163, Zwischenziel
13.3900,52.5180, Ziel 13.4050,52.5200; Trekking, `timode=2`, Alternative 0.
Geometrie (130 Punkte), alle 21 Hinweise und Routenwerte sind unverändert;
`messages` und `times` wurden zur Verkleinerung entfernt. Der Zwischenhalt liegt
am Punkt 71, einem Wendemanöver. Genau zwei Ankünfte werden ergänzt.

`exportCorrectedWaypoints=1` lieferte im Live-Test dieser Serverversion keine
korrigierten Punkte und ungültiges JSON (abschließendes Komma). Die App nutzt
diesen Parameter nicht. Mehrfach besuchte Zwischenziele brauchen zuverlässig
exportierte Leg-Grenzen/Indizes oder eine separat geprüfte Teilstreckenlösung.

- [Analyse in Issue #249](https://github.com/MunichWays/munich-ways-app/issues/249#issuecomment-6045799441)
- [BRouter GeoJSON-Formatter](https://github.com/abrensch/brouter/blob/master/brouter-core/src/main/java/btools/router/FormatJson.java)
- [BRouter Teilstrecken und Hinweisindizes](https://github.com/abrensch/brouter/blob/master/brouter-core/src/main/java/btools/router/OsmTrack.java)
- [BRouter Manövercodes](https://github.com/abrensch/brouter/blob/master/brouter-core/src/main/java/btools/router/Formatter.java)

## Technische Prüfung

- Formatierung und `git diff --check` erfolgreich.
- `flutter analyze --no-pub`: ohne Befund.
- 70 fokussierte Tests für BRouter, Routing-Fallbacks und VoiceGuidance bestanden.
- Finale Gesamtsuite: 416 Tests bestanden; ein optionaler RadlNavi-Live-Test
  bleibt ohne `RADLNAVI_LIVE_TEST=true` standardmäßig übersprungen.
- Repositoryweite Formatprüfung: 165 Dart-Dateien, keine Änderungen.
- Handytest der Zwischenziel-Erweiterung vom Nutzer erfolgreich bestätigt.
- Im Rahmen der finalen Prüfungen keine zusätzliche APK gebaut.
- Abschlussstand für Branch `249_brouter-abbiegeansagen`.
