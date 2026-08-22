import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/map/map_overlay/map_home_destination_sheet.dart';
import 'package:munich_ways/ui/theme.dart';

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
  testWidgets('keeps minimal map mode across unrelated parent rebuilds',
      (tester) async {
    late StateSetter rebuildParent;
    var searchCenter = const LatLng(48.1, 11.5);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return Stack(
                children: [
                  MapHomeDestinationSheet(
                    searchCenter: searchCenter,
                    onSelected: (_) {},
                    onPlanRoute: () {},
                    onNearbySelected: (_) async {},
                    onSelectOnMap: () {},
                    onShowInfo: () {},
                    onToggleAttribution: () {},
                    onShowSettings: () {},
                    attributionExpanded: false,
                    showNearby: false,
                    favoritesStore: _EmptyFavoritesStore(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('In der Nähe'), findsNothing);

    await tester.drag(find.text('Wohin?'), const Offset(0, 500));
    await tester.pumpAndSettle();
    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.controller!.size, closeTo(.12, .01));

    rebuildParent(() {
      searchCenter = const LatLng(48.1001, 11.5001);
    });
    await tester.pumpAndSettle();

    expect(sheet.controller!.size, closeTo(.12, .01));
  });

  testWidgets('offers nearby drinking water in compact mode', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    NearbyPoiType? selectedType;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MapHomeDestinationSheet(
                searchCenter: const LatLng(48.1, 11.5),
                onSelected: (_) {},
                onPlanRoute: () {},
                onNearbySelected: (type) async => selectedType = type,
                onSelectOnMap: () {},
                onShowInfo: () {},
                onToggleAttribution: () {},
                onShowSettings: () {},
                attributionExpanded: false,
                favoritesStore: _EmptyFavoritesStore(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('In der Nähe'));
    await tester.pumpAndSettle();
    expect(find.text('Trinkwasserbrunnen'), findsOneWidget);
    expect(find.text('Öffentliche Toiletten'), findsOneWidget);
    expect(find.text('Servicestationen'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(
      tester.getSize(find.text('Trinkwasserbrunnen')).height,
      lessThan(30),
    );
    expect(
      find.ancestor(
        of: find.text('Trinkwasserbrunnen'),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Trinkwasserbrunnen'));
    await tester.pumpAndSettle();

    expect(selectedType, NearbyPoiType.drinkingWater);
  });

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
                onNearbySelected: (_) async {},
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
    final destinationField = find.byKey(
      const ValueKey('map-destination-search-field'),
    );
    expect(tester.getSize(destinationField).height, greaterThanOrEqualTo(48));
    expect(
      tester.widget<Material>(destinationField).color,
      AppColors.uiPrimary,
    );
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.textContaining('OpenMapTiles'), findsNothing);
    final draggable = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    expect(draggable.controller!.size, closeTo(.28, .01));
    expect(find.text('Route planen'), findsOneWidget);
    expect(find.text('In der Nähe'), findsOneWidget);
    expect(find.text('Auf Karte wählen'), findsNothing);
    final compactPlanRouteX = tester.getCenter(find.text('Route planen')).dx;

    await tester.drag(find.text('Wohin?'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Wohin?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(attributionHidden, isTrue);
    expect(find.text('Letztes Ziel'), findsOneWidget);
    expect(find.text('Arbeitsroute'), findsOneWidget);
    expect(find.text('Route planen'), findsOneWidget);
    expect(find.text('In der Nähe'), findsOneWidget);
    expect(find.text('Auf Karte wählen'), findsNothing);

    await tester.drag(find.text('Wohin?'), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    final queryField = tester.widget<TextField>(find.byType(TextField));
    expect(queryField.decoration?.labelText, isNull);
    expect(queryField.decoration?.hintText, 'Wohin?');
    expect(queryField.decoration?.prefixIcon, isNull);
    expect(
      find.byKey(const ValueKey('destination-query-clear')),
      findsNothing,
    );
    await tester.enterText(find.byType(TextField), 'I');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('destination-query-clear')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('destination-query-clear')));
    await tester.pump();
    expect(find.text('Wohin?'), findsOneWidget);
    expect(find.text('Route planen'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Route planen')).dx,
      closeTo(compactPlanRouteX, 1),
    );
    final selectOnMapButton = find.textContaining('Karte');
    expect(find.text('Auf Karte wählen'), findsOneWidget);

    await tester.tap(selectOnMapButton);
    await tester.pumpAndSettle();
    expect(selectOnMap, isTrue);
    expect(find.text('Wohin?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(draggable.controller!.size, closeTo(.28, .01));

    await tester.tap(find.text('Wohin?'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 25));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(draggable.controller!.size, closeTo(1, .01));
    expect(tester.takeException(), isNull);

    expect(find.byTooltip('Schließen'), findsOneWidget);
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();

    expect(find.text('Wohin?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(draggable.controller!.size, closeTo(.28, .01));
    expect(tester.takeException(), isNull);
  });
}
