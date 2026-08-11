import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/api/geoapify_api.dart';
import 'package:munich_ways/api/munich_street_corrector.dart';
import 'package:munich_ways/api/nominatim_api.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/place_search/place_search_body.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';

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

class DelayedRecentSearchesStore extends RecentSearchesStore {
  final Completer<List<Place>> completer = Completer<List<Place>>();

  @override
  Future<List<Place>> load() => completer.future;

  @override
  Future<void> store(List<Place> places) async {}
}

class FakeSavedRoutesStore extends SavedRoutesStore {
  FakeSavedRoutesStore(this.routes);

  final List<SavedRoute> routes;
  List<SavedRoute>? storedRoutes;

  @override
  Future<List<SavedRoute>> load() async => List.of(routes);

  @override
  Future<void> store(List<SavedRoute> routes) async {
    storedRoutes = List.of(routes);
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

class DelayedGeoapifyApi extends GeoapifyApi {
  DelayedGeoapifyApi() : super(apiKey: 'test');

  final Completer<List<Place>> completer = Completer<List<Place>>();

  @override
  Future<List<Place>> search(String query, {LatLng? searchCenter}) =>
      completer.future;
}

class SuccessfulGeoapifyApi extends GeoapifyApi {
  SuccessfulGeoapifyApi() : super(apiKey: 'test');

  @override
  Future<List<Place>> search(String query, {LatLng? searchCenter}) async => [
        Place(query, const LatLng(48.137, 11.576)),
      ];
}

class EmptyGeoapifyApi extends GeoapifyApi {
  EmptyGeoapifyApi() : super(apiKey: 'test');

  @override
  Future<List<Place>> search(String query, {LatLng? searchCenter}) async => [];
}

class HangingStreetCorrector extends MunichStreetCorrector {
  HangingStreetCorrector() : super.fromStreetNames(const []);

  @override
  Future<MunichStreetCorrection?> correct(String query) =>
      Completer<MunichStreetCorrection?>().future;
}

void main() {
  test('combines and persistently reorders destination and route favorites',
      () async {
    final home = Place(
      'Home',
      const LatLng(48.1, 11.5),
      favoriteOrder: 0,
    );
    final work = Place(
      'Work',
      const LatLng(48.2, 11.6),
      favoriteOrder: 1,
    );
    final route = SavedRoute(
      name: 'Lieblingsroute',
      start: home,
      stops: [Place('Stopp', const LatLng(48.15, 11.55))],
      destination: work,
    );
    final favoritesStore = FakeRecentSearchesStore([home, work]);
    final routesStore = FakeSavedRoutesStore([route]);
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
      favoritesRepo: favoritesStore,
      savedRoutesRepo: routesStore,
    );
    await Future<void>.delayed(Duration.zero);

    expect(model.favoriteCount, 2);
    expect(await model.toggleRouteFavorite(route), isTrue);
    final favoriteRoute = model.savedRoutes.single;
    expect(model.favoriteCount, 3);
    expect(model.favoriteItems, [home, work, favoriteRoute]);
    expect(
      await model.toggleFavorite(
        Place('Fourth', const LatLng(48.4, 11.8)),
      ),
      isFalse,
    );

    await model.reorderFavorite(2, 0);

    expect(model.favoriteItems.first, isA<SavedRoute>());
    expect(routesStore.storedRoutes!.single.favoriteOrder, 0);
    expect(
      favoritesStore.storedPlaces!.map((place) => place.favoriteOrder),
      containsAll([1, 2]),
    );
  });

  test('ignores recent searches that finish after disposal', () async {
    final store = DelayedRecentSearchesStore();
    final model = PlaceSearchScreenViewModel(recentSearchesRepo: store);

    model.dispose();
    store.completer.complete([
      Place('Schloss Blutenburg', const LatLng(48.163, 11.456)),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(model.recentSearches, isEmpty);
  });

  test('ignores an address search that finishes after disposal', () async {
    final api = DelayedGeoapifyApi();
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
      api: api,
      streetCorrector: MunichStreetCorrector.fromStreetNames(const []),
    );

    final search = model.startSearch('Schlossschmidstraße 16');
    await Future<void>.delayed(Duration.zero);
    model.dispose();
    api.completer.complete([
      Place('Schlossschmidstraße 16', const LatLng(48.15, 11.5)),
    ]);
    await search;

    expect(model.places, isEmpty);
  });

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

  test('uses Nominatim when primary address search has no results', () async {
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
      api: EmptyGeoapifyApi(),
      fallbackApi: SuccessfulNominatimApi(),
    );

    await model.startSearch('Venedig Italien');

    expect(model.loading, isFalse);
    expect(model.errorMsg, isNull);
    expect(model.places, isNotEmpty);
    expect(model.resultsFromNominatim, isTrue);
  });

  test('shows normal results without waiting for typo correction', () async {
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
      api: SuccessfulGeoapifyApi(),
      streetCorrector: HangingStreetCorrector(),
    );

    await model.startSearch('Marien');

    expect(model.loading, isFalse);
    expect(model.places.single.displayName, 'Marien');
  });

