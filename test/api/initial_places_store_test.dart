import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/initial_places_store.dart';
import 'package:munich_ways/model/place.dart';

void main() {
  late Directory directory;
  late InitialPlacesStore store;
  final places = [
    Place('First example', const LatLng(48.1, 11.5)),
    Place('Second example', const LatLng(48.2, 11.6)),
  ];

  File file(String name) => File('${directory.path}/$name');
  InitialPlacesStore newStore() => InitialPlacesStore(
        places: places,
        directoryProvider: () async => directory,
      );
  Future<List<Place>> readPlaces(String name) async {
    final json = jsonDecode(await file(name).readAsString());
    return (json['recentSearches'] as List)
        .map((entry) => Place.fromJson(entry))
        .toList();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('initial_places_test_');
    store = newStore();
  });
  tearDown(() async => directory.delete(recursive: true));

  test('seeds both lists offline once, including concurrent readers', () async {
    await Future.wait(List.generate(5, (_) => store.ensureInitialized()));

    final favorites = await readPlaces('favoritePlaces.json');
    expect(favorites, places);
    expect(favorites.map((place) => place.favoriteOrder), [0, 1]);
    expect(await readPlaces('recentSearches.json'), places);
    expect(
        jsonDecode(await file(InitialPlacesStore.markerName).readAsString()), {
      'pending': false,
      'safetyNoticePending': true,
      'tutorialPending': true
    });

    await newStore().ensureInitialized();
    expect(await readPlaces('recentSearches.json'), places);
  });

  test('cleared, renamed and removed lists stay changed after restart',
      () async {
    await store.ensureInitialized();
    await file('favoritePlaces.json').writeAsString('{"recentSearches":[]}');
    final renamed = Place('My place', places.first.latLng);
    await file('recentSearches.json').writeAsString(jsonEncode({
      'recentSearches': [renamed],
    }));

    await newStore().ensureInitialized();
    expect(await readPlaces('favoritePlaces.json'), isEmpty);
    expect(await readPlaces('recentSearches.json'), [renamed]);

    await file('recentSearches.json').delete();
    await newStore().ensureInitialized();
    expect(await file('recentSearches.json').exists(), isFalse);
  });

  for (final name in InitialPlacesStore.existingDataFiles) {
    test('update preserves existing $name, even empty or corrupt', () async {
      for (final contents in ['{"recentSearches":[]}', 'invalid']) {
        await file(name).writeAsString(contents);
        await newStore().ensureInitialized();
        expect(await file(name).readAsString(), contents);
        for (final destination in InitialPlacesStore.destinationFiles) {
          if (destination != name) {
            expect(await file(destination).exists(), isFalse);
          }
        }
        await file(InitialPlacesStore.markerName).delete();
      }
    });
  }

  test('interrupted initialization resumes without replacing an existing list',
      () async {
    await file(InitialPlacesStore.markerName).writeAsString('{"pending":true}');
    await file('favoritePlaces.json').writeAsString('{"recentSearches":[]}');
    await store.ensureInitialized();
    expect(await readPlaces('favoritePlaces.json'), isEmpty);
    expect(await readPlaces('recentSearches.json'), places);
  });

  test('recovers from a failed seed write in the same session', () async {
    final obstruction = Directory(file('recentSearches.json').path);
    await obstruction.create();
    await expectLater(
        store.ensureInitialized(), throwsA(isA<FileSystemException>()));
    expect(await readPlaces('favoritePlaces.json'), places);
    await file('favoritePlaces.json').writeAsString('{"recentSearches":[]}');

    await obstruction.delete();
    await store.ensureInitialized();
    expect(await readPlaces('favoritePlaces.json'), isEmpty);
    expect(await readPlaces('recentSearches.json'), places);
  });

  test('recovers from an unavailable directory without a partial decision',
      () async {
    var unavailable = true;
    store = InitialPlacesStore(
      places: places,
      directoryProvider: () async {
        if (unavailable) throw const FileSystemException('Unavailable');
        return directory;
      },
    );
    await expectLater(
        store.ensureInitialized(), throwsA(isA<FileSystemException>()));
    unavailable = false;
    await store.ensureInitialized();
    expect(await readPlaces('favoritePlaces.json'), places);
    expect(await readPlaces('recentSearches.json'), places);
  });

  test('a malformed marker never reintroduces examples', () async {
    for (final contents in ['broken', '[]', '{}', '{"pending":false}']) {
      await file(InitialPlacesStore.markerName).writeAsString(contents);
      await newStore().ensureInitialized();
      for (final destination in InitialPlacesStore.destinationFiles) {
        expect(await file(destination).exists(), isFalse);
      }
    }
  });

  test('new installation keeps notice pending until it is dismissed', () async {
    expect(await store.shouldShowSafetyNotice(), isTrue);
    expect(await newStore().shouldShowSafetyNotice(), isTrue);
    await store.dismissSafetyNotice();
    expect(await newStore().shouldShowSafetyNotice(), isFalse);
    expect(await readPlaces('favoritePlaces.json'), places);
    expect(await readPlaces('recentSearches.json'), places);
  });

  test('concurrent dismissal preserves other first-run fields', () async {
    await store.ensureInitialized();
    final marker = file(InitialPlacesStore.markerName);
    final state = jsonDecode(await marker.readAsString());
    state['futureTutorialPending'] = true;
    await marker.writeAsString(jsonEncode(state));
    await Future.wait(List.generate(3, (_) => store.dismissSafetyNotice()));
    expect(jsonDecode(await marker.readAsString()), {
      'pending': false,
      'safetyNoticePending': false,
      'tutorialPending': true,
      'futureTutorialPending': true,
    });
  });

  test('previous installations do not get a notice on update', () async {
    for (final contents in [
      '{"pending":false}',
      '{"pending":true}',
      'invalid'
    ]) {
      await file(InitialPlacesStore.markerName).writeAsString(contents);
      expect(await newStore().shouldShowSafetyNotice(), isFalse);
      expect(await newStore().shouldShowTutorial(), isFalse);
    }
  });

  for (final name in InitialPlacesStore.existingDataFiles) {
    test('existing $name prevents first-installation notice', () async {
      await file(name).writeAsString('existing data');
      expect(await store.shouldShowSafetyNotice(), isFalse);
      expect(await store.shouldShowTutorial(), isFalse);
    });
  }

  test('interrupted seeding preserves a pending safety notice', () async {
    await file(InitialPlacesStore.markerName)
        .writeAsString('{"pending":true,"safetyNoticePending":true}');
    expect(await store.shouldShowSafetyNotice(), isTrue);
    expect(await readPlaces('favoritePlaces.json'), places);
    expect(await readPlaces('recentSearches.json'), places);
  });

  test('failed dismissal stays pending and can recover', () async {
    expect(await store.shouldShowSafetyNotice(), isTrue);
    final obstruction =
        Directory('${file(InitialPlacesStore.markerName).path}.tmp');
    await obstruction.create();
    await expectLater(
        store.dismissSafetyNotice(), throwsA(isA<FileSystemException>()));
    expect(await newStore().shouldShowSafetyNotice(), isTrue);
    await obstruction.delete();
    await store.dismissSafetyNotice();
    expect(await newStore().shouldShowSafetyNotice(), isFalse);
  });

  test(
      'tutorial stays pending independently and concurrent completion preserves both flags',
      () async {
    expect(await store.shouldShowTutorial(), isTrue);
    await store.dismissSafetyNotice();
    expect(await newStore().shouldShowTutorial(), isTrue);
    expect(await newStore().shouldShowSafetyNotice(), isFalse);
    await Future.wait([
      store.dismissTutorial(),
      store.dismissSafetyNotice(),
      store.dismissTutorial()
    ]);
    expect(await newStore().shouldShowTutorial(), isFalse);
    expect(await newStore().shouldShowSafetyNotice(), isFalse);
    expect(await readPlaces('favoritePlaces.json'), places);
    expect(await readPlaces('recentSearches.json'), places);
  });

  test(
      'old and interrupted installations never acquire a missing tutorial flag',
      () async {
    for (final contents in [
      '{"pending":false,"safetyNoticePending":true}',
      '{"pending":true,"safetyNoticePending":true}',
    ]) {
      await file(InitialPlacesStore.markerName).writeAsString(contents);
      expect(await newStore().shouldShowTutorial(), isFalse);
    }
  });

  test('interrupted fresh initialization retains tutorial and notice flags',
      () async {
    await file(InitialPlacesStore.markerName).writeAsString(
      '{"pending":true,"safetyNoticePending":true,"tutorialPending":true}',
    );
    expect(await store.shouldShowTutorial(), isTrue);
    expect(await store.shouldShowSafetyNotice(), isTrue);
    await Future.wait([store.dismissSafetyNotice(), store.dismissTutorial()]);
    expect(await newStore().shouldShowTutorial(), isFalse);
    expect(await newStore().shouldShowSafetyNotice(), isFalse);
  });

  test('failed tutorial write can recover without blocking notice completion',
      () async {
    expect(await store.shouldShowTutorial(), isTrue);
    final obstruction =
        Directory('${file(InitialPlacesStore.markerName).path}.tmp');
    await obstruction.create();
    await expectLater(
        store.dismissTutorial(), throwsA(isA<FileSystemException>()));
    expect(await newStore().shouldShowTutorial(), isTrue);
    await obstruction.delete();
    await Future.wait([store.dismissTutorial(), store.dismissSafetyNotice()]);
    expect(await newStore().shouldShowTutorial(), isFalse);
    expect(await newStore().shouldShowSafetyNotice(), isFalse);
  });
}
