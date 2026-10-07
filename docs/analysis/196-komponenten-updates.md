# #196 – Komponenten-Updates für 3.2.0

Stand: 7. Oktober 2026. Branch: `feature/196-component-updates`.

## Anforderung und Umsetzung

Veraltete Build-Komponenten und Plugins aktualisieren, ohne Start, Offline-Daten,
Karte, Standort und Sprachansagen zu gefährden. Die App-Version bleibt
`3.2.0+72`.

| Komponente | Vorher (Lockfile/SDK) | Jetzt | Nutzen |
| --- | --- | --- | --- |
| Flutter / Dart | 3.44.7 / 3.12.2 | 3.47.6 / 3.13.5 | Aktuelle Stable-Reihe mit Android-, iOS- und Tooling-Korrekturen |
| MapLibre | 0.25.0 | 0.27.1 | Schnellere große Datenupdates, Activity-Recovery und native Fehlerkorrekturen |
| Cache Manager | 3.4.1 | 3.4.5 | Korrekte Cache-Dateilöschung, zuverlässigere Metadatenpersistenz und Fehlerweitergabe |
| Geolocator | 14.0.2 | 14.1.1 | Aktuelle Android-/Apple-Implementierungen |
| Wakelock | 1.3.2 | 1.8.0 | Activity-Wechsel ohne verlorenes Wakelock-Toggle, aktualisierte native Integration |
| Package Info | 8.3.1 | 10.2.2 | Aktuelle Android-/Apple-Buildintegration |
| WebView | 4.13.0 | 4.14.1 | Aktuelle Android-/WKWebView-Implementierungen |
| Path Provider | 2.1.5 | 2.1.6 | Aktuelle native Integration; Android 2.3.1 korrigiert einen Release-Klassenladefehler |
| Kotlin-Plugin | 2.2.20 | 2.4.10 | Kompatibel mit den aktualisierten nativen Plugins und der vorhandenen Build-Kombination |

Weitere kompatible Hilfspakete und transitive Abhängigkeiten sind im
`pubspec.lock` aktualisiert. FVM, lokale Qualitätsprüfung und alle CI-Workflows
verwenden denselben Flutter-Pin. Die lokale Qualitätsprüfung liest die Version
aus `.fvmrc`, statt einen zweiten Pin zu pflegen. Der bisherige Dart-Sprachstand
bleibt erhalten; die Flutter-Mindestversion erzwingt den aktuellen SDK, ohne
eine sachfremde Neuformatierung der ganzen Anwendung auszulösen.

`dio_cache_interceptor_file_store` war ausschließlich im Pubspec/Lockfile
vorhanden und wird entfernt. Die App verwendet für Radnetz und POIs weiterhin
`flutter_cache_manager`; gebündelte Offline-Daten bleiben unabhängig davon.

Die Release-Actions verwenden veröffentlichte Node-24-Versionen: Checkout
7.0.1, Setup Java 6.0.1, Upload Artifact 7.0.1, GitHub Release 3.0.3 und Google
Play Upload 1.1.5. Java 21 wird auch in den PR-Prüfungen explizit eingerichtet.

Der neue Analyzer erkennt einen Future-Return im Routing-`try`-Block. Der
Fallback bei fehlender Direct-Provider-Unterstützung wird vor diesen Block
verschoben. Ein BRouter-Fehler darf keinen zweiten BRouter-Versuch auslösen;
eine spätere Anfrage muss sich wieder erholen können.

`http 1.6` sendet JSON gemäß RFC 8259 ohne ergänzten `charset`-Parameter. Der
Request-Test prüft den neuen exakten Content-Type und weiterhin den vollständigen
JSON-Inhalt mit allen Routenabschnitten.

## Bewusst offen oder beibehalten

- **Built-in Kotlin:** Noch nicht aktivierbar. Das aktuelle `flutter_tts 4.2.5`
  wendet zwingend `kotlin-android` und `kotlinOptions` an. Die App verwendet
  bereits `compilerOptions`, behält aber `android.builtInKotlin=false` und das
  App-Kotlin-Plugin. Erst nach einem kompatiblen TTS-Release beide Plugin-
  Deklarationen entfernen, Built-in Kotlin aktivieren und erneut native Builds
  sowie Sprachansagen prüfen. Kein lokaler Patch am Pub-Cache.
