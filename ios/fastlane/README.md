# MunichWays — iOS Fastlane

This folder contains the Fastlane setup for building and uploading the iOS app to TestFlight. **All Fastlane-specific instructions live here**; the repository root [README.md](../../README.md) only points to this file.

## Prerequisites

- Xcode (including Command Line Tools). If needed: `xcode-select --install`
- Ruby and [Bundler](https://bundler.io/) on your machine
- Apple Developer Program access for the app’s team and bundle identifier

Official Fastlane install overview: [Installing fastlane](https://docs.fastlane.tools/#installing-fastlane)

## First-time setup

From the repository root:

```sh
cd ios
bundle install
bundle exec fastlane --version
```

Always prefer **`bundle exec fastlane …`** so you use the Fastlane version pinned in `Gemfile.lock`.

## Configuration

| File / folder | Purpose |
|---------------|---------|
| `Fastfile` | Lanes — safe to commit |
| `Appfile` | `app_identifier`, `apple_id`, team IDs — **gitignored** in this repo; maintain your own copy locally or via secure distribution |
| `.env` | Optional local secrets (e.g. app-specific password) — **gitignored**; never commit |
| `metadata/` | App Store listing text per locale (`deliver`) — safe to commit; see **Lane: `ios metadata`** below |
| `screenshots/` | Optional per-locale PNGs for `deliver` — populated by **`ios screenshots`** (not committed by default) |

Build outputs and signing exports in `ios/` (`.ipa`, `.mobileprovision`, `.p12`, `.cer`, etc.) are listed in `ios/.gitignore` and must not be committed.

## Lane: `ios beta`

Runs: **`cert`** → **`sigh`** → **`build_app`** (gym) → **`upload_to_testflight`**.

- Ensures a distribution certificate and an App Store provisioning profile for `com.munichways.app`
- Archives `Runner.xcworkspace` / scheme `Runner`, exports an App Store IPA
- Uploads the build to App Store Connect / TestFlight

```sh
cd ios
bundle exec fastlane ios beta
```

Use `bundle exec fastlane ios beta --verbose` if you need full logs.

## Lane: `ios metadata` (App Store listing text)

Text files under `fastlane/metadata/` are uploaded to App Store Connect by this lane using **`deliver`**. Uploads **metadata only** (no IPA). Use it to create or update an app version’s description, keywords, What’s New, URLs, etc.

### Directory layout

- **`metadata/de-DE/`** — German store listing
- **`metadata/copyright.txt`** — Copyright line (global).

### Edit then push

1. Update the `.txt` files (description, What’s New in `release_notes.txt`, URLs, etc.).
2. Optionally set **`APP_STORE_VERSION`** to the App Store version string you are editing (must match **Version** in App Store Connect, e.g. `3.0.0`):

   ```sh
   export APP_STORE_VERSION=3.0.0
   ```

3. Run:

   ```sh
   cd ios
   bundle exec fastlane ios metadata
   ```

Screenshots are **not** uploaded by this lane (`skip_screenshots: true`). To upload listing text **and** PNGs from `fastlane/screenshots/`, use **`ios metadata_and_screenshots`** (see below).

**Authentication:** Same as [Upload authentication](#upload-authentication-testflight-and-deliver) below — App Store Connect API key (`ASC_*`) is recommended; Apple ID + app-specific password can work for `deliver` in many setups.

## Lane: `ios screenshots` (App Store marketing PNGs)

Runs **`flutter test`** on an **iOS Simulator** with `--dart-define=STORE_SCREENSHOTS=true`, which drives three scenes (map idle with Radl-Netz, active route, street details). PNGs are written inside the app data container under **`Library/Caches/store_screenshots/`** (iOS **`path_provider`** maps “temporary” / cache APIs to **`NSCachesDirectory`**, not `tmp/`). Flutter **uninstalls the app when the integration test finishes**, so a one-shot `get_app_container` after the run often finds nothing. This lane **polls `simctl get_app_container … data` in a background thread** while `flutter test` runs and copies any `*.png` into **`integration_test/screenshots/`**, then into **`fastlane/screenshots/de-DE/`** for `deliver` or manual upload.

**Prerequisites**

- Flutter SDK on `PATH`, repo dependencies installed (`flutter pub get` from the repo root).
- From **`ios/`**, run **`bundle install`** at least once so [ios/Gemfile](../Gemfile) (includes **CocoaPods** for this lane) is satisfied.
- A **booted** iOS Simulator (pick a device size you care about for the store, e.g. iPhone 15 Pro Max).
- Network access for live Munich Ways / routing / map tiles (no mocking in this workflow).

The lane runs **`bundle install`**, **`bundle config set --local bin vendor/bundle_binstubs`**, **`bundle binstubs cocoapods --force`**, and **`bundle exec pod install`** under `ios/`, then runs Flutter with **`PATH`** prefixed so the **`pod`** binary comes from **`ios/vendor/bundle_binstubs`** (Bundler 4 no longer supports **`bundle binstubs --path=…`**). That avoids Flutter’s “CocoaPods is installed but broken” error when a global `pod` was installed with a different Ruby than the one on your `PATH`. If you run **`flutter test …` without Fastlane**, you still need a working **`pod`** on `PATH` (fix or reinstall CocoaPods, or prepend the same `ios/vendor/bundle_binstubs` path after generating binstubs once).

**Steps**

1. Boot a simulator and copy its UDID (Xcode → Devices and Simulators, or `xcrun simctl list devices booted`).
2. From **`ios/`**:

   ```sh
   export SCREENSHOT_SIMULATOR_UDID='<paste UDID>'
   bundle exec fastlane ios screenshots
   ```

The lane runs `xcrun simctl privacy … grant location` and `xcrun simctl location … set 48.14,11.5652` (latitude and longitude are **one comma-separated pair**, per `simctl location` syntax) so routing has a start position. If `simctl privacy` fails on your Xcode version, grant location once manually on that simulator.

**Manual run (without Fastlane):** from the repo root:

```sh
flutter test integration_test/screenshots_test.dart -d <SimulatorId> --dart-define=STORE_SCREENSHOTS=true
```

**Important:** Never pass `STORE_SCREENSHOTS=true` for production App Store archives; it only exists for integration tests and screenshot builds.

## Lane: `ios metadata_and_screenshots`

Same as **`ios metadata`**, but **`skip_screenshots: false`** so `deliver` uploads PNGs under `fastlane/screenshots/` together with `metadata/`. Requires the same `ASC_*` (or Apple ID) setup as metadata upload. Run **`ios screenshots`** first to populate `fastlane/screenshots/de-DE/`.

```sh
cd ios
bundle exec fastlane ios metadata_and_screenshots
```

## Lane: `ios submit_review` (optional)

Submits the **current** App Store version **for review** (does not upload a new binary). Use only after metadata is complete, export compliance is answered, and a **build is already attached** to that version in App Store Connect.

```sh
cd ios
export CONFIRM_SUBMIT=1
export APP_STORE_VERSION=3.0.0   # optional but recommended
bundle exec fastlane ios submit_review
```

If you prefer not to automate submission, submit for review manually in the App Store Connect web UI.

## Upload authentication (TestFlight and `deliver`)

**TestFlight uploads** (`upload_to_testflight`) may use **`altool`**, which does **not** use your normal Apple ID password when **two-factor authentication** is on. **`deliver`** / metadata upload typically uses **Spaceship** (session or API key). For both, the following applies:

### Option A — App Store Connect API key (recommended when available)

Create a key in App Store Connect → **Users and Access** → **Keys** (role App Manager or Admin). Download the `.p8` once; store it outside git (for example `ios/fastlane/AuthKey_XXXXX.p8` — `AuthKey*.p8` is gitignored at repo level).

Before running the lane, set:

| Variable | Meaning |
|----------|---------|
| `ASC_KEY_ID` | Key ID |
| `ASC_ISSUER_ID` | Issuer ID from the key page |
| `ASC_KEY_PATH` | Path to the `.p8` file (relative paths are resolved from the **`ios/`** working directory when you run `bundle exec fastlane`) |

Alternatively set **`ASC_KEY_CONTENT_BASE64`** to the base64-encoded contents of the `.p8` instead of `ASC_KEY_PATH` (useful in CI).

If `ASC_KEY_ID` and `ASC_ISSUER_ID` are set, you must also set either `ASC_KEY_PATH` or `ASC_KEY_CONTENT_BASE64`; otherwise the lane will error.

### Option B — App-specific password (personal Apple ID)

1. At [appleid.apple.com](https://appleid.apple.com) → **Sign-In and Security** → **App-Specific Passwords**, generate a password.
2. Either export it for the shell session:
   ```sh
   export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD='xxxx-xxxx-xxxx-xxxx'
   ```
   or add the same line to **`ios/fastlane/.env`** (gitignored). Fastlane loads `.env` from this directory automatically so you are not prompted every run.

Do **not** commit secrets into `Appfile` or the tracked `Fastfile`.

## Troubleshooting

- **Signing / export errors:** See [Codesigning concepts](https://docs.fastlane.tools/codesigning/getting-started/) and gym [export options](https://docs.fastlane.tools/actions/gym/#export-options).
- **`sigh`:** `adhoc` and `development` must not both be passed as explicit options (even `false`); use defaults for App Store profiles.
- **`build_app` `export_method`:** This project uses `app-store` (not `app-store-connect` — that value is not valid for `export_method` in the pinned Fastlane/gym version).

## Further reading

- [fastlane.tools](https://fastlane.tools)
- [docs.fastlane.tools](https://docs.fastlane.tools)

---

`skip_docs` is set in `Fastfile` so Fastlane does not overwrite this hand-maintained README when lanes run. To regenerate Fastlane’s default lane summary locally, run: `bundle exec fastlane docs`.
