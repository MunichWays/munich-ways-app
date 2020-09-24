# MunichWays App

Mobile App in Flutter for iOS and Android

## Development

### Google Maps - Add API Key for development

* Set up project in Google Cloud Platform e.g. MunichWaysDev
* Enable Google Maps SDK for Android & iOS in Google Cloud Console for your project (https://console.cloud.google.com/apis/library/maps-android-backend.googleapis.com)
* Get an API Key which can be used in the App https://developers.google.com/maps/documentation/embed/get-api-key
* For Android add a `local_maps.properties` file to android with following content:
```
# Do not add to version control, this contains your local development configurations
MAPS_API_KEY=<YOUR-API-KEY>
```