import 'dart:convert';
import 'dart:io';

import 'package:munich_ways/model/place.dart';
import 'package:path_provider/path_provider.dart';

/// Owns first-installation initialization and independent completion flags.
class InitialPlacesStore {
  InitialPlacesStore({
    required this.places,
    Future<Directory> Function()? directoryProvider,
  }) : directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const markerName = 'initial_places.json';
  static const destinationFiles = [
    'favoritePlaces.json',
    'recentSearches.json',
  ];
  static const existingDataFiles = [
    ...destinationFiles,
    'settings.json',
    'map_ui_prefs.json',
    'savedRoutes.json',
  ];

  final List<Place> places;
  final Future<Directory> Function() directoryProvider;
  Future<void>? _initialization;
  Future<void> _markerUpdates = Future<void>.value();

  Future<void> ensureInitialized() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final directory = await directoryProvider();
      final marker = File('${directory.path}/$markerName');
      Map<String, dynamic> state;
      if (await marker.exists()) {
        // A malformed marker must never cause deleted examples to reappear.
        try {
          final decoded = jsonDecode(await marker.readAsString());
          if (decoded is! Map<String, dynamic> || decoded['pending'] != true) {
            return;
          }
          state = decoded;
        } on FormatException {
          return;
        }
      } else {
        for (final name in existingDataFiles) {
          if (await File('${directory.path}/$name').exists()) {
            await _writeJson(marker, {'pending': false});
            return;
          }
        }
        // Persist the decision before creating either list. A failed write or
        // interrupted first start can then resume without overwriting user data.
        state = {
          'pending': true,
          'safetyNoticePending': true,
          'tutorialPending': true
        };
        await _writeJson(marker, state);
      }

      for (final name in destinationFiles) {
        final file = File('${directory.path}/$name');
        if (await file.exists()) continue;
        final entries = name == 'favoritePlaces.json'
            ? [
                for (var i = 0; i < places.length; i++)
                  places[i].withFavoriteOrder(i),
              ]
            : places;
        await _writeJson(file, {'recentSearches': entries});
      }
      await _writeJson(marker, {...state, 'pending': false});
    } catch (_) {
      // Permit retry after a transient storage/platform failure.
      _initialization = null;
      rethrow;
    }
  }

  Future<bool> shouldShowSafetyNotice() => _shouldShow('safetyNoticePending');

  Future<bool> shouldShowTutorial() => _shouldShow('tutorialPending');

  Future<bool> _shouldShow(String flag) async {
    await ensureInitialized();
    final directory = await directoryProvider();
    try {
      final state = jsonDecode(
        await File('${directory.path}/$markerName').readAsString(),
      );
      // Missing flags belong to previous installs; never retrofit on updates.
      return state is Map && state[flag] == true;
    } on FormatException {
      return false;
    }
  }

  Future<void> dismissSafetyNotice() => _dismiss('safetyNoticePending');

  Future<void> dismissTutorial() => _dismiss('tutorialPending');

  Future<void> _dismiss(String flag) {
    final operation = _markerUpdates.then((_) async {
      await ensureInitialized();
      final directory = await directoryProvider();
      final marker = File('${directory.path}/$markerName');
      final state = jsonDecode(await marker.readAsString());
      if (state is! Map<String, dynamic> || state[flag] != true) return;
      await _writeJson(marker, {...state, flag: false});
    });
    _markerUpdates = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _writeJson(File file, Object data) async {
    final temporary = File('${file.path}.tmp');
    await temporary.create(recursive: true);
    await temporary.writeAsString(jsonEncode(data), flush: true);
    await temporary.rename(file.path);
  }
}
