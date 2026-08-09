import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/map/map_overlay/map_home_destination_sheet.dart';

class _EmptyFavoritesStore extends RecentSearchesStore {
  @override
  Future<List<Place>> load() async => [];

  @override
  Future<void> store(List<Place> places) async {}
}

class _PlacesStore extends RecentSearchesStore {
  _PlacesStore(this.places);
  final List<Place> places;

  @override
  Future<List<Place>> load() async => places;
}

class _RoutesStore extends SavedRoutesStore {
  _RoutesStore(this.routes);
  final List<SavedRoute> routes;

  @override
  Future<List<SavedRoute>> load() async => routes;
}

void main() {
  testWidgets('expands the home destination header into search',
      (tester) async {
    var selectOnMap = false;
    var attributionHidden = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MapHomeDestinationSheet(
                searchCenter: null,
                onSelected: (_) {},
                onPlanRoute: () {},
                onSelectOnMap: () => selectOnMap = true,
                onShowInfo: () {},
                onToggleAttribution: () => attributionHidden = true,
                onShowSettings: () {},
                attributionExpanded: true,
                favoritesStore: _EmptyFavoritesStore(),
                recentSearchesStore: _PlacesStore([
                  Place('Letztes Ziel', const LatLng(48.1, 11.5)),
                ]),
                savedRoutesStore: _RoutesStore([
                  SavedRoute(
                    name: 'Arbeitsroute',
                    start: null,
                    stops: const [],
                    destination: Place('Arbeit', const LatLng(48.2, 11.6)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wohin?'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.textContaining('OpenMapTiles'), findsOneWidget);
    final draggable = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    expect(draggable.controller!.size, closeTo(.20, .01));

    await tester.drag(find.text('Wohin?'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Wohin?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(attributionHidden, isTrue);
    expect(find.text('Letztes Ziel'), findsOneWidget);
    expect(find.text('Arbeitsroute'), findsOneWidget);
    expect(find.text('Route planen'), findsOneWidget);
    final mapAction = tester.widget<Text>(find.textContaining('Auf Karte'));
    expect(mapAction.maxLines, 1);

    await tester.drag(find.text('Wohin?'), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Route planen'), findsOneWidget);
    final selectOnMapButton = find.textContaining('Karte');
    expect(find.text('Auf Karte wählen'), findsOneWidget);

    await tester.tap(selectOnMapButton);
    await tester.pumpAndSettle();
    expect(selectOnMap, isTrue);
    expect(find.text('Wohin?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(draggable.controller!.size, closeTo(.20, .01));

    await tester.tap(find.text('Wohin?'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 25));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(find.byTooltip('Schließen'), findsOneWidget);
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();

    expect(find.text('Wohin?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(draggable.controller!.size, closeTo(.20, .01));
    expect(tester.takeException(), isNull);
  });
}
