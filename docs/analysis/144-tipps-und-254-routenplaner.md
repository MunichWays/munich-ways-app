# Tipps zur Bedienung (#144) und Start/Ziel im Routenplaner (#254)

## Umfang

Unter **ⓘ → Legende & Tipps** führt am Ende ein Button **Tipps & Bedienung**
zu neun einzeln abrufbaren kurzen Tipps. Die bisherigen Erklärungen zu Zielwahl
und Streckendetails entfallen dort, damit keine doppelten Tipps stehen.
Jeder Tipp zeigt einen Text und eine nicht bedienbare Abbildung. Sechs Tipps
verwenden die vom Nutzer vorbereiteten Screenshot-Ausschnitte aus dem
[Drive-Unterordner Tipps](https://drive.google.com/drive/folders/1rg1F-KfJapo4_ZfDZwu0wDNnDN9Ktj10),
lokal unter `images/tip-*.jpg`. Sie behalten ihre deutsche, helle Darstellung;
die übrigen Abbildungen passen sich Sprache und Theme an. Texte unterstützen
Deutsch, Englisch und vergrößerte Schrift. Die Tipps laden weder Kartendaten
noch weitere Netzressourcen und ändern keinen Routen- oder Navigationszustand.

Für Navigation, Drei-Punkte-Menü und Verschieben werden die verbesserten
`-ausschnitt2`-Vorlagen verwendet. Die Screenshots stehen über dem Text.
Proportional platzierte Rahmen, Pfeile und Fingersymbole markieren das jeweilige
Bedienelement bzw. langen Druck und Verschieben, ohne die Screenshot-Pixel zu
verändern. Die Markierungen sind nicht bedienbar und nicht Teil des Screenreaders;
die Erklärung steht als normaler, vergrößerbarer Text darunter.

Die Detailansicht bietet im feststehenden Kopf eine kompakte Zeile **‹ 1 / 9 ›**
zum Blättern. Die Pfeile haben zugängliche Beschriftungen und ausreichend große
Touchflächen. Links/rechts wischen im Inhalt wechselt ebenfalls den Tipp;
vertikales Scrollen bleibt erhalten. An den Grenzen ist die jeweilige Richtung deaktiviert.
Jeder Wechsel beginnt oben; Kopf-Pfeil und Android-Zurück führen weiterhin zur
Liste, Schließen beendet das Infofenster.

Auch **Mehr Platz für die Karte** (mit markiertem Griff) und **Routen vergleichen**
verwenden lokale Screenshots. Das Erststartfenster begrüßt nun mit
**So einfach wie Radfahren!** und der kurzen Bedienfolge einschließlich
**Route hierhin → Starten**. Darunter steht der bisherige Sicherheitstext kleiner;
Nutzungsbedingungen, Schließen, Vorladen der Karte und der anschließende
freiwillige Einstieg in die drei Tipps bleiben erhalten.

Erststart und permanente Tipp-Details verwenden denselben `TipViewer` mit
fester verfügbarer Maximalhöhe, kompakter Pfeilnavigation und Wischgesten.
Die Screenshots und grauen Textflächen nutzen die volle Fensterbreite;
nur Titel und Text haben einen kleinen Innenabstand. Die Fenstergröße bleibt
beim Blättern unverändert. Beim dritten Erststart-Tipp bietet **Alle Tipps ansehen**
die vollständige Sammlung ab der aktuellen Position an; **Fertig** beendet
weiterhin die Einführung. Auch die erweiterte Sammlung verändert keine Karte.

Das Angebot **Neu hier?** erhält einen farbigen Bereich mit Fahrrad-Symbol
und einer Vorschau auf die drei Themen. Das Willkommen nennt unter dem Logo
nur noch **So einfach wie Radfahren!**, mit breiterem Textbereich und drei
nummerierten Schritten statt einer langen Zeile mit Pfeilen.

Reihenfolge:

1. Navigation fortsetzen (Aktualisieren-Symbol)
2. Das Drei-Punkte-Menü unter „Wohin?“
3. Lange drücken, mehr entdecken
4. Start, Zwischenziele und Ziel verschieben
5. Mehr Platz für die Karte
6. Mit Zwischenzielen planen
7. Route für später speichern
8. Lieblingsziele schnell erreichen
9. Routen vergleichen

Bei frischen App-Daten erscheint nach dem Sicherheitshinweis das freiwillige
Angebot **Neu hier? → Tipps ansehen / Später**. Es zeigt die ersten drei Tipps
(Aktualisieren-Symbol, Drei-Punkte-Menü und langer Druck auf die Karte), mit
Zurück/Weiter und Fertig. Kreuz und Android-Zurück schließen die Einführung
jederzeit. **Später** verschiebt keinen Termin, sondern beendet das Angebot;
alle Tipps bleiben über die Legende erreichbar.

Der Erststart-Speicher ergänzt dafür `tutorialPending`, getrennt vom
Sicherheitshinweis und über dieselbe serialisierte, atomare Schreibfolge.
Fehlende Flags auf bestehenden Installationen werden nicht nachträglich gesetzt.
Schließen/Überspringen/Fertig speichert den Abschluss ohne die App darauf warten
zu lassen. Bei unterbrochenem Erststart oder fehlgeschlagenem Speichern bleibt
das Angebot für einen späteren Start erhalten. Während beider Fenster bleibt
die Karte unverändert gemountet und lädt weiter; Berechtigungsdialoge und andere
Startinteraktionen werden erst nach Abschluss freigegeben.

## Routenplaner

Die unterschiedlichen Symbole und Hintergründe ließen Start, Zwischenziele und
Ziel wie unterschiedliche Bedienkonzepte wirken. Alle Positionen erhalten nun
gleich große orange Kreise und eine ausdrückliche Rollenbeschriftung. Ein noch
unbesetztes Ziel wird orange hervorgehoben.

Langer Druck verschiebt weiterhin einen Eintrag in der Reihenfolge. Das
Drei-Punkte-Menü bietet für gewählte Orte zusätzlich **Als Start** und **Als Ziel**.
Beide Aktionen nutzen denselben Verschiebeablauf wie die Geste; bisherige Orte
bleiben in der Reihenfolge erhalten. Die Schaltfläche zum Hinzufügen eines
Zwischenziels gehört nicht mehr zur Fläche für langen Druck.

Die Änderungen bleiben im geöffneten Planer, bis die Route ausdrücklich
berechnet oder gespeichert wird. Schließen verwirft ungespeicherte Änderungen.
Ein leeres Ziel verhindert Berechnen und Speichern. Ein impliziter GPS-Start
bleibt beim Verschieben von Zwischenzielen erhalten.

## Kartenwechsel nach dem ersten Handytest

Der Übergang Suche → Planer → Karte wird erst nach Abschluss der jeweiligen
Ausblendanimation fortgesetzt. Die Scroll-Controller werden erst danach
freigegeben, und der schließende Planer startet keine weitere Scrollanimation.
Beim Eintritt in die Kartenauswahl wird die vorhandene Kartenverfolgung
angehalten; GPS und der bisherige Routenplan bleiben erhalten. Die Auswirkung
auf die native Kartendarstellung wird beim Handytest geprüft. Beim Ein- und
Ausblenden der Tastatur behält die native Karte ihre Größe; nur die darüber
liegenden Flutter-Bedienelemente weichen der Tastatur aus.

## Handytest

- Unter ⓘ → Legende & Tipps am Ende **Tipps & Bedienung** öffnen, dann alle neun
  Tipps einzeln öffnen. Text, markiertes Symbol und Reihenfolge
  prüfen. Zurück führt zur Liste; das Kreuz schließt das Infofenster vollständig.
  Android-Zurück führt über Tipp → Liste → Legende → Info zurück zur Karte.
- Mit frischen App-Daten starten (Löschen der App-Daten entfernt lokale Favoriten
  und gespeicherte Routen). Zuerst Sicherheitshinweis, danach freiwilliges Angebot.
  **Später** wählen, App vollständig schließen und neu öffnen: kein erneutes Angebot.
- Bei einem weiteren frischen Erststart alle drei Tipps mit Zurück/Weiter prüfen
  und **Fertig** wählen. Neu öffnen: direkt zur Karte. Zusätzlich Kreuz und
  Android-Zurück während eines Tipps testen. Installation mit bestehenden Daten
  aktualisieren: keine neue Einführung, Favoriten und Routen bleiben erhalten.
- Während der Einführung Netz ausschalten/einschalten, App in den Hintergrund
  und zurück holen. Kein Verlust der aktuellen Seite; nach dem Schließen bleibt
  die Karte bedienbar. Standortberechtigungen dürfen erst danach erscheinen.
- Die Tipps auch ohne Netz öffnen; dabei eine vorhandene Route unverändert lassen.
- Kleine Anzeige, große Systemschrift, Hell/Dunkel und Englisch prüfen. Lange
  Inhalte müssen scrollbar und Zurück/Schließen immer erreichbar sein.
- Zwischenziel hinzufügen → Auf Karte wählen mit geschlossener und geöffneter
  Tastatur testen. Nach dem Schließen beider Fenster muss die Karte ohne weitere
  Bewegung auswählbar sein. Punkt lange antippen, benennen/überspringen, im
  Planer prüfen und berechnen. Auswahl abbrechen und erneut beginnen. Auch
  Start-/Zielauswahl sowie die Auswahl während der Navigation prüfen; nachher
  muss das Aktualisieren-Symbol die Navigation wieder fortsetzen können.
- Route mit Start, zwei Zwischenzielen und Ziel planen. Einträge lange drücken und
  nach oben/unten ziehen, einschließlich Zwischenziel → finales Ziel. Symbole,
  Beschriftungen und Reihenfolge müssen sich passend ändern.
- Dasselbe über **Als Start** und **Als Ziel** ausführen. Kein gewählter Ort darf
  verloren gehen. Berechnen muss die neue Reihenfolge verwenden; gespeicherte
  Routen müssen sie nach erneutem Öffnen behalten.
- Änderungen ohne Berechnen/Speichern schließen: der vorherige Plan bleibt
  erhalten. Ziel löschen, danach einen Zwischenstopp als Ziel verschieben:
  Berechnen/Speichern müssen wieder möglich sein.
- Mit aktuellem Standort als Start testen. Während einer laufenden Navigation
  einen unveränderten Plan neu berechnen; bereits erledigte Zwischenziele dürfen
  nicht erneut angefahren werden.
- Nach dem Schließen der Tipps Karte verschieben und über das Aktualisieren-Symbol
  fortsetzen; anschließend Navigation regulär beenden und neu starten.
