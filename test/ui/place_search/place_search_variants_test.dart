import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/geoapify_api.dart';
import 'package:munich_ways/api/munich_street_corrector.dart';
import 'package:munich_ways/api/nominatim_api.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';

typedef Search = Future<List<Place>> Function(String, LatLng?);

class _Geoapify extends GeoapifyApi {
  _Geoapify(this.handler) : super(apiKey: 'test');
  final Search handler;
  @override
  Future<List<Place>> search(String query, {LatLng? searchCenter}) =>
      handler(query, searchCenter);
}

class _Nominatim extends NominatimApi {
  _Nominatim(this.handler);
  final Search handler;
  @override
  Future<List<Place>> search(String query, {LatLng? searchCenter}) =>
      handler(query, searchCenter);
}

class _Store extends RecentSearchesStore {
  @override
  Future<List<Place>> load() async => [];
  @override
  Future<void> store(List<Place> places) async {}
}

class _Routes extends SavedRoutesStore {
  @override
  Future<List<SavedRoute>> load() async => [];
  @override
  Future<void> store(List<SavedRoute> routes) async {}
}

PlaceSearchScreenViewModel modelWith(Search primary, {Search? fallback}) =>
    PlaceSearchScreenViewModel(
      recentSearchesRepo: _Store(),
      favoritesRepo: _Store(),
      savedRoutesRepo: _Routes(),
      api: _Geoapify(primary),
      fallbackApi: _Nominatim(fallback ?? (_, __) async => []),
      streetCorrector: MunichStreetCorrector.fromStreetNames(const []),
      searchCenter: const LatLng(47.37, 8.54),
    );