  testWidgets('does not show a redundant search hint', (tester) async {
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

    await tester.tap(find.widgetWithText(InkWell, 'Home'));
    await tester.pump();

    expect(model.recentSearches, [home, work]);
    expect(store.storedPlaces, [home, work]);
  });

  testWidgets('more button reveals actions without accepting the destination',
      (tester) async {
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

    expect(find.text('Umbenennen'), findsNothing);
    await tester.tap(find.byTooltip('Mehr Optionen').last);
    await tester.pumpAndSettle();

    expect(model.recentSearches, [work, home]);
    expect(store.storedPlaces, isNull);
    expect(find.text('Umbenennen'), findsOneWidget);
  });

  testWidgets('opening saved-place options preserves the list position',
      (tester) async {
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([
        for (var i = 0; i < 20; i++)
          Place('Place $i', LatLng(48 + i / 1000, 11.5)),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();

    final listPosition =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final offsetBefore = listPosition.pixels;
    await tester.tap(find.byTooltip('Mehr Optionen').last);
    await tester.pumpAndSettle();

    expect(listPosition.pixels, offsetBefore);
    expect(find.text('Umbenennen'), findsOneWidget);
  });

  testWidgets('shows saved routes in their own expanded section',
      (tester) async {
    final savedRoute = SavedRoute(
      name: 'Isar-Runde',
      start: Place('Start', const LatLng(48.1, 11.5)),
      stops: [Place('Stopp', const LatLng(48.2, 11.6))],
      destination: Place('Ziel', const LatLng(48.3, 11.7)),
    );
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
      savedRoutesRepo: FakeSavedRoutesStore([savedRoute]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    expect(find.text('Routen'), findsOneWidget);
    expect(find.text('Letzte Ziele'), findsNothing);
    expect(find.text('Isar-Runde'), findsOneWidget);
    expect(find.byIcon(Icons.route), findsOneWidget);
    expect(
      tester.widget<ListView>(find.byType(ListView)).keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });

  testWidgets('hides saved routes including route favorites in place-only mode',
      (tester) async {
    final model = PlaceSearchScreenViewModel(
      favoritesRepo: FakeRecentSearchesStore([
        Place(
          'Zuhause',
          const LatLng(48.1, 11.5),
          favoriteOrder: 1,
        ),
      ]),
      recentSearchesRepo: FakeRecentSearchesStore([]),
      savedRoutesRepo: FakeSavedRoutesStore([
        SavedRoute(
          name: 'Isar-Runde',
          start: null,
          stops: const [],
          destination: Place('Isar', const LatLng(48.3, 11.7)),
          isFavorite: true,
          favoriteOrder: 0,
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceSearchBody(model: model, showSavedRoutes: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Zuhause'), findsOneWidget);
    expect(find.text('Isar-Runde'), findsNothing);
    expect(find.text('Routen'), findsNothing);
  });

  testWidgets('orders and independently collapses all saved sections',
      (tester) async {
    final model = PlaceSearchScreenViewModel(
      favoritesRepo: FakeRecentSearchesStore([
        Place('Zuhause', const LatLng(48.1, 11.5)),
      ]),
      recentSearchesRepo: FakeRecentSearchesStore([
        Place('Bäckerei', const LatLng(48.2, 11.6)),
      ]),
      savedRoutesRepo: FakeSavedRoutesStore([
        SavedRoute(
          name: 'Isar-Runde',
          start: null,
          stops: const [],
          destination: Place('Isar', const LatLng(48.3, 11.7)),
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PlaceSearchBody(model: model))),
    );
    await tester.pump();

    final favoritesY = tester.getTopLeft(find.text('Favoriten')).dy;
    final recentY = tester.getTopLeft(find.text('Letzte Ziele')).dy;
    final routesY = tester.getTopLeft(find.text('Routen')).dy;
    expect(recentY, greaterThan(favoritesY));
    expect(routesY, greaterThan(recentY));
    expect(find.text('Zuhause'), findsOneWidget);
    expect(find.text('Bäckerei'), findsOneWidget);
    expect(find.text('Isar-Runde'), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.star)).color, Colors.amber);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.history)).color,
      AppColors.munichWaysBlue,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.route)).color,
      AppColors.munichWaysOrange,
    );
    expect(find.byIcon(Icons.route), findsOneWidget);

    await tester.tap(find.text('Favoriten'));
    await tester.pumpAndSettle();
    expect(find.text('Zuhause'), findsNothing);
    expect(find.text('Bäckerei'), findsOneWidget);
    expect(find.text('Isar-Runde'), findsOneWidget);
  });

  testWidgets('shows recent searches after the no-results message',
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
    final recentSearchesTop = tester.getTopLeft(find.text('Letzte Ziele')).dy;

    expect(recentSearchesTop, greaterThan(noResultsTop));
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
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.text('Umbenennen'), findsNothing);

    await tester.tap(find.byTooltip('Mehr Optionen'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    expect(find.text('Löschen'), findsOneWidget);
    expect(find.text('Umbenennen'), findsOneWidget);
    expect(find.text('Als Favorit speichern'), findsOneWidget);
    expect(find.text('Vollständige Adresse'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Als Favorit speichern')).dy,
      lessThan(tester.getTopLeft(find.text('Löschen')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Löschen')).dy,
      lessThan(tester.getTopLeft(find.text('Umbenennen')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a horizontal details button only for truncated addresses',
      (tester) async {
    const address = 'Sehr lange Musterstraße 123, Rückgebäude, 80331 München';
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([
        Place(address, const LatLng(48.14, 11.57)),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: PlaceSearchBody(model: model),
          ),
        ),
      ),
    );
    await tester.pump();

    final addressText = tester.widget<Text>(find.text(address));
    expect(addressText.maxLines, 1);
    expect(addressText.overflow, TextOverflow.clip);

    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(
      find.byTooltip('Vollständige Adresse anzeigen'),
      findsOneWidget,
    );
    final detailsButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.more_horiz),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      detailsButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      Colors.white,
    );
    expect(
      detailsButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.munichWaysBlue,
    );

    await tester.tap(find.byTooltip('Vollständige Adresse anzeigen'));
    await tester.pumpAndSettle();

    expect(find.byType(SelectableText), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      address,
    );
  });

  testWidgets('shows the full name button for truncated route names',
      (tester) async {
    const routeName =
        'Sehr lange gespeicherte Lieblingsroute über mehrere Zwischenziele';
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
      savedRoutesRepo: FakeSavedRoutesStore([
        SavedRoute(
          name: routeName,
          start: null,
          stops: const [],
          destination: Place('Ziel', const LatLng(48.14, 11.57)),
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: PlaceSearchBody(model: model),
          ),
        ),
      ),
    );
    await tester.pump();

    final routeText = tester.widget<Text>(find.text(routeName));
    expect(routeText.maxLines, 1);
    expect(routeText.overflow, TextOverflow.clip);
    expect(
      find.byTooltip('Vollständigen Routennamen anzeigen'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Vollständigen Routennamen anzeigen'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      routeName,
    );
  });

  testWidgets('renames a recent destination with the edit button',
      (tester) async {
    final store = FakeRecentSearchesStore([
      Place('Doctor Drooly', const LatLng(48.128, 11.557)),
    ]);
    final model = PlaceSearchScreenViewModel(recentSearchesRepo: store);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    expect(find.text('Umbenennen'), findsNothing);
    await tester.tap(find.byTooltip('Mehr Optionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Umbenennen'));
    await tester.pumpAndSettle();
    expect(find.text('Ziel umbenennen'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Tierarzt');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(model.recentSearches.single.displayName, 'Tierarzt');
    expect(store.storedPlaces?.single.displayName, 'Tierarzt');
  });

  testWidgets('removes a single recent destination with its delete button',
      (tester) async {
    final home = Place('Home', const LatLng(48.2, 11.6));
    final work = Place('Work', const LatLng(48.1, 11.5));
    final store = FakeRecentSearchesStore([home, work]);
    final favoritesStore = FakeRecentSearchesStore([home]);
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: store,
      favoritesRepo: favoritesStore,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Auswahl übernehmen'), findsNothing);
    await tester.tap(find.byTooltip('Mehr Optionen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Ziel löschen?'), findsOneWidget);
    expect(model.recentSearches, [home, work]);
    expect(model.favoritePlaces, [home]);

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(model.recentSearches, [work]);
    expect(model.favoritePlaces, isEmpty);
    expect(store.storedPlaces, [work]);
    expect(favoritesStore.storedPlaces, isEmpty);
  });

  testWidgets('favorite star only disables favorite status', (tester) async {
    final home = Place('Home', const LatLng(48.2, 11.6));
    final recentStore = FakeRecentSearchesStore([home]);
    final favoritesStore = FakeRecentSearchesStore([home]);
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: recentStore,
      favoritesRepo: favoritesStore,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Mehr Optionen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorit entfernen'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(model.favoritePlaces, isEmpty);
    expect(model.recentSearches, [home]);
    expect(favoritesStore.storedPlaces, isEmpty);
    expect(recentStore.storedPlaces, isNull);
  });

  testWidgets('can recreate a deleted destination and add it as favorite',
      (tester) async {
    final home = Place('Home', const LatLng(48.2, 11.6));
    final recentStore = FakeRecentSearchesStore([home]);
    final favoritesStore = FakeRecentSearchesStore([home]);
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: recentStore,
      favoritesRepo: favoritesStore,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Mehr Optionen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(model.favoritePlaces, isEmpty);
    model.addToRecentSearches(home);
    await tester.pump();
    final homeRow = find
        .ancestor(of: find.text('Home'), matching: find.byType(LayoutBuilder))
        .first;
    final homeOptions = find.descendant(
      of: homeRow,
      matching: find.byTooltip('Mehr Optionen'),
    );
    expect(homeOptions, findsOneWidget);
    await tester.tap(homeOptions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Als Favorit speichern'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(model.favoritePlaces, [home]);
    expect(favoritesStore.storedPlaces, [home]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('highlights favorite rows with a light blue background',
      (tester) async {
    final home = Place('Home', const LatLng(48.2, 11.6));
    final route = SavedRoute(
      name: 'Lieblingsroute',
      start: home,
      stops: const [],
      destination: Place('Arbeit', const LatLng(48.3, 11.7)),
      isFavorite: true,
    );
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
      favoritesRepo: FakeRecentSearchesStore([home]),
      savedRoutesRepo: FakeSavedRoutesStore([route]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceSearchBody(model: model),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Lieblingsroute'), findsNWidgets(2));

    final highlightedMaterial = find.ancestor(
      of: find.text('Home'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.color == AppColors.favoriteHighlight,
      ),
    );
    expect(highlightedMaterial, findsOneWidget);

    final favoriteRoute = find.byKey(const ValueKey('route-Lieblingsroute'));
    expect(favoriteRoute, findsOneWidget);
    final highlightedRoute = tester.widget<ListTile>(
      find.descendant(of: favoriteRoute, matching: find.byType(ListTile)),
    );
    expect(highlightedRoute.tileColor, AppColors.favoriteHighlight);
  });

  testWidgets('starts favorites expanded and lays them out compactly',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final favorites = [
      Place(
        'Sehr lange Favoritenadresse in München',
        const LatLng(48.1, 11.5),
      ),
      Place('Arbeit', const LatLng(48.2, 11.6)),
      Place('Bahnhof', const LatLng(48.3, 11.7)),
    ];
    final model = PlaceSearchScreenViewModel(
      recentSearchesRepo: FakeRecentSearchesStore([]),
      favoritesRepo: FakeRecentSearchesStore(favorites),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlaceSearchBody(model: model)),
      ),
    );
    await tester.pump();

    expect(find.text('Arbeit'), findsOneWidget);
    expect(find.text('Bahnhof'), findsOneWidget);

    final firstY = tester.getCenter(find.text(favorites[0].displayName!)).dy;
    expect(tester.getCenter(find.text('Arbeit')).dy, greaterThan(firstY));
    expect(
      tester.getCenter(find.text('Bahnhof')).dy,
      greaterThan(tester.getCenter(find.text('Arbeit')).dy),
    );
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(find.byTooltip('Mehr Optionen'), findsNWidgets(3));

    await tester.tap(find.text('Favoriten'));
    await tester.pumpAndSettle();
    expect(find.text('Arbeit'), findsNothing);
  });
}