- `android.newDsl=false` bleibt gemäß Flutter-Migrationsleitfaden bestehen.
- **Java-8-Zukunftswarnungen:** Der Release-Build ordnet sie dem aktuellen
  `geolocator_android 5.1.1+1` zu. Dessen Gradle-Datei setzt weiterhin
  `sourceCompatibility` und `targetCompatibility` auf Java 8. Die App selbst
  verwendet bereits Ziel 17. Keine globale Zielüberschreibung oder
  Warnungsunterdrückung; dieser Punkt benötigt ein entsprechendes Plugin-Update.
- AGP 9.0.1 und Gradle 9.1 bleiben bei der vorhandenen kompatiblen Kombination;
  ein zusätzlicher Build-System-Wechsel bringt für diesen Schritt keinen
  nachgewiesenen Vorteil. JDK 21 ist wegen MapLibre erforderlich, die App selbst
  behält ihr Java-/Kotlin-Ziel 17.
- Wakelock 1.8.1 kollidiert über `dbus` mit `battery_plus`; 1.8.0 enthält bereits
  die relevanten mobilen Korrekturen.
- Größere API-Wechsel bei `cached_network_image`, `http_interceptor`,
  `equatable`, `latlong2` und Cupertino Icons werden nicht allein wegen einer
  höheren Versionsnummer übernommen.
- Der F-Droid-Eintrag beschreibt einen historischen, fest gepinnten Build von
  3.1.22 und wird nicht rückwirkend geändert.
- iOS-Archivierung/TestFlight und native Gerätetests benötigen macOS bzw.
  physische Geräte; ein Windows-Check ersetzt sie nicht.
- Release-Builds nach Tests mit `flutter build apk --release` bzw.
  `flutter build appbundle --release` starten. `--no-pub` überspringt auch die
  Release-spezifische Plugin-Registrierung; ein zuvor für Tests generiertes
  Register kann dann irrtümlich `integration_test` referenzieren. Die CI verwendet
  bereits den regulären Build-Befehl. Generierte Registrierungsdateien nicht
  von Hand bearbeiten.

## How to test – Handy-Praxistest und Beta

Auf Android und iPhone möglichst sowohl Update einer vorhandenen Installation
als auch Neuinstallation prüfen. Auf einem älteren/kleineren Android-Gerät
Startzeit, flüssige Kartenbewegung und Absturzfreiheit vergleichen.

1. **Start und Offline-Daten:** Kalt und warm starten, dann im Flugmodus erneut
   öffnen. Das gebündelte Münchner Radnetz muss verfügbar bleiben; vorhandene
   Ziele/Einstellungen müssen nach einem Update erhalten bleiben. Nach Rückkehr
   des Netzes müssen zusätzliche Bewertungen und POIs wieder laden. Bereits
   gecachte Kartenbereiche prüfen; eine vollständig offline verfügbare
   Hintergrundkarte ist keine neue Zusage.
2. **Cache und POIs:** Bewertungen neu laden, App schließen und erneut öffnen.
   Trinkwasser, Toiletten und Reparaturstationen ein-/ausschalten. Bei langsamem
   oder unterbrochenem Netz darf die Karte bedienbar bleiben; nach Netzrückkehr
   erneut laden. Die vorhandene nutzbare Darstellung darf nicht verloren gehen.
3. **Karten-Recovery:** Hell/dunkel wechseln, zoomen, verschieben, App in den
   Hintergrund schicken und zurückkehren. Auf Android auch Bildschirm drehen
   bzw. eine Activity-Neuerstellung provozieren. Radnetz, POIs, Standort und
   aktive Route müssen wieder erscheinen; keine doppelten Layer oder Marker.
4. **Routing und Standort:** Standard- und direkte Route mit Zwischenziel planen,
   wechseln und Navigation starten. Kurz und länger abweichen, GPS/Netz
   vorübergehend verlieren, wiederherstellen und erneut fahren. Keine doppelte
   Neuberechnung; nach Fehler muss eine erneute Anfrage möglich sein. Pausieren,
   fortsetzen und beenden prüfen. Auf iPhone auch längere Navigation mit
   gesperrtem Bildschirm und anschließendes Entsperren prüfen.
