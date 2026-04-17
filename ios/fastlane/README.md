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

Screenshots are **not** uploaded by this lane (`skip_screenshots: true`). Manage screenshots in App Store Connect or add a separate screenshots workflow later.

**Authentication:** Same as [Upload authentication](#upload-authentication-testflight-and-deliver) below — App Store Connect API key (`ASC_*`) is recommended; Apple ID + app-specific password can work for `deliver` in many setups.

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
