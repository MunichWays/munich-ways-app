# #239 – Sprachsteuerung der Hauptfunktionen

Stand: 27.09.2026 · Branch: `239-b68-spracheingabe-hauptfunktionen`

## Entscheidung: zurückgestellt

Die Umsetzung der Sprachbefehle für die Hauptfunktionen wird zurückgestellt.
Es wurden dafür bisher keine neuen Funktionen implementiert.

Eine Mikrofontaste vor jedem Befehl bietet für einfache Aktionen wie „Starten“
oder „Pause“ zu wenig Mehrwert gegenüber dem direkten Antippen der jeweiligen
Taste. Dieser Vorschlag wurde vom Nutzer verworfen.

Voraussetzung für einen neuen Anlauf ist eine **sprachliche Aktivierung**:
Während der vorgesehenen Nutzung muss ein Befehl ohne vorherigen Griff zum
Handy möglich sein. Das Ziel bleibt, die App während der Fahrradfahrt mit
möglichst wenigen Blicken auf das Display bedienen zu können.

## Bereits vorhandene Basis aus #137

- Zielsuche per Mikrofontaste mit `speech_to_text` und gemeinsamer Dart-Logik.
- Android-Gerätetest mit „Lindwurmstraße 88“ vom Nutzer als erfolgreich bestätigt.
- iOS-Berechtigungstexte und Plugin-Anbindung vorhanden; iOS-Build und Abnahme
  auf einem echten iPhone, beispielsweise über TestFlight, stehen noch aus.
- Aufnahme, Stopp, Abbruch, Zeitlimits, Fehlerbehandlung und erneute Aufnahme.
- Keine dauerhafte Aufnahme und keine Erkennung eines Aktivierungsworts.
- Spracheingabe während aktiver Navigation bisher ausgeblendet; die Koordination
  von Mikrofon und Navigationsansagen ist noch nicht implementiert.

Die bestehende Spracheingabe für längere Zieleingaben behält ihren Nutzen.
Die Zurückstellung betrifft die neue Sprachsteuerung der Hauptfunktionen.

## Vorgesehene Befehle bei Wiederaufnahme

| Befehl | Gewünschtes Verhalten |
| --- | --- |
| „Wohin?“ / „Ziel eingeben“ | Zielaufnahme öffnen; die Auswahl eines Suchtreffers bleibt eine eigene Aktion. |
| „Starten“ | Nur eine vorhandene, startfähige Route starten. |
| „Pause“ | Bestehende Navigation pausieren und die Route erhalten. |
| „Weiter“ | Pausierte Navigation fortsetzen. |
| „Beenden“ | „Navigation wirklich beenden?“ fragen; erst nach ausdrücklicher Bestätigung beenden. |

Bei unbekannten Befehlen, Nichterkennung, Abbruch oder ausbleibender Bestätigung
darf keine unerwünschte Navigationsaktion erfolgen. Die Bestätigung muss ebenfalls
ohne Bildschirmbedienung möglich sein.

## Ergebnisse der bisherigen Codeprüfung

- Start und Ende sind in `map_screen.dart` bereits zentral angebunden.
- Die bestehende Pause beendet die Kartenverfolgung und stoppt Ansagen, ohne
  die Route zu löschen. `navigationPaused` wird im Modell aus dem bestehenden
  Navigations- und Verfolgungszustand abgeleitet.
- Die vorhandene Fortsetzen-Aktion berechnet die Route neu und startet bei
  Erfolg wieder die Navigation. Vor einer Sprachintegration muss entschieden
  werden, ob „Weiter“ genau diesen Ablauf verwendet.
- Die Starttaste prüft unter anderem, ob eine Route angezeigt wird, die
  Navigation noch nicht läuft und kein benutzerdefinierter Startpunkt vorliegt.
  Sprachbefehle müssen dieselben Voraussetzungen beachten.
- Navigationsansagen und Spracheingabe benötigen eine gemeinsame Abstimmung,
  damit sich die App nicht selbst hört und Ansagen nach der Aufnahme zuverlässig
  wieder funktionieren. Das ist besonders für die iOS-Audiositzung zu prüfen.

Die spätere Umsetzung soll die vorhandenen Aktionen und Zustände verwenden,
statt eine zweite Navigationslogik aufzubauen.

## Offene Untersuchung: sprachliche Aktivierung

Das bisher verwendete Plugin ist für kurze Sprachaufnahmen ausgelegt. Eine
zuverlässige Aktivierung per Sprache ist damit noch nicht gelöst; der Hersteller
nennt dauerhaftes Mithören ausdrücklich nicht als Zielanwendung.
Quelle: [speech_to_text 7.5.0](https://pub.dev/packages/speech_to_text/versions/7.5.0).

Vor einer Umsetzung sind folgende Punkte zu klären:

1. **Aktivierung:** Geeigneten Ansatz für ein Aktivierungswort oder eine andere
   sprachliche Aktivierung auf Android und iOS untersuchen. Kein Anbieter und
   kein Aktivierungswort sind bisher ausgewählt.
2. **Nutzungszustände:** Festlegen und auf Geräten prüfen, ob die Funktion nur
   bei sichtbarer App oder auch bei ausgeschaltetem Bildschirm bzw. im
   Hintergrund benötigt wird und zuverlässig möglich ist.
3. **Akku und Erkennung:** Stromverbrauch, Reaktionszeit, Wind- und Verkehrsgeräusche
   sowie versehentliche Aktivierungen praktisch messen. Akzeptanzgrenzen vor
   einer Freigabe festlegen.
4. **Audio:** Aktivierungswort-Erkennung, Befehlsaufnahme und Navigationsansagen
   koordinieren. Unterbrechungen, Anrufe und erneute Nutzung nach Fehlern prüfen.
5. **Datenverarbeitung:** Lokale Aktivierungserkennung bevorzugt untersuchen;
   Offline-Fähigkeit, eventuelle Übertragung von Audio, Kosten und Lizenz eines
   zusätzlichen Dienstes oder Plugins klären.

## Transparenz für den Nutzer – Vorschlag, noch nicht beschlossen

- Einen bewusst einschaltbaren Sprachsteuerungsmodus vorsehen, beispielsweise
  vor Fahrtbeginn. Danach soll keine Taste vor jedem Befehl nötig sein.
- Klar zwischen „Sprachsteuerung aus“, „Wartet auf Aktivierungswort“ und
  „Nimmt Befehl auf“ unterscheiden. Warten auf ein Aktivierungswort darf nicht
  als ausgeschaltetes Mikrofon dargestellt werden.
- Aufnahmebeginn, verstandenem Befehl und Abschluss eine verständliche akustische
  Rückmeldung geben; den Zustand zusätzlich sichtbar darstellen.
- Eine jederzeit erreichbare Ausschaltmöglichkeit vorsehen; automatisches
  Abschalten und Verhalten bei App-Wechsel oder Fahrtende ausdrücklich festlegen.
- Sprachsteuerung und Navigationsansagen verständlich getrennt benennen.

Nächster Schritt bei Wiederaufnahme ist eine Machbarkeitsprüfung der sprachlichen
Aktivierung auf echten Geräten. Erst bei tragfähigem Ergebnis folgen Bedienkonzept
und Implementierung der Befehle. Ein MVP mit Mikrofontaste vor jedem Befehl wird
für diese Hauptfunktionen nicht weiterverfolgt.
