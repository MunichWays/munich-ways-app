# MunichWays App

Mobile App displaying the Radlvorangnetz in Flutter for iOS and Android. For more information see: munichways.de

## Development Setup

Development principles, required checks, debugging guidance, and regression
scenarios are documented in [CONTRIBUTING.md](CONTRIBUTING.md). AI coding agents
must additionally follow [AGENTS.md](AGENTS.md).

### Geoapify address search

Ask Thomas for the API key or go to https://myprojects.geoapify.com/, mail@munichways.de, project App-MunichWays

The Geoapify API key is injected at build time and must not be committed:

```
flutter run --dart-define=GEOAPIFY_API_KEY=<your-api-key>
```

Use the same `--dart-define` for release builds.

The Android release workflow expects a GitHub Actions secret named
`GEOAPIFY_API_KEY`.

### Setup Git hooks for formatting

The build server checks if all files are formatted correctly with `dart format`. If not it will fail.
To ensure that the formatter is run locally before a commit set the hooksPath property: `git config --local core.hooksPath ./githooks`

## Release

Android und iOS werden manuell über GitHub Actions hochgeladen. Tags und
GitHub-Releases sind dafür nicht erforderlich und starten keinen Upload mehr.
`pubspec.yaml` bleibt die gemeinsame Versionsquelle für beide Plattformen.

1. `version` in `pubspec.yaml` erhöhen, beispielsweise von `3.2.1+80` auf
   `3.2.1+81`. Die Zahl hinter `+` ist die Buildnummer.
2. Änderungen committen, pushen und den geprüften Branch nach `master` mergen.
3. Unter **Actions** den gewünschten Workflow öffnen: **Android Release** oder
   **iOS TestFlight Release**. **Run workflow** wählen und `master` auswählen.
4. Für einen Store-Upload die Upload-Option aktiviert und
   **Only check the version** deaktiviert lassen. Beide Workflows getrennt starten.

Vor einem Upload muss die Buildnummer höher sein als die höchste vom jeweiligen
Store gemeldete Buildnummer. Android prüft Google Play einschließlich aller
Tracks, APKs und App Bundles. iOS prüft die Builds der App in App Store Connect
über alle App-Versionen und Seiten hinweg, auch bereits hochgeladene Builds, die
noch verarbeitet werden. Bei API-/Berechtigungsfehlern wird vor dem Build abgebrochen.
Es wird keine Nummer automatisch erhöht oder aus einem Tag übernommen.

Dieselbe Version, z. B. `3.2.1+81`, kann einmal nach Google Play und einmal nach
TestFlight hochgeladen werden. Der zweite Plattform-Upload benötigt keine neue
Nummer. Ein weiterer Upload in denselben Store benötigt dagegen eine höhere
Buildnummer. Nach einem fehlgeschlagenen Upload prüfen, ob der Store das Paket
bereits angenommen hat; die nächste Versionsprüfung berücksichtigt den Store-Stand.

**Prüfbuild ohne Upload:** Die jeweilige Upload-Option deaktivieren. Damit wird
das signierte Paket gebaut, ohne einen Store-Upload oder Store-Versionsvergleich
zu starten. Die Buildnummer darf wiederverwendet werden. Das Android-App-Bundle
steht anschließend als Workflow-Artefakt `appbundle` bereit.

**Nur Versionsprüfung:** **Only check the version** aktivieren und die
Upload-Option aktiviert lassen. Der Workflow prüft die Nummer gegen den Store,
führt aber keinen Build und keinen Upload aus. Ist zusätzlich die Upload-Option
deaktiviert, wird nur die Versionsangabe in `pubspec.yaml` validiert.

Upload-Läufe derselben Plattform werden nacheinander ausgeführt. Android und
iOS können unabhängig voneinander laufen. Die Workflow-Zusammenfassung nennt
jeweils die geprüfte Version und die höchste Store-Buildnummer.

Vor einem Release auch das gebündelte RadlVorrang-Netz bei Bedarf aktualisieren:
in VS Code **Terminal > Run Task... > RadlVorrang-Netz aktualisieren**. Die
Änderung in `assets/radlnetz/` prüfen und zusammen mit dem Release committen.

### iOS

#### Github Actions

