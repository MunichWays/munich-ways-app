import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:munich_ways/localization/app_localizations.dart';

/// Alert dialogs shown from the map when location is unavailable or denied.
abstract final class MapLocationDialogs {
  MapLocationDialogs._();

  /// Shown when the app needs the OS "Location" permission. If the user opens app
  /// settings, [markRecheckLocationOnResume] should set the map screen flag so
  /// location is retried after [AppLifecycleState.resumed].
  static Future<void> showPermissionRequestDialog(
    BuildContext context, {
    required VoidCallback markRecheckLocationOnResume,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.tr('Standortberechtigung')),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(context.l10n.isEnglish
                    ? 'The app needs location permission to show your current location.'
                    : 'Zur Anzeige des aktuellen Standorts benötigt die App die Berechtigung "Standort".'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.tr('Abbrechen')),
            ),
            TextButton(
              onPressed: () {
                Geolocator.openAppSettings();
                markRecheckLocationOnResume();
                Navigator.of(context).pop();
              },
              child: Text(context.l10n.tr('Appeinstellungen')),
            ),
          ],
        );
      },
    );
  }

  /// Shown when system location services are off. If the user opens system
  /// location settings, [markRecheckLocationOnResume] should set the map screen
  /// flag so location is retried after resume.
  static Future<void> showEnableLocationServiceDialog(
    BuildContext context, {
    required VoidCallback markRecheckLocationOnResume,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.tr('Standort aktivieren')),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(context.l10n.isEnglish
                    ? 'Location services must be enabled to show your current location.'
                    : 'Zur Anzeige des aktuellen Standorts muss die Standortbestimmung aktiviert sein.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.tr('Abbrechen')),
            ),
            TextButton(
              onPressed: () {
                Geolocator.openLocationSettings();
                markRecheckLocationOnResume();
                Navigator.of(context).pop();
              },
              child: Text(context.l10n.tr('Standorteinstellungen')),
            ),
          ],
        );
      },
    );
  }
}
