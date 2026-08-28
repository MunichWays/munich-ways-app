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
* change version in code pubspec.yaml and commit to master as "Bump version to 2.0.2+26"
* Update the bundled RadlVorrang network in VS Code: `Terminal` > `Run Task...` > `RadlVorrang-Netz aktualisieren`
  * The task downloads the current network, validates it and only then replaces the offline asset.
  * Review and commit the changed file in `assets/radlnetz/` together with the release.
* commit and push

### iOS

#### Github Actions

* In Browser open iOS Testflight Action: https://github.com/MunichWays/munich-ways-app/actions/workflows/ios-testflight.yml
* Select "run workflow"
* New build is uploaded to Testflight

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

* tag current state and push the tags
    * `git tag -a 3.1.2+39 -m "3.1.2+39 open beta"`
    * `git push origin 3.1.2+39` 
* this will trigger the workflow, see `workflows/android-release`

#### Local

1. Get release.keystore from Sven and place it in `android/app/`
2. Get Credentials for keystore from Sven and add them to `android/release_keystore.properties`:
```
# Do not add to version control!
# This contains the credentials to sign the android app and should only be on your local machine
# or the build server
storePassword=<Password>
alias=<Alias>
aliasPassword=<Password>
```
3. Run `flutter build apk` or see the other output options

#### How to test
- Handy per USB Kabel anschließen
- Voraussetzung Handy einrichten: Einstellungen > Entwickleroptionen > USB-Debugging aktivieren
- im Android Studion erscheint das USB Symbol bei physical device- z.B Samsung Sm F711B
- im Visual Studio code App starten: Button run (grüner Pfeil) oder flutter run -v
  C:\Users\Thomas\dev\flutter\munich-ways-app> flutter run -v  
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
