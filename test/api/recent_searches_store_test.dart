import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/initial_places_store.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/model/example_places.dart';
import 'package:munich_ways/model/place.dart';

void main() {
  late Directory directory;
  late InitialPlacesStore initializer;
  late RecentSearchesStore recent;
  late RecentSearchesStore favorites;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('recent_searches_test_');
    initializer = InitialPlacesStore(
      places: initialExamplePlaces(),
      directoryProvider: () async => directory,
    );
    recent = RecentSearchesStore(initializer: initializer);
    favorites = RecentSearchesStore(
      fileName: 'favoritePlaces.json',
      initializer: initializer,
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  test('home and search load the same examples without a startup call',
      () async {
    final lists = await Future.wait([recent.load(), favorites.load()]);
    expect(lists[0], initialExamplePlaces());
    expect(lists[1], initialExamplePlaces());
    expect(lists[1].map((place) => place.favoriteOrder), [0, 1]);
  });

  test('adding a destination keeps examples and deduplicates by coordinates',
      () async {
    final destination = Place('My destination', const LatLng(48.1, 11.5));
    await recent.add(destination);
    expect(await recent.load(), [destination, ...initialExamplePlaces()]);
    final renamed =
        Place('Renamed example', exampleDestinations.first.location);
    await recent.add(renamed);
    expect(await recent.load(),
        [renamed, destination, initialExamplePlaces().last]);
  });

  test('explicitly clearing before the first load stays empty', () async {
    await recent.store([]);
    expect(await recent.load(), isEmpty);
    expect(await favorites.load(), initialExamplePlaces());
  });

  test('an existing empty list prevents seeding the other list on update',
      () async {
    await File('${directory.path}/recentSearches.json')
        .writeAsString('{"recentSearches":[]}');
    expect(await recent.load(), isEmpty);
    expect(await favorites.load(), isEmpty);
  });

  test('completed store is immediately readable by a new reader', () async {
    final destination = Place('Saved destination', const LatLng(48.3, 11.7));
    await recent.store([destination]);
    expect(
      await RecentSearchesStore(initializer: initializer).load(),
      [destination],
    );
  });
}
