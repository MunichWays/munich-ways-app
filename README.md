# MunichWays App

Mobile App displaying the Radlvorangnetz in Flutter for iOS and Android. For more information see: munichways.com

## Development Setup

### Setup Git hooks for formatting

The build server checks if all files are formatted correctly with `flutter format`. If not it will fail.
To ensure that the formatter is run locally before a commit set the hooksPath property: `git config --local core.hooksPath ./githooks`

### Google Maps - Add API Key for development

* Set up project in Google Cloud Platform e.g. MunichWaysDev
* Enable Google Maps SDK for Android & iOS in Google Cloud Console for your project (https://console.cloud.google.com/apis/library/maps-android-backend.googleapis.com)
* Get an API Key which can be used in the App https://developers.google.com/maps/documentation/embed/get-api-key
* For Android add a `local_maps.properties` file to android with following content:
```
# Do not add to version control, this contains your local development configurations
MAPS_API_KEY=<YOUR-API-KEY>
```
* For iOS add `add_credentials_to_env.sh` to `./ios/credentials` with following content:
```bash
#!/bin/bash
# DO NOT CHECK INTO VERSION CONTROL
export MAPS_API_KEY=<YOUR-KEY>
```

## Release

### Android

#### Gitlab Actions

* tag current state and push the tags
    * `git tag -a 0.0.3+5 -m "0.0.3+5"`
    * `git push --tags`
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
3. Add googls Maps Production key, see Development > Google Maps Setup
3. Run `flutter build apk` or see the other output options