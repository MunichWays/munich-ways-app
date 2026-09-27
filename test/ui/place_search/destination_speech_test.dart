import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/geoapify_api.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/speech/speech_input_controller.dart';
import 'package:munich_ways/speech/speech_input_engine.dart';
import 'package:munich_ways/ui/map/map_overlay/map_home_destination_sheet.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';
import 'package:munich_ways/ui/place_search/place_search_sheet.dart';
import 'package:provider/provider.dart';

void main() {
  for (final home in [true, false]) {
    final view = home ? 'home destination' : 'search sheet';
    late _Speech engine;
    late SpeechInputController speech;
    late _SearchApi api;
    Object? selected;

    Future<void> open(WidgetTester tester, {bool enableSpeech = true}) async {
      engine = _Speech();
      speech = SpeechInputController(engine: engine);
      speech.didChangeAppLifecycleState(AppLifecycleState.resumed);
      addTearDown(speech.dispose);
      api = _SearchApi();
      selected = null;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: speech,
          child: MaterialApp(
            home: Scaffold(
              body: home
                  ? Stack(children: [
                      MapHomeDestinationSheet(
                        searchCenter: null,
                        onSelected: (value) => selected = value,
                        onPlanRoute: () {},
                        onNearbySelected: (_) async {},
                        onSelectOnMap: () {},
                        onShowInfo: () {},
                        onToggleAttribution: () {},
                        onShowSettings: () {},
                        attributionExpanded: false,
                        favoritesStore: _Places(),
                        recentSearchesStore: _Places(),
                        savedRoutesStore: _Routes(),
                      ),
                    ])
                  : Builder(
                      builder: (context) => FilledButton(
                            onPressed: () async {
                              selected = await showPlaceSearchSheet(
                                context,
                                enableSpeechInput: enableSpeech,
                              );
                            },
                            child: const Text('Open search'),
                          )),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!home) {
        await tester.tap(find.text('Open search'));
        await tester.pumpAndSettle();
      }
      if (enableSpeech) {
        final model = tester
            .element(find.byTooltip('Ziel sprechen'))
            .read<PlaceSearchScreenViewModel>();
        model.api = api;
      }
    }

    Future<void> record(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Ziel sprechen'));
      await tester.pumpAndSettle();
      if (find.text('Aufnahme starten').evaluate().isNotEmpty) {
        await tester.tap(find.text('Aufnahme starten'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Ich höre zu …'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
    }

    testWidgets(
        '$view requests permission only after notice confirmation and searches once',
        (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Ziel sprechen'));
      await tester.pumpAndSettle();
      expect(engine.initializations, 0);
      expect(find.textContaining('Audio online'), findsOneWidget);
      await tester.tap(find.text('Aufnahme starten'));
      await tester.pumpAndSettle();
      engine.result('Marien', false);
      await tester.pump();
      expect(find.text('Marien'), findsOneWidget);
      expect(api.queries, isEmpty);
      engine.result('Marienplatz', true);
      await tester.pumpAndSettle();
      expect(api.queries, ['Marienplatz']);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Marienplatz');
      expect(selected, isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(api.queries.length, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '$view cancels pending typed search and keeps input after cancellation',
        (tester) async {
      await open(tester);
      if (home) {
        await tester.tap(find.text('Wohin?'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextField), 'Vorheriges Ziel');
      await record(tester);
      final lateResult = engine.result;
      engine.result('Unfertiges Ziel', false);
      await tester.pump();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      lateResult('Falsches Ziel', true);
      await tester.pump(const Duration(seconds: 1));
      expect(api.queries, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Vorheriges Ziel');
      expect(engine.cancels, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$view recovers from no match and accepts a stopped recording',
        (tester) async {
      await open(tester);
      await record(tester);
      engine.error(SpeechInputFailure.noMatch);
      await tester.pumpAndSettle();
      expect(find.text('Nicht verstanden. Bitte erneut versuchen.'),
          findsOneWidget);
      expect(api.queries, isEmpty);
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aufnahme stoppen'));
      await tester.pump();
      expect(engine.stops, 1);
      engine.result('Westpark', true);
      await tester.pumpAndSettle();
      expect(api.queries, ['Westpark']);
      // The notice has been accepted for this app session.
      await tester.tap(find.byTooltip('Ziel sprechen'));
      await tester.pumpAndSettle();
      expect(find.text('Aufnahme starten'), findsNothing);
      expect(find.text('Ich höre zu …'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
    });

    testWidgets('$view retains recognized address after native no match',
        (tester) async {
      await open(tester);
      await record(tester);
      engine.result('Lindwurmstraße 88', false);
      engine.error(SpeechInputFailure.noMatch);
      await tester.pump();
      expect(api.queries, isEmpty);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(api.queries, ['Lindwurmstraße 88']);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Lindwurmstraße 88');
      expect(
          find.text('Nicht verstanden. Bitte erneut versuchen.'), findsNothing);
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '$view offers recognized text after an unknown completion error',
        (tester) async {
      await open(tester);
      await record(tester);
      engine.result('Lindwurmstraße 88', false);
      engine.error(SpeechInputFailure.unknown);
      await tester.pumpAndSettle();
      expect(find.text('Lindwurmstraße 88'), findsOneWidget);
      expect(find.textContaining('derzeit nicht verfügbar'), findsNothing);
      expect(api.queries, isEmpty);
      await tester.tap(find.text('Text übernehmen'));
      await tester.pumpAndSettle();
      expect(api.queries, ['Lindwurmstraße 88']);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Lindwurmstraße 88');
      expect(selected, isNull);
      expect(engine.cancels, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$view retries an unknown error without reusing earlier text',
        (tester) async {
      await open(tester);
      await record(tester);
      engine.result('Lindwurmstraße 88', false);
      engine.error(SpeechInputFailure.unknown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(find.text('Lindwurmstraße 88'), findsNothing);
      expect(find.text('Text übernehmen'), findsNothing);
      engine.error(SpeechInputFailure.unknown);
      await tester.pumpAndSettle();
      expect(find.text('Text übernehmen'), findsNothing);
      expect(api.queries, isEmpty);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(api.queries, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$view back dismisses recording without changing the query',
        (tester) async {
      await open(tester);
      await record(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(engine.cancels, 1);
      expect(api.queries, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    if (!home) {
      testWidgets('search sheet can exclude microphone during navigation',
          (tester) async {
        await open(tester, enableSpeech: false);
        expect(find.byTooltip('Ziel sprechen'), findsNothing);
        expect(engine.initializations, 0);
      });
    }
  }
}

class _Speech implements SpeechInputEngine {
  int initializations = 0;
  int stops = 0;
  int cancels = 0;
  late void Function(String, bool) result;
  late void Function(SpeechInputFailure) error;

  @override
  Future<SpeechInputAvailability> initialize() async {
    initializations++;
    return SpeechInputAvailability.available;
  }

  @override
  Future<List<String>> locales() async => ['de-DE', 'en-US'];

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    required void Function(SpeechInputStatus status) onStatus,
    required void Function(SpeechInputFailure failure) onError,
  }) async {
    result = onResult;
    error = onError;
    onStatus(SpeechInputStatus.listening);
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> cancel() async => cancels++;
}

class _SearchApi extends GeoapifyApi {
  final queries = <String>[];
  @override
  Future<List<Place>> search(String query, {LatLng? searchCenter}) async {
    queries.add(query);
    return [Place('Gefundenes Ziel', const LatLng(48.1, 11.5))];
  }
}

class _Places extends RecentSearchesStore {
  @override
  Future<List<Place>> load() async => [];
}

class _Routes extends SavedRoutesStore {
  @override
  Future<List<SavedRoute>> load() async => [];
}
