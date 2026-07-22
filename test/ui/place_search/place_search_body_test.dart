import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
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

void main() {
  testWidgets('shows compact address search help in a tooltip', (tester) async {
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    expect(find.text('Suchbegriff eingeben'), findsOneWidget);
    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).showDuration,
      const Duration(seconds: 8),
    );
    expect(
      find.textContaining('Bitte gebe einen Suchbegriff ein'),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pump();

    expect(
      find.textContaining('Bitte gebe einen Suchbegriff ein'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bitte gebe einen Suchbegriff ein'),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bitte gebe einen Suchbegriff ein'),
      findsNothing,
    );
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
    final clearButtonTop = tester.getTopLeft(find.text('Suchverlauf')).dy;

    expect(clearButtonTop, greaterThan(headingTop));
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
