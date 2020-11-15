# MunichWays App

Mobile App displaying the Radlvorangnetz in Flutter for iOS and Android. For more information see: munichways.com

## Development Setup

### Setup Git hooks for formatting

The build server checks if all files are formatted correctly with `flutter format`. If not it will fail.
To ensure that the formatter is run locally before a commit set the hooksPath property: `git config --local core.hooksPath ./githooks`

## Release

### iOS

* `flutter build ios`
* in XCode `Procuct -> Archive`

#### Screenshots

* 6,5" - iPhone 12 Pro Max
* 5,5" - iPhone 8 Plus
* iPad - iPadPro (12.9-inch)

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