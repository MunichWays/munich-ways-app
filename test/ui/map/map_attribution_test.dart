import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/map_attribution.dart';
import 'package:munich_ways/model/map_background.dart';

void main() {
  testWidgets('only shows accessible attribution links while expanded',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(children: [MapAttribution(expanded: false)]),
        ),
      ),
    );

    expect(
      find.textContaining('OpenStreetMap', findRichText: true),
      findsNothing,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(children: [MapAttribution(expanded: true)]),
        ),
      ),
    );

    expect(
      find.textContaining('OpenStreetMap', findRichText: true),
      findsOneWidget,
    );
    expect(tester.getSize(find.bySemanticsLabel('OpenMapTiles')).height, 48);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
  testWidgets(
      'aerial credits use two link rows and fit a narrow map at large text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: const SizedBox(
            width: 248,
            child: MapAttribution(
                expanded: true,
                inline: true,
                background: MapBackground.aerial)),
      )),
    ));
    expect(find.textContaining('Copernicus Sentinel-2'), findsOneWidget);
    final tiles = tester.getRect(find.bySemanticsLabel('OpenMapTiles'));
    final osm =
        tester.getRect(find.bySemanticsLabel('© OpenStreetMap contributors'));
    final free = tester.getRect(find.bySemanticsLabel('OpenFreeMap'));
    final bayern = tester.getRect(find.bySemanticsLabel('Bayern-WMTS'));
    expect(tiles.top, osm.top);
    expect(free.top, bayern.top);
    expect(free.top, tiles.bottom);
    for (final rect in [tiles, osm, free, bayern]) {
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.right, lessThanOrEqualTo(248));
    }
    expect(tester.takeException(), isNull);
  });
}
