import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
          title: const Text('Standortberechtigung'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Zur Anzeige des aktuellen Standorts benötigt die App die Berechtigung "Standort".',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                Geolocator.openAppSettings();
                markRecheckLocationOnResume();
                Navigator.of(context).pop();
              },
              child: const Text('Appeinstellungen'),
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
          title: const Text('Standort aktivieren'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Zur Anzeige des aktuellen Standorts muss die Standortbestimmung aktiviert sein.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                Geolocator.openLocationSettings();
                markRecheckLocationOnResume();
                Navigator.of(context).pop();
              },
              child: const Text('Standorteinstellungen'),
            ),
          ],
        );
      },
    );
  }
}
