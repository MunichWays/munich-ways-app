# #257 – Mehr hilfreiche App-Store-Bewertungen

Stand: 11. Oktober 2026. Bezug: [Issue #257](https://github.com/MunichWays/munich-ways-app/issues/257).
Codebasis: `805298d`, Umsetzung auf Branch `257-app-store-bewertungen`.
Status: Zählung und Test-Sperrvermerk korrigiert; Feedback und Diagnosedaten
umgesetzt. Die zuletzt angepasste Darstellung wurde vom Nutzer am Handy
bestätigt. Finale technische Verifikation siehe unten.
Aktuelle Entscheidung vom 11. Oktober: Die eigene Feedback-Seite wird weiterhin
nur manuell geöffnet. Der Wunsch, sie nach drei Fahrten automatisch anzuzeigen,
war ausdrücklich an die Zulässigkeit bei Apple und Google geknüpft. Diese
Bedingung ist für das gemeinsame Fenster mit Bewertungsaufforderung nicht erfüllt.
Apple untersagt eigene Bewertungsaufforderungen in
[Regel 5.6.1](https://developer.apple.com/app-store/review/guidelines/#developer-code-of-conduct)
und verlangt die native API. Das automatische Öffnen unserer Seite mit
Bewertungstext und Store-Button wird hier als eigene Bewertungsaufforderung
eingeordnet; das ist eine Interpretation der Regel, keine App-Review-Entscheidung.
Google untersagt zudem Meinungsfragen vor oder neben dem Bewertungsbutton im
[In-App-Review-Ablauf](https://developer.android.com/guide/playcore/in-app-review#when-to-request).
Es wurde deshalb keine automatische Anzeige der Feedback-Seite implementiert.
Die bisherige native Anfrage bleibt bestehen; ihre sichtbare Anzeige ist nicht
garantiert. Der erneut gemeldete Handytest ohne Dialog beweist allein weder
einen Zählfehler noch eine erfolgreiche native Übergabe. Für diese Unterscheidung
sind Laufzeitdaten des Geräts nötig; sie lagen bei dieser Prüfung nicht vor.
Kurzfassung als [AI-Kommentar im Issue](https://github.com/MunichWays/munich-ways-app/issues/257#issuecomment-6100906517) dokumentiert.
Umsetzung und Handy-Testschritte: [AI-Abschlusskommentar](https://github.com/MunichWays/munich-ways-app/issues/257#issuecomment-6101289491).
Korrektur nach Handytest: [AI-Kommentar vom 11. Oktober](https://github.com/MunichWays/munich-ways-app/issues/257#issuecomment-6106894038).

## Empfehlung

Zuerst einen dauerhaft erreichbaren Eintrag **„App bewerten“** im Info-Menü
ergänzen. Anschließend eine **native Bewertungsanfrage nach drei erfolgreich
abgeschlossenen Navigationen** einführen, sobald die Navigation beendet und die
Oberfläche wieder ruhig ist. Für die erste Ausbaustufe genügt ein automatischer
Anfrageversuch je Installation. Der Menüeintrag bleibt danach erreichbar.

Parallel die häufigsten tatsächlichen Nutzungsprobleme beheben, Rezensionen
beantworten und die Store-Darstellung aktuell halten. Eine Anfrage erleichtert
die Abgabe einer Bewertung; bessere Bewertungen entstehen vor allem durch eine
zuverlässige und verständliche App. Wie stark die Maßnahmen wirken, ist für
MunichWays bisher nicht belegt. Die Priorisierung ist eine Produktempfehlung.

## Ausgangslage vor Umsetzung und Grenzen der Analyse

- Das Issue schlägt drei erfolgreiche Fahrten vor, erkannt an „Ziel erreicht“
  oder „Beenden“, und wünscht einen direkten Einstieg in die Sternebewertung.
- Im untersuchten Code fehlen eine Store-Bewertungsanfrage und ein dauerhafter
  Bewertungslink. `url_launcher`, `package_info_plus` und lokale JSON-Speicherung
  sind vorhanden; `in_app_review` ist keine bestehende Abhängigkeit.
- Das Info-Menü bietet bereits E-Mail-Feedback an `mail@munichways.de` mit
  App-Version. Dieser unabhängige Kontaktweg ist eine gute Grundlage für Support.
- Der abgerufene deutsche [App-Store-Eintrag](https://apps.apple.com/de/app/munichways/id1534934984)
  zeigt 5,0 Sterne bei 17 Bewertungen. Die kleine Basis spricht dafür, zunächst
  mehr ehrliche Rückmeldungen zu gewinnen. Apple bewertet je Store-Gebiet; dies
  ist keine weltweite Kennzahl und kein Live-Export aus App Store Connect.
- Der abgerufene [Play-Store-Eintrag](https://play.google.com/store/apps/details?id=com.munichways.app&hl=de)
  zeigt 1.000+ Downloads, aber keine auswertbare Sternezahl im gelieferten
  Seiteninhalt. Daraus lässt sich nicht auf null Bewertungen schließen.
- Store-Seiten können verzögert oder regional unterschiedlich ausgeliefert
  werden. Eine belastbare Ausgangsmessung braucht die beiden Store-Konsolen.
  Nutzerbindung, Fehlerraten und Bewertungsquote wurden hier nicht gemessen.

## Möglichkeiten und Priorität

| Maßnahme | Erwarteter Nutzen | Aufwand / Grenze | Empfehlung |
| --- | --- | --- | --- |
| Kritische Fehler und unklare Bedienung beheben | Mehr zufriedene Nutzer; weniger begründete schlechte Bewertungen | Laufend; aus Support und Rezensionen priorisieren | Höchste Priorität: Start, Routing, Ansagen, Akku und Fehlererholung |
| „App bewerten“ im Info-Menü | Bewertung jederzeit auffindbar, auch ohne drei Navigationen | Klein; Wechsel in den Store | Erster Umsetzungsschritt |
| Nativer Dialog nach drei erfolgreichen Navigationen | Wenige Schritte zur Sterneabgabe nach erlebtem Nutzen | Mittel; Store entscheidet über Anzeige | Zweiter Umsetzungsschritt |
| Rezensionen und Support zeitnah beantworten | Probleme verstehen, Vertrauen und Wiederkehr stärken | Laufender redaktioneller Aufwand | Wöchentlich prüfen; konkrete Hilfe und behobene Fehler nennen |
| Store-Text und Screenshots mit der ausgelieferten App abgleichen | Passende Erwartungen an Gebiet, Daten und Navigation | Klein bis mittel; Veröffentlichung separat | Mit jedem relevanten Release prüfen |
| Website, Newsletter und Community-Termine | Erreicht auch Nutzer, die selten navigieren | Klein; tatsächliche App-Erfahrung voraussetzen | Gelegentlich neutral um ehrliche Erfahrungen bitten, mit Store-Links/QR-Codes |
| Beta-Feedback vor Releases | Fehler vor breiter Veröffentlichung finden | Mittel; keine öffentliche Bewertungsmaßnahme | Bestehende Testwege nutzen; Testfeedback und Store-Rezension trennen |

Antworten auf Rezensionen sollen auf das konkrete Problem eingehen und hilfreiche
Supportwege nennen. Keine Aufforderung, die Sternezahl zu erhöhen. Das entspricht
den Empfehlungen von [Google](https://support.google.com/googleplay/android-developer/answer/9898684?hl=en)
und [Apple](https://developer.apple.com/app-store/ratings-and-reviews/).

Eine konkrete Auffälligkeit im Repository: Die deutsche Fastlane-Beschreibung
empfiehlt noch zusätzliche Sprachnavigation durch eine andere App, während der
aktuelle Code eigene Ansagen enthält. Die abgerufenen öffentlichen Store-Texte
sind bereits neuer. Vor einem erneuten Metadaten-Upload die lokalen Vorlagen
abgleichen, damit alte Texte nicht wieder veröffentlicht werden.

## Native Anfrage und Store-Link sind unterschiedliche Wege

| Weg | Android | iOS |
| --- | --- | --- |
| Automatische native Anfrage | Google Play In-App Review; Sterne innerhalb der App, wenn Google den Dialog anzeigt | StoreKit; Sterne innerhalb der App, wenn Apple den Dialog anzeigt |
| Bewusster Tipp auf „App bewerten“ | MunichWays-Seite im Play Store öffnen | MunichWays-Rezensionsseite über `action=write-review` öffnen |
| Verlässlichkeit | Native Anzeige unterliegt einer nicht öffentlich festgelegten Quote | Native Anzeige höchstens dreimal innerhalb von 365 Tagen; kann zusätzlich ausbleiben |

Ein API-Aufruf garantiert weder die Anzeige noch eine abgegebene Rezension.
Google empfiehlt deshalb für einen sichtbaren Bewertungsbutton ausdrücklich
den Store-Link. Seine dokumentierten Links öffnen die Produktseite; ein direkt
geöffneter Sterne-Editor lässt sich damit nicht plattformübergreifend zusagen.
Quellen: [Google In-App Review](https://developer.android.com/guide/playcore/in-app-review),
[Google Store-Links](https://developer.android.com/distribute/marketing-tools/linking-to-google-play),
[Apple Review-Anfrage](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews).

Verifizierte App-Kennungen und vorgesehene Links:

- Android-Paket: `com.munichways.app`;
  [MunichWays bei Google Play](https://play.google.com/store/apps/details?id=com.munichways.app).
- Apple-ID: `1534934984`; sie ist nicht die Bundle-ID `com.munichways.app`.
  [MunichWays bewerten](https://apps.apple.com/app/id1534934984?action=write-review).
  Der Linkaufbau ist von Apple dokumentiert; der tatsächliche Geräteablauf
  wurde in dieser Analyse nicht getestet.

Kein automatischer Store-Wechsel, wenn der native Dialog ausbleibt: Die App
erfährt nicht zuverlässig, ob er sichtbar war. Ein zusätzlicher Store-Aufruf
könnte den Nutzer unerwartet aus der App holen. Für eine freiwillige Bewertung
steht der Menüeintrag zur Verfügung.

## Auslöser für #257

**Nur der orangene Button „Beenden“ nach „Du hast das Ziel erreicht“ zählt.**
Jeder solche Abschluss erhöht den dauerhaft gespeicherten Zähler genau einmal:
0 → 1 → 2 → 3. Das Kreuz zählt nicht. Nach dem dritten Abschluss wird einmalig
beim Store eine Bewertung angefragt, sofern die App gerade bedienfrei ist.

Das gilt gleichermaßen für bestehende Installationen nach dem Update und für
Neuinstallationen. Fehlt `app_review.json`, beginnt die Zählung bei null;
Erststart- oder Installationsflags werden nicht geprüft. Fahrten vor Einführung
der Funktion lassen sich nicht rückwirkend zählen. Spätere Updates erhalten
den Zähler und den einmaligen Anfragevermerk.

Die Anfrage erfolgt erst nach dem normalen Aufräumen der Navigation und einer
kurzen Ruhephase, beispielsweise zwei Sekunden. Dann erneut prüfen: App im
Vordergrund, keine neue Navigation, kein anderer Dialog und keine laufende
Interaktion. Die Ruhephase ist ein Vorschlag, keine Sicherheitsgarantie.
Eine GPS-Ankunft allein darf während der Fahrradfahrt keinen Dialog auslösen.

Für die erste Version vorgeschlagene Regeln:

1. Ab der dritten qualifizierten Fahrt ist eine automatische Anfrage möglich.
   Frühere Fahrten vor Einführung der Funktion werden nicht geschätzt.
2. Zwischenziele, reine Planung, Abbruch, Pause/Fortsetzen und Neuberechnungen
   erzeugen keine zusätzlichen abgeschlossenen Fahrten.
3. Die Zählung hängt nicht von der eingeschalteten Sprachausgabe oder vom
   gesprochenen Text ab. Spracheinstellungen und TTS-Fehler ändern sie nicht.
4. Erfolgreiche Fehlererholung disqualifiziert keine Fahrt. Solange ein Fehler
   oder eine neue Aufgabe die Oberfläche beansprucht, wird nicht angefragt.
5. Bei Hintergrundwechsel oder neuer Interaktion die geplante Anfrage abbrechen.
   Keine nachträgliche Anfrage beim App-Start oder unmittelbar beim Zurückkehren;
   frühestens nach einem späteren qualifizierten Fahrtabschluss erneut prüfen.
6. Ein an die native API übergebener Anfrageversuch wird lokal vermerkt, auch
   wenn kein Dialog sichtbar wird oder der Aufruf scheitert. In Version 1 bleibt
   es bei diesem einen Versuch je Installation. `isAvailable() == false` ist
   noch kein Anfrageversuch; nicht in einer Schleife erneut prüfen.
7. Der manuelle Store-Link verändert weder Zähler noch Anfragevermerk.
   Store-Öffnen ist kein Nachweis für eine abgegebene Bewertung.
8. Updates erhalten Zähler und Anfragevermerk. Nach vollständigem Löschen der
   App-Daten/Neuinstallation kann die App eine frühere Anfrage nicht erkennen.

Eine spätere Wiederholung wäre eine getrennte Produktentscheidung, zum Beispiel
frühestens nach 120 Tagen, drei weiteren abgeschlossenen Fahrten und einer neuen
Version. Eine neue Buildnummer allein soll keine neue Anfrage ermöglichen.
Diese Werte sind eigene Vorschläge, keine von Google zugesicherte Quote.

## Technische Anknüpfungspunkte

| Vorhandene Stelle | Bedeutung für eine spätere Umsetzung |
| --- | --- |
| `lib/ui/info/info_sheet_main_content.dart` | „App bewerten“ neben dem unabhängigen Feedback-Eintrag; Deutsch/Englisch, Screenreader und Fehlermeldung berücksichtigen |
| `lib/ui/map/map_screen.dart`: `_refreshVoiceGuidance` | Verwendet den bestehenden Ankunftszustand auch bei ausgeschalteten Ansagen; prüft GPS-Alter und Genauigkeit |
| `lib/ui/map/voice_guidance.dart`: `finalDestinationReached` | Maßgebliches Signal für die endgültige Ankunft; keine Auswertung von TTS-Texten |
| `lib/ui/map/map_screen.dart`: `_finishRoute` | Nur der orangene Ankunftsbutton ruft diesen Abschluss und die Zählung auf; das Kreuz nutzt `_endRoute` ohne Zählung |
| `lib/ui/map/map_overlay/map_navigation_header_bar.dart` | Getrennte Callbacks für orangenen Ankunftsbutton (`onFinishRoute`) und Kreuz (`onEndRoute`) |
| `lib/ui/map/map_screen_model.dart` | Navigation, Pause und Routenwechsel bleiben die maßgebliche Zustandsquelle |
| `lib/api/initial_places_store.dart` | Vorhandenes Muster für serialisierte Änderungen und Schreiben über temporäre Datei; keine Vermischung mit Erststart-Flags |

Wichtige Einschränkung: `VoiceGuidance.setRoute()` übernimmt nur Routen mit
`supportsVoiceGuidance == true`. Bei reinem Karten-Fallback fehlt deshalb auch
das nutzbare Ankunftssignal. Solche Fahrten werden zunächst nicht automatisch
gezählt. Der Menüeintrag bleibt nutzbar. Eine allgemeine Ankunftserkennung wäre
eine eigene, sicherheitsrelevante Erweiterung; keine zweite GPS-Logik nur für
Bewertungen einführen.

Für den nativen Weg ist das Flutter-Paket
[`in_app_review`](https://pub.dev/packages/in_app_review) ein geeigneter Kandidat
(recherchierter Stand: 2.0.12). Es bietet `isAvailable()`, `requestReview()` und
`openStoreListing(appStoreId: ...)`. Vor Integration die tatsächliche SDK- und
Plugin-Kompatibilität durch Android-/iOS-Builds prüfen. Eine eigene native
Anbindung vermeidet das Plugin, erzeugt aber mehr Plattformcode und Pflegeaufwand;
der dauerhafte Link allein ist bereits mit `url_launcher` möglich.

Die Bewertungslogik sollte einen kleinen, testbaren Dienst mit einer einzigen
lokalen Zustandsdatei erhalten: abgeschlossene Fahrten und Anfragevermerk samt
optionalen Metadaten. Die erste Umsetzung speichert bewusst nur den auf drei
begrenzten Zähler, den Anfragevermerk und die Schemaversion; Zeit und App-Version
werden für einen einmaligen Versuch nicht benötigt. Ereignisse serialisieren;
doppelte Endaktionen absichern.
Eine Neuberechnung oder Fortsetzung darf keine neue Fahrtidentität erzeugen.
Vor dem automatischen Aufruf den Anfrageversuch zuverlässig speichern. Ist das
nicht möglich oder der Zustand beschädigt, die Anfrage auslassen und die App
normal weiterlaufen lassen. Ein später wieder lesbarer Zustand muss wieder
nutzbar sein. Keine Fahrwege, Koordinaten, Store-Konten oder Sterne speichern.

Bewertungen benötigen keine neue Standort-, Mikrofon- oder Benachrichtigungs-
berechtigung. Keine Startverzögerung, neue Netzprüfung oder Kopplung an Karten-
und Routing-Downloads einführen. Pluginfehler abfangen; bestehende Offline-
Funktionen und gebündelte Daten bleiben unabhängig. Ein manuell fehlgeschlagener
Store-Aufruf darf eine kurze, barrierefreie Meldung und den HTTPS-Link zum
erneuten Öffnen anbieten. Automatische API-Fehler bleiben ohne zusätzlichen
Fehlerdialog; siehe [Google Integrationshinweise](https://developer.android.com/guide/playcore/in-app-review/kotlin-java).

## Texte und Store-Regeln

- Menü Deutsch: **„App bewerten“**; Englisch: **“Rate the app”**.
- Optionaler erklärender Text beim Menüeintrag: „Teile deine Erfahrung im Store.
  Deine Bewertung hilft anderen, MunichWays zu entdecken.“ Englisch:
  “Share your experience in the store. Your review helps others discover MunichWays.”
- Website/Newsletter: „Du nutzt MunichWays im Alltag? Teile deine Erfahrung im
  App Store oder bei Google Play. Deine ehrliche Bewertung hilft anderen bei
  der Auswahl.“ Dazu beide Store-Links.
- Der automatische Dialog verwendet ausschließlich den nativen Store-Text.
  Für das „Text: to-do“ im Issue ist kein eigener Popup-Text erforderlich.

Apple untersagt eigene Bewertungs-Prompts; deshalb keinen vorgeschalteten
„Jetzt bewerten / Später“-Dialog bauen. Google untersagt vorgelagerte Fragen
wie „Gefällt dir die App?“ im In-App-Review-Ablauf. Keine Zufriedenheitsabfrage,
die nur zufriedene Nutzer zum Store und andere ausschließlich zum Support
schickt. Beide Wege müssen unabhängig zugänglich sein. Keine fünf Sterne
verlangen, Belohnungen anbieten oder Funktionen von einer Bewertung abhängig
machen. Quellen: [Apple, insbesondere 5.6.1 und 5.6.3](https://developer.apple.com/app-store/review/guidelines/),
[Google Anfragegestaltung](https://developer.android.com/guide/playcore/in-app-review#when-to-request),
[Google Bewertungsrichtlinie](https://support.google.com/googleplay/android-developer/answer/9898684?hl=en).

## Erfolg messen

Vor Veröffentlichung die Ausgangswerte aus App Store Connect und Play Console
festhalten, dann nach vier und acht Wochen vergleichen: neue Bewertungen pro
Woche, Sterneverteilung, wiederkehrende Kritik und – soweit bereits verfügbar –
Bewertungen im Verhältnis zu aktiven Nutzern. Plattform, Land und App-Version
getrennt betrachten. Absolute Zahlen allein können durch Saison, Reichweite
oder ein Release steigen; ein Vorher/Nachher-Vergleich beweist keine Kausalität.

Ein abgearbeiteter API-Aufruf ist keine gemessene Dialoganzeige oder Bewertung.
Es gibt keine verlässliche individuelle Rückmeldung über abgegebene Sterne.
Für Version 1 genügt die Store-Auswertung ohne neues Tracking-SDK. Falls später
Anfrageereignisse übertragen werden sollen, ist dies eine separate Entscheidung
einschließlich Prüfung der Datenschutzangaben. Ziel ist ein höheres Volumen
hilfreicher Rezensionen bei stabiler Zufriedenheit, keine garantierte Sternezahl.

## Vorgesehene Handy- und Beta-Abnahme nach Umsetzung

1. Bestehende Installation ohne Löschen ihrer Daten auf diese Version aktualisieren. Zwei
   Navigationen bis „Du hast das Ziel erreicht“ fahren und den orangenen Button
   „Beenden“ drücken: keine Anfrage. Eine Neuinstallation ist nicht nötig.
   Die dritte ebenso abschließen: erst nach dem Beenden kann der native Dialog
   erscheinen; während der Fahrt erscheint keine Bewertungsanfrage.
2. Eine Route nur planen, vor dem Ziel beenden, pausieren/fortsetzen und eine
   Route mit Zwischenzielen fahren: nur die endgültig abgeschlossene Fahrt
   zählt. Neuberechnung und mehrfaches Antippen erzeugen keine Doppelzählung.
3. Dieselben Schritte mit stummen Ansagen, Deutsch/Englisch und Rundroute prüfen.
   Bei Karten-Fallback ohne Ankunftssignal gibt es keine automatische Zählung;
   „App bewerten“ bleibt über das Info-Menü erreichbar.
4. Nach dem dritten Abschluss sofort eine neue Aufgabe beginnen oder die App
   in den Hintergrund schicken: kein verspäteter Dialog über der neuen Aufgabe.
   Ein späterer Fahrtabschluss darf die noch nicht übergebene Anfrage ermöglichen.
5. Offline bzw. ohne nutzbaren Store prüfen: kein blockierter Abschluss und
   normales Navigationsverhalten. Danach Netz wiederherstellen und über „App bewerten“
   den richtigen Store öffnen. Rückkehr zur App und neue Navigation funktionieren.
6. Nach einem Anfrageversuch weitere Fahrten, App-Neustart und App-Update testen:
   keine erneute automatische Anfrage in Version 1. Manueller Link und E-Mail-
   Feedback funktionieren weiterhin, auch mit großer Schrift und Screenreader.

Den Android-Dialog über einen internen Play-Testtrack mit passendem Testkonto
und App in dessen Play-Bibliothek prüfen. Bei Internal App Sharing ist das
Absenden deaktiviert; die Testbedingungen ersetzen keine Produktionsmessung.
Siehe [Google Testanleitung](https://developer.android.com/guide/playcore/in-app-review/test).
Unter iOS die Dialogdarstellung im Entwicklungsbuild prüfen; TestFlight zeigt
diesen Dialog nicht. Dort die Zählbedingungen über den vorgesehenen Testzugang
und den manuellen Store-Link auf einem echten Gerät prüfen, ohne für den Test
eine echte Rezension zu verlangen. Quelle:
[Apple requestReview(in:)](https://developer.apple.com/documentation/StoreKit/SKStoreReviewController/requestReview%28in%3A%29).
In Produktion ist ein ausbleibender Dialog allein kein Fehlernachweis.

## Umsetzung der ersten Ausbaustufe

- `AppReviewStore` speichert `app_review.json` unabhängig von Favoriten,
  Einstellungen und Erststartdaten. Änderungen laufen seriell über eine temporäre
  Datei. Beschädigte/unbekannte Daten werden nicht zurückgesetzt oder überschrieben.
- `AppReviewService` kapselt `in_app_review` 2.0.12 für automatische Anfragen.
  Der manuelle Weg nutzt `url_launcher`, damit ein fehlgeschlagener Start erkennbar
  bleibt: Android zuerst `market://`, danach HTTPS; iOS die HTTPS-Rezensionsseite.
- Nur `onFinishRoute` des orangenen Ankunftsbuttons führt über `_finishRoute`
  zu `AppReviewPromptController.destinationFinished()`. Das Kreuz führt über
  `onEndRoute` zu `_endRoute` ohne Zählung. Die bisherige zusätzliche Prüfung
  eines internen Ankunftsflags entfällt; die vorhandene Buttonanzeige bestimmt
  den eindeutigen Abschluss. Der normale Reset verhindert Doppelzählung.
- Bestehende Installationen beginnen bei fehlender Zählerdatei genauso bei null
  wie neue. Der Zähler bleibt über Neustarts und weitere Updates erhalten.
- Nach erfolgreicher Speicherung und zwei Sekunden Ruhe wird erneut geprüft,
  ob Karte und App im Vordergrund sind und keine neue Navigation, Planung,
  Ladeaktion, Tastatur oder modale Ansicht aktiv ist. Zeiger-/Tastatureingaben,
  Hintergrundwechsel, neue Navigation, Info/Einstellungen, Routenplaner und
  Fehlermeldungen verwerfen die geplante Anfrage. Die Tastaturbeobachtung erzeugt
  keinen zusätzlichen Tabstopp oder eigenen Semantikeintrag; eine neue Suche nach
  einem nahegelegenen POI bricht die Anfrage ebenfalls ausdrücklich ab.
- Auch nach asynchroner Verfügbarkeitsprüfung und Schreiben des Anfragevermerks
  wird die Zulässigkeit erneut geprüft. Bei Abbruch während der Speicherung wird
  die Reservierung zurückgenommen. Schlägt auch das Zurückschreiben fehl, bleibt
  vorsichtshalber der Anfragevermerk erhalten; es wird kein Dialog angefordert.
- Verfügbarkeitsprüfung und manueller Store-Start haben jeweils fünf Sekunden
  Zeitlimit; ein nativer Anfrageaufruf 30 Sekunden. Ausbleibende Anzeige oder Fehler
  nach nativer Übergabe verbrauchen den einmaligen Versuch. Ein späteres natives
  Ergebnis löst keinen zweiten Aufruf aus. Über die Darstellung nach Übergabe
  entscheidet weiterhin der Store.
- Der neue Menüeintrag ist Deutsch/Englisch verfügbar und behält den bestehenden
  E-Mail-Feedbackweg. Wiederholte manuelle Tipps während eines laufenden Öffnens
  teilen einen Aufruf. Nach Abschluss bleibt der Eintrag weiter nutzbar.

## Korrektur nach Handytest vom 11. Oktober

Der manuelle Store-Link wurde vor den Fahrten geöffnet. Schema 1 der noch
unveröffentlichten Testfassung setzte dabei `requestAttempted = true` und
unterdrückte die automatische Anfrage dauerhaft. Die fehlende Neuinstallation
war nicht die Ursache. Zusätzlich war die Zählung unnötig mit einem internen
Ankunftsflag statt ausschließlich mit dem eindeutigen orangenen Button gekoppelt.

Der manuelle Link verändert jetzt keine Bewertungsdaten. Schema 2 speichert nur
noch echte automatische Anfrageversuche. Beim Lesen von Schema 1 bleibt die
Fahrtzahl erhalten, der mehrdeutige Sperrvermerk wird einmalig verworfen. Schema 1
kann manuelles Öffnen und einen echten nativen Versuch nicht unterscheiden;
auch ein bereits in dieser unveröffentlichten Testfassung übergebener nativer
Versuch könnte deshalb einmal erneut ermöglicht werden. Schema 2 behält den
Vermerk anschließend dauerhaft, auch über weitere Updates hinweg.

## Diagnosedaten

Unter „Über & Quellenangaben“, nach Nutzungsbedingungen und vor der Version,
öffnet der dezente Eintrag „Diagnosedaten“ eine weitere Info-Unterseite mit
Griff, Zurück-Pfeil und Schließen-Kreuz. „Aktualisieren“ liest eine neue
Momentaufnahme; „Kopieren“ legt ausschließlich auf Knopfdruck den vollständigen
Bericht in die Zwischenablage, einschließlich eingeklappter Abschnitte.
Es erfolgt keine automatische Übertragung. Parameter und Werte stehen als
„Parameter: Wert“ linksbündig in einer gemeinsamen Textzeile, Werte fett.
Verwendet wird kleine Schrift (`bodySmall`), mit nur 3 dp Abstand oberhalb und
unterhalb der Zeile. Lange Texte dürfen gemeinsam umbrechen; die
System-Textskalierung bleibt wirksam. Die Versionszeile enthält „Version“ nur
einmal, auch im kopierten Bericht. „App & System“ ist sichtbar; „Einstellungen“,
„Karte & Navigation“ und „App-Bewertung“ sind zunächst eingeklappt und lassen sich wie
„Quellen & Routendienste“ öffnen. Ereignisse zeigen Zeit und Beschreibung
getrennt.

„Einstellungen“ steht vor „Karte & Navigation“ und zeigt Routenempfehlung,
Zoomtasten, wirksames Energiesparen, gewählte Darstellung, automatische
Neuberechnung, Kartentastenposition, gewählte Sprache, Radl-Vorrang-Netz,
weitere Strecken sowie aktivierte Sprachansagen. Die entsprechenden bisherigen
Zeilen wurden aus „Karte & Navigation“ verschoben. Die tatsächlich wirksame
Sprache und Darstellung bleiben unter „App & System“ erkennbar, insbesondere
bei System-/Automatikwahl. „Radnetz neu laden“ ist eine Aktion ohne einstellbaren
Parameter und erzeugt keine zusätzliche Zeile. Die Daten werden nur aus dem
vorhandenen Zustand gelesen. Streichkandidaten wurden vorgeschlagen, noch keine
Statusangaben entfernt.

Enthalten sind Appversion einschließlich lokaler Testbuildnummer,
Betriebssystemversion, Ausführungsmodus, Sprache, Darstellung, Bildschirmgröße,
Pixeldichte, Textskalierung und reduzierte Animationen. Hinzu kommen vorhandene
Karten-/Navigationszustände: initiale Ladung, Radwegbewertungen vorhanden,
Routenmodus und Profil, Routen- und Komfortdatenstatus, Navigation/Pause,
Sprachausgabe, automatische Neuberechnung und GPS-Signalstatus mit Genauigkeit
und Zeitpunkt des letzten angenommenen Updates. Es werden keine Koordinaten,
Ziele, Routengeometrien, Favoriten, Kontodaten oder API-Schlüssel aufgenommen.
Es gibt keine zusätzlichen Standort-, Netzwerk- oder Berechtigungsabfragen.

Die Bewertungsdiagnose zeigt den tatsächlichen gespeicherten Zähler (0–3),
den dauerhaften Anfragevermerk, das Ergebnis der letzten Store-Verfügbarkeits-
prüfung und maximal 20 zeitgestempelte Ereignisse aus der aktuellen App-Sitzung.
Diese unterscheiden insbesondere Speicherung, Timerplanung/-abbruch,
nicht freie Oberfläche, nicht verfügbaren Store, native Übergabe, Abschluss
und Fehler. Fehlerdetails enthalten nur den Fehlertyp, keine Rohdaten.
Der Zähler und der Anfragevermerk überleben Neustarts; Ereignisse und
Verfügbarkeitsprüfung bleiben ausschließlich im Arbeitsspeicher. „Nativer
Aufruf abgeschlossen“ bestätigt weder eine Dialoganzeige noch eine Rezension.
Lesefehler werden als unbekannt/nicht lesbar angezeigt, niemals als null Fahrten
oder als Erlaubnis für einen neuen Versuch. Diagnoseanzeigen ändern den
Bewertungszustand nicht und lösen keine Store-Anfrage aus.

Handytest: Nach jeder endgültigen Ankunft den orangenen „Beenden“-Button nutzen.
Bei der dritten Fahrt mindestens zehn Sekunden ohne weitere Bedienung warten,
bevor Info → Über & Quellenangaben → Diagnosedaten geöffnet wird. Sofortiges
Öffnen von Info würde wie jede neue Aktion den noch geplanten Timer abbrechen.
Zähler 1/3, 2/3, 3/3 und Ereignis „an native API übergeben“ prüfen. Eine vierte
Fahrt darf keinen zweiten nativen Aufruf erzeugen. Nach Neustart bleiben 3/3
und Anfragevermerk erhalten; die Sitzungshistorie beginnt leer. Bericht kopieren,
Aktualisieren, Zurück-Pfeil, System-Zurück, große Schrift und Englisch prüfen.

## Technische Verifikation und Arbeitsstand

Die finale Darstellung verwendet kleine Schrift und linksbündige
„Parameter: Wert“-Zeilen mit fettem Wert. Version erscheint nur einmal.
Feedback und die letzte Diagnoseformatierung wurden vom Nutzer am Handy
bestätigt. Dies belegt keine native Dialoganzeige oder abgegebene Bewertung.

Finale Formatprüfung, `git diff --check`, statische Analyse und 98 gezielte
Tests sind erfolgreich. Die vollständige Suite besteht mit 596 erfolgreichen
Tests; ein optionaler Live-API-Test ohne `RADLNAVI_LIVE_TEST=true` ist
übersprungen. Regressionen umfassen Zählung, Updates/Neustarts, manuelle
Storelinks, gleichzeitige Zugriffe, Abbruch, Zeitlimits, Fehlererholung,
readonly Diagnosen, Kopieren, Aufklappen und große Schrift in Deutsch/Englisch.
Der Quellen-Aufklappbereich erhielt die notwendige lokale Material-Fläche.

Der Android-Release-Build der vorherigen Zählerkorrektur mit Flutter 3.47.6
war erfolgreich (88,6 MB, lokale Testdefines). Für die anschließenden
Dart-/UI-Anpassungen wurde er nicht wiederholt; die letzte Darstellung wurde
stattdessen per Handytest bestätigt. Ein iOS-Build ist unter Windows nicht
möglich. Die vorbestehende Versionsänderung und die separate Analyse zu
Reststrecke/Restzeit gehören nicht zum Feature-Commit.

Die Umsetzung wird auf `257-app-store-bewertungen` committed und gepusht.
Es wurde kein Pull Request beauftragt.
