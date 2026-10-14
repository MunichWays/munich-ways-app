# GPX-Routenübergabe: geprüfter Stand

14. Oktober 2026, Feature-Branch `feature/gpx-route-transfer` in Web/Backend und App.
Android-Testbuild **65**, App-Version 3.2.1+79; RadlNavi 2.3.5.

| Prüfung | Ergebnis |
| --- | --- |
| Flutter 3.47.6: statische Analyse | Keine Fehler oder Warnungen |
| Vollständige App-Testsuite | 669 bestanden; 1 opt-in Livetest nicht aktiviert |
| Tatsächlicher Web-GPX-Export → App-Parser | Gemeinsame GPX-Testdatei erfolgreich importiert; Geometrie, 2 Zwischenziele und alle 6 Manöver erhalten |
| Snapshot-Persistenz und Wiederherstellung | Originalstrecke erhalten; gleiche Namen ersetzen keine anderen Importe; Index wird ohne Geometrien geladen |
| Verspätete Antworten und Speicherfehler | Neue Auswahl nicht überschrieben; fehlender Snapshot blockiert die normale Routenberechnung nicht |
| Android-Testbuild | Erfolgreich erzeugt; keine Installation oder App-Ausführung durch den Agenten |
| Frontend | 50 Tests bestanden; Produktionsbuild erfolgreich |
| Backend | 84 Tests bestanden |
| Eingabeprüfung mit Python `-O` | 5 gezielte Linkdiensttests bestanden; Validierung unabhängig von Python-Assertions |
| Echter lokaler HTTP-Test | Teilen/Lesen desselben Snapshots und CORS erfolgreich; Testserver beendet |
| Nginx im tatsächlichen Basisimage | Syntaxprüfung und HTTP-Aufruf von `/r/<id>` erfolgreich; fehlende statische Dateien liefern HTTP 404; Testcontainer beendet |
| Diff-/Formatprüfung | Beide Repositories ohne Whitespacefehler; geänderte Dart-Dateien formatiert |

Die Builds melden bestehende React-Lint-/Browserslist- und Android-Kotlin-
Migrationshinweise. Die Prüfungen wurden nicht deaktiviert. Die debouncten MUI-
Oberflächentests haben begründete Zeitlimits für langsame CI-/Build-Rechner.

Vor Übergabe wurden Gradle beendet und verbliebene Flutter-/Dart-/Build-/Run-
Prozesse kontrolliert; kein laufender Prozess für diese Arbeitsbereiche.

Android-Handytest vom Nutzer erfolgreich bestätigt; Lauf beendet und USB getrennt.
Nicht geprüft: iOS-Build und native iPhone-Abläufe sowie gesonderter Fahrtest mit Ansagen. Hosting und GCS-
Speicher wurden noch nicht veröffentlicht; App-/Universal-Links benötigen diese
Veröffentlichung sowie den zusätzlichen Play-App-Signing-Fingerabdruck. Die
vorbereitete Domainzuordnung enthält zunächst das lokale Android-Debug-Zertifikat.

Abschlussprüfung vor dem ausdrücklich beauftragten Commit und Push beider Repositories.
Versionsänderungen und lokale Docker-Befehle werden wie gewünscht mitgenommen.
Der Android-Releasebuild einschließlich R8 ist nach der Korrektur der Gradle-
Projekt-Auswertungsreihenfolge erfolgreich; ProGuard verweist auf den richtigen Buildpfad.

Testschritte und Einrichtung: [Umsetzungsdokument](gpx-route-transfer-implementation.md).
