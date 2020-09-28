# MunichWays App

Mobile App displaying the Radlvorangnetz in Flutter for iOS and Android. For more information see: munichways.com

## Release

### Android

#### Local

1. Get release.keystore from Sven and place it in `android/app/`
2. Get Credentials for keystore from Sven and add them to `android/release_keystore.properties`:
```
# Do not add to version control!
# This contains the credentials to sign the android app and should only be on your local machine
# or the build server
ANDROID_RELEASE_STORE_PASSWORD=<PASSWORD>
ANDROID_RELEASE_ALIAS=<ALIAS>
ANDROID_RELEASE_ALIAS_PASSWORD=<ALIAS_PASSWORD>
```
3. Run `flutter build apk` or see the other output options

## Development Setup

### Google Maps - Add API Key for development

* Set up project in Google Cloud Platform e.g. MunichWaysDev
* Enable Google Maps SDK for Android & iOS in Google Cloud Console for your project (https://console.cloud.google.com/apis/library/maps-android-backend.googleapis.com)
* Get an API Key which can be used in the App https://developers.google.com/maps/documentation/embed/get-api-key
* For Android add a `local_maps.properties` file to android with following content:
```
# Do not add to version control, this contains your local development configurations
MAPS_API_KEY=<YOUR-API-KEY>
```