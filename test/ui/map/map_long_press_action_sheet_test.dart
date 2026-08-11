import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/map/map_long_press_action_sheet.dart';
import 'package:munich_ways/ui/map/map_screen.dart';

void main() {
  test('map screen compiles with the long-press integration', () {
    expect(MapScreen(), isA<MapScreen>());
  });

  testWidgets('always offers starting a route', (tester) async {
    MapLongPressAction? selected;
    await tester.pumpWidget(_Harness(onSelected: (value) => selected = value));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Route hierhin starten'), findsOneWidget);
    expect(find.text('Details anzeigen'), findsNothing);
    expect(find.byIcon(Icons.location_pin), findsOneWidget);

    await tester.tap(find.text('Route hierhin starten'));
    await tester.pumpAndSettle();
    expect(selected, MapLongPressAction.startRoute);
  });

  testWidgets('offers details when a route section was hit', (tester) async {
    MapLongPressAction? selected;
    await tester.pumpWidget(
      _Harness(
        details: StreetDetails(name: 'Teststrecke'),
        onSelected: (value) => selected = value,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Route hierhin starten'), findsOneWidget);
    expect(find.text('Details anzeigen'), findsOneWidget);
    expect(find.byIcon(Icons.location_pin), findsOneWidget);

    await tester.tap(find.text('Details anzeigen'));
    await tester.pumpAndSettle();
    expect(selected, MapLongPressAction.showDetails);
  });

  testWidgets('offers route editing actions for a selected endpoint',
      (tester) async {
    await tester.pumpWidget(
      _Harness(
        canAddWaypoint: true,
        canMoveStart: true,
        onSelected: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Zwischenziel setzen'), findsOneWidget);
    expect(find.text('Startpunkt verschieben'), findsOneWidget);
    expect(find.text('Ziel verschieben'), findsNothing);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({
    this.details,
    this.canAddWaypoint = false,
    this.canMoveStart = false,
    required this.onSelected,
  });

  final StreetDetails? details;
  final bool canAddWaypoint;
  final bool canMoveStart;
  final ValueChanged<MapLongPressAction?> onSelected;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onSelected(
              await showMapLongPressActionOverlay(
                context,
                anchor: const Offset(200, 200),
                overlaySize: const Size(400, 600),
                streetDetails: details,
                canAddWaypoint: canAddWaypoint,
                canMoveStart: canMoveStart,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }
}