[Workflow iOS TestFlight Release öffnen](https://github.com/MunichWays/munich-ways-app/actions/workflows/ios-testflight.yml).
`upload_to_testflight` steuert den TestFlight-Upload; `version_check_only` führt
nur die oben beschriebene Versionsprüfung aus. Ein Upload startet keine
App-Store-Veröffentlichung und reicht die App nicht zur Prüfung ein.

##### Certificate renewal
Apple Distribution certificates expire after **1 year**. When that happens, `cert` will generate
+ a new one automatically for *local* runs (a dev machine's keychain accepts that), but CI will keep failing until someone
+ re-exports the (now current) certificate as a fresh `.p12` and updates `IOS_DIST_CERT_P12_BASE64`/`IOS_DIST_CERT_P12_PAS
     +SWORD` — the same steps as the initial setup above.

#### Fastlane locally

##### In short
* From the ios/ directory: `bundle exec fastlane beta`
* Don't forget: bump the build number in pubspec.yaml first (version: 3.1.x+YY), otherwise App Store Connect will reject the build as a duplicate. 

##### More Details
See detailed fastlane docs for setup, lanes, credentials, and troubleshooting: [ios/fastlane/README.md](ios/fastlane/README.md).**

#### Manual build/archive (alternative)

* `flutter build ios`
* in XCode `Product -> Archive`

#### Screenshots

* 6,5" - iPhone 12 Pro Max
* 5,5" - iPhone 8 Plus
* iPad - iPadPro (12.9-inch)

### Android

#### Github Actions

[Workflow Android Release öffnen](https://github.com/MunichWays/munich-ways-app/actions/workflows/android-release.yml).
`upload_to_play` steuert den Upload in den Google-Play-Beta-Track;
`version_check_only` führt nur die oben beschriebene Versionsprüfung aus.
Das gebaute AAB wird als Workflow-Artefakt gespeichert. Ein GitHub-Release oder
Tag muss nicht angelegt werden. Der Upload bleibt im Beta-Track.

#### Local

Für lokale Handytests ist kein offizieller Release-Keystore erforderlich.
Ohne vollständige Release-Signierung verwendet das Projekt den lokalen
Debug-Schlüssel; ein gewählter Release-Build bleibt im Release-Modus.
Die folgenden Schritte gelten für die offizielle Signierung zur Veröffentlichung.

1. Get release.keystore from Sven and place it in `android/app/`
2. Get Credentials for keystore from Sven and add them to `android/release_keystore.properties`:
```
# Do not add to version control!
# This contains the credentials to sign the android app and should only be on your local machine
# or the build server
storeFile=release.keystore
storePassword=<Password>
alias=<Alias>
aliasPassword=<Password>
```
3. Run `flutter build apk` or see the other output options

#### How to test

- Handy per USB anschließen; unter Entwickleroptionen USB-Debugging aktivieren.
- In VS Code unter `Run and Debug` die Konfiguration
  `munich-ways-app (release mode)` auswählen und mit
  `Run Without Debugging` starten. Für Performance-Untersuchungen steht
  `profile mode` zur Verfügung.
- Alle lokalen Startkonfigurationen benötigen denselben Geoapify-Schlüssel.
  Der Vorbereitungstask erhöht automatisch `LOCAL_TEST_BUILD`; im
  Info-Bereich der App erscheint die Kennung als `Testbuild N`.
- Installation vollständig abwarten, den VS-Code-Lauf beenden und die App am
  Handy über `Stopp erzwingen` schließen. USB abziehen und die App über
  ihr Symbol frisch starten. App-Daten für normale Update-Tests behalten.
- Bei Fehlern USB wieder anschließen und vor einem App-Neustart die Logs
  mit `Straßentest: Logs einsammeln` sichern. App-Diagnoselogging in
  Profile/Release benötigt eine gesonderte Konfiguration.
- Details zum lokalen Setup und zum bestehenden Skriptstart stehen in
  [CONTRIBUTING.md](CONTRIBUTING.md#local-phone-tests-in-vs-code).
-----------
#### How to change code 
 Code Änderung mit Android Studio
 - Android Studion starten
 - Handy anschließen, siehe oben
 - unten rechts auf den aktuellen Branch klicken
 - ggf. auf Master klicken und mit "Update" die neueste Version holen
 - im Scrumboard issue auswählen oder anlegen und die Nummer merken
 - auf Master klicken und "New branch from selected" klicken
 - Branchname <issue nummen>_<kurzer Titel>
 - Stelle suchen und ändern
 - oben rechts auf den grünen Run button klicken
 - bei Fehlern ist ggf. ist ein flutter ubgrade nötig (Sven fragen)
 - Änderung am Handy testen
 - Links in "Change" geänderte Dateien auswählen, darunter eine kurze Commit Nachricht eingeben und unten auf "Commit and Push" klicken
 - push mit Token wählen, ggf. Token erneuern wenn abgelaufen in github neuen Token generieren
 - Wenn gepushed gehe im Browser zu github pulls: https://github.com/MunichWays/munich-ways-app/pulls
 - Pull request für den Branch anstoßen, geht an Sven zum Review
