import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/poi_details.dart';
import 'package:munich_ways/ui/poi_details/poi_details_sheet.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';

void main() {
  testWidgets(
      'shows translated tags in useful order without translating values',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final details = PoiDetails.fromGeoJsonFeature({
      'properties': {
        'osm_id': 123,
        'wheelchair': 'yes',
        'opening_hours': '24/7',
        'amenity': 'drinking_water',
        'name': 'Brunnen am Platz',
        'osm_type': 'node',
        'osm_url': 'https://www.openstreetmap.org/node/123',
        'source:website': 'https://example.org/source',
        'custom_tag': 'original_value',
      },
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PoiDetailsSheet(details: details, onRouteHere: () {}),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Brunnen am Platz'), findsNWidgets(2));
    expect(find.text('Route hierhin'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Route hierhin'),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
    expect(find.text('Einrichtungsart'), findsOneWidget);
    expect(find.text('drinking_water'), findsOneWidget);
    expect(find.text('Öffnungszeiten'), findsOneWidget);
    expect(find.text('24/7'), findsOneWidget);
    expect(find.text('Rollstuhlgerecht'), findsOneWidget);
    expect(find.text('yes'), findsOneWidget);
    expect(find.text('custom_tag'), findsOneWidget);
    expect(find.text('original_value'), findsOneWidget);
    expect(find.text('osm_type'), findsNothing);
    expect(find.text('osm_url'), findsNothing);
    expect(find.text('Quell-Webseite'), findsOneWidget);
    final sourceLink = tester
        .widgetList<ListItem>(find.byType(ListItem))
        .singleWhere((item) => item.label == 'Quell-Webseite');
    expect(sourceLink.isLink, isTrue);
    expect(sourceLink.onTap, isNotNull);

    expect(
      tester.getTopLeft(find.text('Einrichtungsart')).dy,
      lessThan(tester.getTopLeft(find.text('Öffnungszeiten')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Öffnungszeiten')).dy,
      lessThan(tester.getTopLeft(find.text('Rollstuhlgerecht')).dy),
    );

    await tester.scrollUntilVisible(
      find.text('EveryDoor'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Auf OpenStreetMap ansehen'), findsOneWidget);
    expect(find.text('OSM selbst ändern'), findsOneWidget);
    final bottomLinks = tester
        .widgetList<ListItem>(find.byType(ListItem))
        .where((item) =>
            item.label == 'OpenStreetMap' || item.label == 'OSM selbst ändern')
        .toList();
    expect(bottomLinks, hasLength(2));
    expect(
        bottomLinks.every((item) => item.isLink && item.onTap != null), isTrue);
    expect(
      tester.getTopLeft(find.text('OpenStreetMap')).dy,
      lessThan(tester.getTopLeft(find.text('OSM selbst ändern')).dy),
    );
  });
}
