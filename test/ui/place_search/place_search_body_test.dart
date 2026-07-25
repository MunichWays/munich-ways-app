import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/api/geoapify_api.dart';
import 'package:munich_ways/api/nominatim_api.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/place_search/place_search_body.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';

class FakeRecentSearchesStore extends RecentSearchesStore {
  FakeRecentSearchesStore(this.places);

  final List<Place> places;
  List<Place>? storedPlaces;

  @override
  Future<List<Place>> load() async => List.of(places);

  @override
  Future<void> store(List<Place> places) async {
    storedPlaces = List.of(places);
  }
}

class FailingGeoapifyApi extends GeoapifyApi {
  FailingGeoapifyApi() : super(apiKey: 'test');

  @override
  Future<List<Place>> search(String query, {LatLng? searchCenter}) =>
      Future<List<Place>>.error(Exception('network failed'));
}

class FailingNominatimApi extends NominatimApi {
  @override
  Future<List<Place>> search(String query, {LatLng? searchCenter}) =>
      Future<List<Place>>.error(Exception('fallback failed'));
}

class SuccessfulNominatimApi extends NominatimApi {
  @override
  Future<List<Place>> search(String query, {LatLng? searchCenter}) async => [
        Place('Marienplatz', const LatLng(48.137, 11.576)),
      ];
}

void main() {
  test('stops loading when address search fails', () async {
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
      api: FailingGeoapifyApi(),
      fallbackApi: FailingNominatimApi(),
    );

    await model.startSearch('Marienplatz');

    expect(model.loading, isFalse);
    expect(model.errorMsg, contains('Fehler'));
  });

  test('uses Nominatim when primary address search fails', () async {
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
      api: FailingGeoapifyApi(),
      fallbackApi: SuccessfulNominatimApi(),
    );

    await model.startSearch('Marienplatz');

    expect(model.loading, isFalse);
    expect(model.errorMsg, isNull);
    expect(model.places.single.displayName, 'Marienplatz');
    expect(model.resultsFromNominatim, isTrue);
  });

  testWidgets('shows map selection without redundant search hint',
      (tester) async {
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    expect(find.text('Suchbegriff eingeben'), findsNothing);
    expect(find.text('Auf Karte auswählen'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsNothing);
  });

  test('stores at most 25 recent searches', () async {
    final store = FakeRecentSearchesStore([]);
    final model = PlaceSearchScreenViewModel(recentSearchesRepo: store);
    await Future<void>.delayed(Duration.zero);

    for (var i = 0; i < 30; i++) {
      model.addToRecentSearches(
        Place('Place $i', LatLng(i.toDouble(), i.toDouble())),
      );
    }

    expect(model.recentSearches, hasLength(25));
    expect(model.recentSearches.first.displayName, 'Place 29');
    expect(model.recentSearches.last.displayName, 'Place 5');
    expect(store.storedPlaces, hasLength(25));
  });

  testWidgets('moves a reused recent search to the top', (tester) async {
    final work = Place('Work', const LatLng(48.1, 11.5));
    final home = Place('Home', const LatLng(48.2, 11.6));
    final store = FakeRecentSearchesStore([work, home]);
    final model = PlaceSearchScreenViewModel(recentSearchesRepo: store);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Home'));
    await tester.pump();

    expect(model.recentSearches, [home, work]);
    expect(store.storedPlaces, [home, work]);
  });

  testWidgets('offers map selection before recent searches without results',
      (tester) async {
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([
        Place('Home', const LatLng(48.2, 11.6)),
      ]),
    );
    model.isFirstSearch = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    final noResultsTop =
        tester.getTopLeft(find.textContaining('Keine Ergebnisse')).dy;
    final mapSelectionTop =
        tester.getTopLeft(find.text('Auf Karte auswählen')).dy;
    final recentSearchesTop = tester.getTopLeft(find.text('Letzte Ziele')).dy;

    expect(mapSelectionTop, greaterThan(noResultsTop));
    expect(recentSearchesTop, greaterThan(mapSelectionTop));
  });

  testWidgets('lays out recent search controls vertically with large text',
      (tester) async {
    final store = FakeRecentSearchesStore([
      Place('Home', const LatLng(48.2, 11.6)),
    ]);
    final model = PlaceSearchScreenViewModel(recentSearchesRepo: store);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    final headingTop = tester.getTopLeft(find.text('Letzte Ziele')).dy;
    final clearButtonTop =
        tester.getTopLeft(find.text('(Suchverlauf löschen)')).dy;

    expect(clearButtonTop, greaterThan(headingTop));
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