5. **Sprache und Wachhalten:** Abbiegeansagen über Lautsprecher und Bluetooth,
   Unterbrechung durch Anruf/Medien, anschließend Wiederaufnahme prüfen.
   Spracheingabe starten, stoppen, abbrechen und nach verweigerter Berechtigung
   erneut versuchen. Bildschirm bei Navigation/Wachhalten beobachten; nach
   Beenden muss der normale Ruhemodus zurückkehren. Energiesparen ein/aus prüfen.
6. **Info und Inhalte:** Version 3.2.0 anzeigen lassen, Straßendetails/Foto und
   einen WebView-Inhalt öffnen und schließen. Externe Links müssen weiterhin
   funktionieren. Primäre Abläufe mit TalkBack/VoiceOver und großer Schrift
   prüfen; kein abgeschnittener Text oder unbedienbarer Hauptbutton.
7. **Beta:** Android-Beta und iOS-TestFlight mit diesen Szenarien über mehrere
   Fahrten testen. Neue Abstürze, auffälligen Akku-/Speicherverbrauch,
   Kartenartefakte und fehlende Ansagen mit Gerät, OS, genauer Uhrzeit und
   reproduzierbaren Schritten melden. Vor Veröffentlichung iOS-Archiv und
   Store-Validierung der aktualisierten nativen Pakete prüfen.

## Validierung und verbleibender Folgeschritt

- Lokale technische Prüfung: Analyzer ohne Befund, Format-/Diff-Prüfung
  erfolgreich, 402 Tests bestanden. Der zunächst übersprungene optionale
  Live-Test wurde separat erfolgreich ausgeführt. Android-Release-APK gebaut.
- Nutzer-Rückmeldung: erste Android-Handytests erfolgreich. Anschließend
  iOS-TestFlight-Build erfolgreich; Suche, Sprachansage bei Zielsuche, Routing
  und Navigationsansagen funktionieren. Die übrigen Beta-Szenarien oben sind
  dadurch noch nicht vollständig abgedeckt.
  Der [iOS-CI-Lauf für Commit 83493f2](https://github.com/MunichWays/munich-ways-app/actions/runs/37637237146)
  ist ebenfalls erfolgreich abgeschlossen.
- Upstream-Nachprüfung: TTS-Migrations-PRs
  [#643](https://github.com/dlutton/flutter_tts/pull/643) und
  [#656](https://github.com/dlutton/flutter_tts/pull/656) sind weiterhin offen.
  Auch der aktuelle Geolocator-Upstream setzt Java-Quell-/Zielversion 8.
- Ein späteres veröffentlichtes TTS-Update muss die eigene Anwendung von KGP
  entfernen und `compilerOptions` unterstützen. Danach App-KGP-Deklarationen
  entfernen und Built-in Kotlin aktivieren; `android.newDsl=false` separat
  nach Flutter-Unterstützung beurteilen. Geolocator muss sein Java-Ziel selbst
  modernisieren. Beide Änderungen mit regulärem Android-Release-Build prüfen;
  auf dem Handy Ansagen, Unterbrechung/Wiederaufnahme sowie Standort-Recovery
  und Navigation erneut testen.
- Eine sofortige Migration erfordert eigene, reproduzierbar gepinnte
  Plugin-Versionen und deren weitere Pflege. Das ist ein zusätzlicher
  Wartungsumfang gegenüber den bislang verwendeten veröffentlichten Paketen.

## Primärquellen

- [Flutter Stable-Changelog](https://github.com/flutter/flutter/blob/stable/CHANGELOG.md)
- [Built-in-Kotlin-Migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
- [Kotlin-/Gradle-/AGP-Kompatibilität](https://kotlinlang.org/docs/gradle-configure-project.html)
- [MapLibre-Changelog](https://pub.dev/packages/maplibre_gl/changelog)
- [Cache-Manager-Changelog](https://pub.dev/packages/flutter_cache_manager/changelog)
- [Wakelock-Changelog](https://pub.dev/packages/wakelock_plus/changelog)
- [Package-Info-Changelog](https://pub.dev/packages/package_info_plus/changelog)
- [Path-Provider-Android-Changelog](https://pub.dev/packages/path_provider_android/changelog)

Technische Prüfergebnisse werden in PR/Übergabe dokumentiert. Eine spätere kurze
Story-Zusammenfassung erhält nach Veröffentlichung die tatsächlichen Branch-
und PR-Links; Story und Board wurden durch diesen lokalen Arbeitsschritt nicht
geändert.
