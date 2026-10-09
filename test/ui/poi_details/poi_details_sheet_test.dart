import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/poi_details.dart';
import 'package:munich_ways/model/example_places.dart';
import 'package:munich_ways/ui/poi_details/poi_details_sheet.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';

void main() {
  for (final language in ['de', 'en']) {
    testWidgets('example POI details and route action work in $language',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = false;
      final details = PoiDetails.fromGeoJsonFeature(
        (examplePlacesGeoJson()['features'] as List).first,
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        locale: Locale(language),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: PoiDetailsSheet(
            details: details,
            onRouteHere: () => selected = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.place), findsOneWidget);
      expect(find.byIcon(Icons.water_drop), findsNothing);
      expect(
          find.text(language == 'de' ? 'Adresse' : 'Address'), findsOneWidget);
      expect(find.text(exampleDestinations.first.address), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester
          .tap(find.text(language == 'de' ? 'Route hierhin' : 'Route here'));
      expect(selected, isTrue);
    });
  }

  test('uses the native EveryDoor store for Android and iOS', () {
    expect(
      everyDoorUrlForPlatform(TargetPlatform.android),
      everyDoorPlayStoreUrl,
    );
    expect(
      everyDoorUrlForPlatform(TargetPlatform.iOS),
      everyDoorAppStoreUrl,
    );
    expect(
      everyDoorUrlForPlatform(TargetPlatform.windows),
      everyDoorWebsiteUrl,
    );
  });

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
    expect(find.byIcon(Icons.close), findsOneWidget);
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

  testWidgets('uses a compact English fallback title for an unnamed fountain',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: PoiDetailsSheet(
          details: PoiDetails(tags: {}, title: ''),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Drinking water'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Drinking water'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('shows public toilet tags in the requested order',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final details = PoiDetails.fromGeoJsonFeature({
      'properties': {
        'amenity': 'toilets',
        'source': 'survey',
        'portable': 'no',
        'changing_table': 'limited',
        'panoramax': 'abc123',
        'toilets:handwashing': 'yes',
        'fee': 'no',
        'opening_hours': '24/7',
        'toilets:wheelchair': 'designated',
        'wheelchair': 'yes',
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
      home: Scaffold(body: PoiDetailsSheet(details: details)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Öffentliche Toilette'), findsOneWidget);
    expect(find.text('yes / designated'), findsOneWidget);
    expect(find.text('Kostenpflichtig'), findsOneWidget);
    expect(find.text('Wickeltisch'), findsOneWidget);
    expect(find.text('limited'), findsOneWidget);
    expect(find.text('panoramax'), findsNothing);
    final compactFee = tester
        .widgetList<ListItem>(find.byType(ListItem))
        .singleWhere((item) => item.label == 'Kostenpflichtig');
    expect(compactFee.compact, isTrue);
    expect(
      tester.getTopLeft(find.text('Rollstuhlgerecht')).dy,
      lessThan(tester.getTopLeft(find.text('Öffnungszeiten')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Öffnungszeiten')).dy,
      lessThan(tester.getTopLeft(find.text('Kostenpflichtig')).dy),
    );
  });

  testWidgets('shows bicycle repair equipment before opening hours',
      (tester) async {
    final details = PoiDetails.fromGeoJsonFeature({
      'properties': {
        'amenity': 'bicycle_repair_station',
        'opening_hours': '24/7',
        'service:bicycle:stand': 'yes',
        'service:bicycle:tools': 'yes',
        'service:bicycle:pump': 'no',
        'name': 'Radlpunkt',
        'description': 'Frei nutzbar',
        'operator': 'Gemeinde',
        'source:website': 'https://example.org/service',
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
      home: Scaffold(body: PoiDetailsSheet(details: details)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Radlpunkt'), findsNWidgets(2));
    expect(find.byIcon(Icons.build), findsOneWidget);
    expect(find.text('Beschreibung'), findsOneWidget);
    expect(find.text('Frei nutzbar'), findsOneWidget);
    expect(find.text('Betreiber'), findsOneWidget);
    expect(find.text('Gemeinde'), findsOneWidget);
    expect(find.text('Quell-Webseite'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Pumpe')).dy,
      lessThan(tester.getTopLeft(find.text('Öffnungszeiten')).dy),
    );
  });
}
