import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/map_attribution.dart';

void main() {
  testWidgets('only shows the narrow attribution row while expanded',
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
  });
}