void main() {
  const location = LatLng(48.128, 11.557);

  test('typed and spoken association variants use one canonical query',
      () async {
    final calls = <String>[];
    final model = modelWith((query, center) async {
      calls.add(query);
      expect(center, const LatLng(47.37, 8.54));
      return query == 'Green City e.V.'
          ? [Place('Green City e.V., Lindwurmstraße 88, München', location)]
          : [];
    });
    addTearDown(model.dispose);
    for (final query in [
      'GreenCity ev',
      'GreenCity e.V.',
      'GreenCity e V',
      'Green City e V'
    ]) {
      await model.startSearch(query);
      expect(calls.last, 'Green City e.V.');
      expect(model.loading, isFalse);
      expect(model.places.single.displayName, contains('Lindwurmstraße 88'));
    }
    expect(calls, hasLength(8));
  });

  test('fallback receives the normalized name and retains its attribution',
      () async {
    final model = modelWith((_, __) async => [], fallback: (query, _) async {
      return query == 'Green City e.V.'
          ? [Place('Green City e.V.', location)]
          : [];
    });
    addTearDown(model.dispose);
    await model.startSearch('GreenCity e V');
    expect(model.resultsFromNominatim, isTrue);
    expect(model.correctedQuery, 'Green City e.V.');
  });

  test('an exact compound name replaces loose matches from the original query',
      () async {
    final calls = <String>[];
    final model = modelWith((query, _) async {
      calls.add(query);
      return [
        Place(query == 'Zürichhorn' ? 'Zürichhorn, Zürich' : 'Horn, Küsnacht',
            location)
      ];
    });
    addTearDown(model.dispose);
    await model.startSearch('Zürich Horn');
    expect(calls, ['Zürich Horn', 'Zürichhorn']);
    expect(model.places.single.displayName, 'Zürichhorn, Zürich');
    expect(model.correctedQuery, 'Zürichhorn');
  });

  test('an exact original name needs no optional request', () async {
    final calls = <String>[];
    final model = modelWith((query, _) async {
      calls.add(query);
      return [Place('New York, USA', location)];
    });
    addTearDown(model.dispose);
    await model.startSearch('New York');
    expect(calls, ['New York']);
    expect(model.correctedQuery, isNull);
  });

  test('a matching alias also avoids the compound probe', () async {
    var calls = 0;
    final model = modelWith((_, __) async {
      calls++;
      return [
        Place('Am Markt, Tübingen', location, alternativeNames: ['Marktplatz'])
      ];
    });
    addTearDown(model.dispose);
    await model.startSearch('Markt Platz');
    expect(calls, 1);
    expect(model.places.single.alternativeNames, ['Marktplatz']);
  });

  test('a failed optional request keeps original results and their attribution',
      () async {
    final model = modelWith((query, _) async {
      if (query == 'Zürichhorn') throw Exception('primary failed');
      return [Place('Horn, Küsnacht', location)];
    }, fallback: (_, __) async => throw Exception('fallback failed'));
    addTearDown(model.dispose);
    await model.startSearch('Zürich Horn');
    expect(model.places.single.displayName, 'Horn, Küsnacht');
    expect(model.resultsFromNominatim, isFalse);
    expect(model.errorMsg, isNull);
    expect(model.loading, isFalse);
  });

  test('loose optional matches cannot replace original fallback results',
      () async {
    final model = modelWith(
        (query, _) async =>
            query == 'Zürichhorn' ? [Place('Bern', location)] : [],
        fallback: (_, __) async => [Place('Horn, Küsnacht', location)]);
    addTearDown(model.dispose);
    await model.startSearch('Zürich Horn');
    expect(model.places.single.displayName, 'Horn, Küsnacht');
    expect(model.resultsFromNominatim, isTrue);
    expect(model.correctedQuery, isNull);
  });

  test(
      'reset cancels pending search without starting fallback or another variant',
      () async {
    final pending = Completer<List<Place>>();
    var fallbackCalls = 0;
    final model = modelWith((_, __) => pending.future, fallback: (_, __) async {
      fallbackCalls++;
      return [];
    });
    addTearDown(model.dispose);
    final search = model.startSearch('Zürich Horn');
    model.resetSearch();
    pending.complete([]);
    await search;
    expect(fallbackCalls, 0);
    expect(model.places, isEmpty);
    expect(model.loading, isFalse);
  });

  test(
      'late compound completion cannot overwrite a newer search or attribution',
      () async {
    final pending = Completer<List<Place>>();
    final started = Completer<void>();
    final model = modelWith((query, _) async {
      if (query == 'Berlin') return [Place('Berlin', location)];
      if (query == 'Zürichhorn') {
        started.complete();
        return pending.future;
      }
      return [];
    }, fallback: (_, __) async => [Place('Horn, Küsnacht', location)]);
    addTearDown(model.dispose);
    final oldSearch = model.startSearch('Zürich Horn');
    await started.future;
    await model.startSearch('Berlin');
    pending.complete([Place('Zürichhorn', location)]);
    await oldSearch;
    expect(model.places.single.displayName, 'Berlin');
    expect(model.resultsFromNominatim, isFalse);
    expect(model.correctedQuery, isNull);
    expect(model.loading, isFalse);
  });

  test('empty input ends loading and invalidates a pending search', () async {
    final pending = Completer<List<Place>>();
    var calls = 0;
    final model = modelWith((_, __) {
      calls++;
      return pending.future;
    });
    addTearDown(model.dispose);
    final search = model.startSearch('Berlin');
    await model.startSearch('   ');
    expect(model.loading, isFalse);
    expect(model.errorMsg, isNotNull);
    pending.complete([Place('Berlin', location)]);
    await search;
    expect(calls, 1);
    expect(model.places, isEmpty);
  });

  test('search recovers after provider errors', () async {
    var healthy = false;
    final model = modelWith((_, __) async {
      if (!healthy) throw Exception('offline');
      return [Place('Berlin', location)];
    }, fallback: (_, __) async => throw Exception('offline'));
    addTearDown(model.dispose);
    await model.startSearch('Berlin');
    expect(model.errorMsg, isNotNull);
    expect(model.loading, isFalse);
    healthy = true;
    await model.startSearch('Berlin');
    expect(model.errorMsg, isNull);
    expect(model.places.single.displayName, 'Berlin');
    expect(model.loading, isFalse);
  });
  test('a normal street and city query does not start a compound retry',
      () async {
    final calls = <String>[];
    final model = modelWith((query, _) async {
      calls.add(query);
      return [Place('Marienplatz, 80331 München', location)];
    });
    addTearDown(model.dispose);
    await model.startSearch('Marienplatz München');
    expect(calls, ['Marienplatz München']);
    expect(model.places.single.displayName, 'Marienplatz, 80331 München');
  });
  test('an already working CamelCase name is searched unchanged', () async {
    final calls = <String>[];
    final model = modelWith((query, _) async {
      calls.add(query);
      return [Place("McDonald's, München", location)];
    });
    addTearDown(model.dispose);
    await model.startSearch("McDonald's");
    expect(calls, ["McDonald's"]);
    expect(model.correctedQuery, isNull);
  });

  test('a canonical retry does not also start a compound probe', () async {
    final calls = <String>[];
    final model = modelWith((query, _) async {
      calls.add(query);
      return [];
    });
    addTearDown(model.dispose);
    await model.startSearch('GreenCity');
    expect(calls, ['GreenCity', 'Green City']);
    expect(model.loading, isFalse);
  });

  test(
      'recorded provider responses find Marktplatz through its Nominatim alias',
      () async {
    final primaryBody = File('test/fixtures/geoapify/marktplatz_tuebingen.json')
        .readAsStringSync();
    final fallbackBody =
        File('test/fixtures/nominatim/marktplatz_tuebingen.json')
            .readAsStringSync();
    final primaryQueries = <String>[];
    final fallbackBounds = <String?>[];
    final primary = GeoapifyApi(
        apiKey: 'test',
        client: MockClient((request) async {
          primaryQueries.add(request.url.queryParameters['text']!);
          return Response(primaryBody, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final fallback = NominatimApi(client: MockClient((request) async {
      expect(request.url.queryParameters['q'], 'Marktplatz, 72070 Tübingen');
      fallbackBounds.add(request.url.queryParameters['bounded']);
      return Response(
          request.url.queryParameters['bounded'] == '1' ? '[]' : fallbackBody,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final model = modelWith(
        (query, center) => primary.search(query, searchCenter: center),
        fallback: (query, center) =>
            fallback.search(query, searchCenter: center));
    addTearDown(model.dispose);
    await model.startSearch('Marktplatz, 72070 Tübingen');
    expect(primaryQueries,
        ['Marktplatz, 72070 Tübingen', 'Marktplatz, 72070 Tübingen']);
    expect(fallbackBounds, ['1', null]);
    expect(model.places.single.displayName, 'Am Markt, Altstadt, Tübingen');
    expect(model.places.single.alternativeNames, ['Marktplatz']);
    expect(model.places.single.latLng, const LatLng(48.5202629, 9.0535540));
    expect(model.resultsFromNominatim, isTrue);
    expect(model.errorMsg, isNull);
    expect(model.loading, isFalse);
  });

  test('recorded mixed suggestions still retry the exact compound name',
      () async {
    final originalBody =
        File('test/fixtures/geoapify/zuerich_horn.json').readAsStringSync();
    final compoundBody =
        File('test/fixtures/geoapify/zuerichhorn.json').readAsStringSync();
    final queries = <String>[];
    final primary = GeoapifyApi(
        apiKey: 'test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/reverse'))
            return Response('{"results":[]}', 200);
          final query = request.url.queryParameters['text']!;
          queries.add(query);
          return Response(
              query == 'Zürichhorn' ? compoundBody : originalBody, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final model = modelWith(
        (query, center) => primary.search(query, searchCenter: center),
        fallback: (_, __) async => throw StateError('Unexpected fallback'));
    addTearDown(model.dispose);
    await model.startSearch('Zürich Horn');
    expect(queries, ['Zürich Horn', 'Zürich Horn', 'Zürichhorn', 'Zürichhorn']);
    expect(model.places, isNotEmpty);
    expect(
        model.places
            .every((place) => place.displayName!.startsWith('Zürichhorn,')),
        isTrue);
    expect(model.correctedQuery, 'Zürichhorn');
    expect(model.resultsFromNominatim, isFalse);
    expect(model.errorMsg, isNull);
    expect(model.loading, isFalse);
  });
  test(
      'recorded city-only search reaches the Nominatim alias without a postcode',
      () async {
    final primaryBody =
        File('test/fixtures/geoapify/marktplatz_tuebingen_ohne_plz.json')
            .readAsStringSync();
    final fallbackBody =
        File('test/fixtures/nominatim/marktplatz_tuebingen.json')
            .readAsStringSync();
    final primaryQueries = <String>[];
    final fallbackBounds = <String?>[];
    final primary = GeoapifyApi(
        apiKey: 'test',
        client: MockClient((request) async {
          primaryQueries.add(request.url.queryParameters['text']!);
          return Response(primaryBody, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final fallback = NominatimApi(client: MockClient((request) async {
      expect(request.url.queryParameters['q'], 'marktplatz tübingen');
      fallbackBounds.add(request.url.queryParameters['bounded']);
      return Response(
          request.url.queryParameters['bounded'] == '1' ? '[]' : fallbackBody,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final model = modelWith(
        (query, center) => primary.search(query, searchCenter: center),
        fallback: (query, center) =>
            fallback.search(query, searchCenter: center));
    addTearDown(model.dispose);
    await model.startSearch('marktplatz tübingen');
    expect(primaryQueries, ['marktplatz tübingen', 'marktplatz tübingen']);
    expect(fallbackBounds, ['1', null]);
    expect(model.places.single.displayName, 'Am Markt, Altstadt, Tübingen');
    expect(model.places.single.alternativeNames, ['Marktplatz']);
    expect(model.places.single.latLng, const LatLng(48.5202629, 9.0535540));
    expect(model.resultsFromNominatim, isTrue);
    expect(model.errorMsg, isNull);
    expect(model.loading, isFalse);
  });
}
