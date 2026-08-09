import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/map_overlay/map_search_bar.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';

class _FavoriteStore extends RecentSearchesStore {
  _FavoriteStore(this.favorites);

  final List<Place> favorites;

  @override
  Future<List<Place>> load() async => List.of(favorites);
}

class _SettingsStore extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

void main() {
  testWidgets('shows up to three truncated favorite shortcuts below search',
      (tester) async {
    final favorites = [
      Place('Sehr lange Adresse Nummer eins', const LatLng(48.1, 11.5)),
      Place('Arbeit', const LatLng(48.2, 11.6)),
      Place('Bahnhof', const LatLng(48.3, 11.7)),
      Place('Nicht sichtbar', const LatLng(48.4, 11.8)),
    ];
    final model = MapScreenViewModel(store: _SettingsStore());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 330,
            child: MapSearchBar(
              model: model,
              favoritesStore: _FavoriteStore(favorites),
              searchCenterProvider: () => null,
              onPlanRoute: () async {},
              onSelectOnMap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Wohin?'), findsOneWidget);
    expect(find.text('Arbeit'), findsOneWidget);
    expect(find.text('Bahnhof'), findsOneWidget);
    expect(find.text('Nicht sichtbar'), findsNothing);

    final longLabel = tester.widget<Text>(
      find.text('Sehr lange Adresse Nummer eins'),
    );
    expect(longLabel.maxLines, 1);
    expect(longLabel.overflow, TextOverflow.ellipsis);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is FilledButton &&
            widget.style?.backgroundColor?.resolve(<WidgetState>{}) ==
                AppColors.favoriteHighlight,
      ),
      findsNWidgets(3),
    );
  });
}
