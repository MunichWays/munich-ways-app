# Große Kreuzungen: Aktivierung und Praxistest

Build 3.2.2+96; Branch `feature/big-conjunctions`. **Standardmäßig aktiv**
für Standard/RadlNavi und ausdrücklich freigegebene Backend-Fahrbeziehungen.
Der Arnulf-Praxistest wurde vom Nutzer am 06.11.2026 erfolgreich abgeschlossen.
Katalogfreigabe vom 07.11.2026: Arnulfstraße/Steubenplatz und
Balanstraße/Chiemgaustraße mit jeweils allen acht Links-/Geradeausbeziehungen.
Beide Polygone sind vom Nutzer bestätigt; Arnulf West nach Nord ist praktisch
getestet. Die weiteren Beziehungen sind noch nicht alle vor Ort gefahren.

Die App unterstützt beliebige Katalogkennungen/-revisionen, mehrere Kreuzungen,
Links-/Geradeausbeziehungen und getrennte wiederholte Besuche. Sie schaltet
keine Kandidaten selbst frei. Im Backend sind 495 stadtweite Kandidatenpunkte
separat erfasst; die Prüfung der weiteren Kreuzungen steht noch aus.

## Lokaler Praxistest

Erst nach Abschluss aller Flutter-Checks/Builds starten. Kein paralleler
VS-Code-/Telefonlauf. Daten auf dem Telefon beim Update behalten.

Die normalen VS-Code-Startprofile verwenden die Funktion jetzt ohne Pilot-
Define. Für einen lokalen Lauf genügt auch:

```powershell
powershell -File tool/run_local_test_build.ps1 --release
```

Für einen gezielten Vergleichslauf ohne Kreuzungsführung:

```powershell
powershell -File tool/run_local_test_build.ps1 -DisableBigJunctionGuidance --release
```

Das setzt `BIG_JUNCTION_GUIDANCE=false` nur in diesem Build. Alternativ diesen
Dart-Define im eigenen Startprofil setzen. Der alte `-BigJunctionPilot`-Schalter
bleibt kompatibel. Bestehende API-Key- und Testbuild-Argumente erhalten.

1. Standard/RadlNavi wählen; Direct/Discovery sind nicht Teil dieses Piloten.
2. Start auf dem westlichen Zufahrtsradweg der Arnulfstraße mindestens
   150–200 m vor dem Kreuzungsbereich setzen, Ziel am Steubenplatz nördlich.
   Geeignete Testplanung: Start 48.150550,11.517800 zum Ziel
   48.150871,11.520477 (aktuell rund 168 m bis zur Einfahrt). Die alte
   Beispielroute ab 48.150239,11.518913 beginnt zu nah an der Kreuzung.
3. Bei durchgehender Anfahrt einmal ungefähr bei 100 m und einmal bei 60 m:
   „In … Metern an der großen Kreuzung links abbiegen.“ Entfernung bis Einfahrt.
4. Innerhalb: Kreuzungshinweis bleibt sichtbar, kein „Hier“, keine weiteren
   Navigationsansagen, keine Routenabweichungswarnung und keine automatische
   Neuberechnung. Warten und GPS-Pendeln dürfen nichts erneut auslösen.
5. Nach korrekter Nord-Ausfahrt normale Führung. Ein Austritt wird erst nach
   zwei neuen, hinreichend außerhalb liegenden GPS-Fixes bestätigt. Bei falschem
   Ausgang greift die bisherige Abweichungs-/Neuberechnungslogik wieder.
6. Pause/Fortsetzen sowie eine neue Route prüfen; kein hängenbleibender
   Kreuzungszustand. Ohne passende Backend-Metadaten normale Einzelhinweise.

Eintritt benötigt eine zuvor beobachtete passende Anfahrt. Ein Start direkt
innerhalb der Fläche aktiviert keine neue Unterdrückung. Bestehende GPS-
Qualitäts- und Fortschrittsschranken bleiben erhalten. Die Grenze wird mit
mindestens 8 m bzw. der aktuellen Genauigkeit als Außenabstand bestätigt.

Der Backend-Pilot genehmigt weiterhin nur den geprüften inneren Routenverlauf.
Während einer zugeordneten Durchfahrt wird eine abweichende Position innerhalb
der Fläche toleriert. Weitere automatisch geplante Querungsvarianten sind
dadurch noch nicht freigegeben. Die vier schwierigen Fälle bleiben ausgenommen.

Bei Diagnose im lokalen Log nach `Big junction:` suchen: Voransagen,
Eintritt und korrekter/falscher Austritt, ohne neue GPS-Koordinaten im Log.
Native Ausgabe und Wahrnehmung im Verkehr müssen vor Ort geprüft werden.

## Technische Prüfung

- Optionales Backend-Feld wird defensiv geprüft; Vertrags-/Geometriefehler
  verändern weder die nutzbare Route noch die bisherigen Einzelmanöver.
- Die Ansagelogik ersetzt nur die enthaltenen Hinweise durch das Makromanöver.
  Geometrieergänzungen innerhalb dieses Intervalls werden ebenfalls entfernt.
- Kreuzungszustand wird einmal je tatsächlichem GPS-Fix aktualisiert, nicht
  durch wiederholte Anzeige-/Abweichungsabfragen. Routenfortschritt bleibt in
  VoiceGuidance; für den Ausfahrtsabgleich wird nur das genehmigte Intervall
  samt unmittelbarem Anschluss betrachtet.
- Bei fehlender Freigabe, ausgeschalteter Kreuzungsführung, anderen Routinganbietern oder
  anderen Fahrbeziehungen gilt die bisherige Navigation.
- Tests: eingefrorene Arnulf-Routenantwort mit ausdrücklich synthetisch
  verlängerter Westanfahrt für 100/60 m; Metadaten, Fallback, Ansagen, Ruhe,
  GPS-Grenzpendeln, falscher Ausgang und Wiederaufnahme.

Das Zielbild für den Katalogausbau ist im Backend unter
`docs/big-junction-rollout.md` beschrieben. Der weitere Ausbau besteht aus der Prüfung und Freigabe von Katalogdaten.

Die App-Änderungen sind für diesen Schritt lokal. Ein App-Push ist erst nach
gesondertem Auftrag vorgesehen. Keine Telefoninstallation durch den Agenten.

## Katalog v2: zusätzliche Regressionen

`test/ui/map/big_junction_catalog_contract_test.dart` prüft alle 16 echten
Referenzrouten aus dem RadlNavi-Katalog v2. Die Anfahrt wird ausschließlich
im Test synthetisch verlängert, um beide Voransagen abspielen zu können.
Innenverlauf, Polygon und Anker bleiben aus der Referenzantwort erhalten.
Die Tests prüfen Metadaten, Ansagetext und Symbol für links/geradeaus, Ruhe
innerhalb sowie korrekte Ausfahrt. Keine weitere App-Verhaltensänderung und
kein neuer App-Build sind für die Katalogerweiterung erforderlich.

## Reviewed catalog v3

Backend 2.4.3 adds eight reviewed junctions and 60 real route references.
K07 remains deferred; K09 is permanently excluded. Four Lachnerstrasse
relationships at K06 remain ordinary guidance because live routing differs
from the reviewed carriageway. The generic App behavior is unchanged;
the contract test now replays all 76 approved real reference routes.

The v3 contract replay exposed slight kerb offsets just before the polygon
blocking the macro approach. The App absorbs only straight continuations or
slight turns within 30m before entry when the approach resumes the same
direction (at most 25 degrees). Real turns, forks and way-type transitions
remain ordinary hints. Positive and preservation regressions cover this rule.
