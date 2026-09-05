import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/map_overlay/map_compass_button.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

void main() {
  testWidgets('map idle reveals compass from native non-north bearing',
      (tester) async {
    final displayedBearing = ValueNotifier<double>(0);
    final idleTick = ValueNotifier<int>(0);
    const nativeBearing = 42.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapCompassOverlayButton(
            mapBearingDegrees: displayedBearing,
            mapIdleTick: idleTick,
            locationState: LocationState.DISPLAY,
            onNorthUp: () async {},
            queryMapBearingDegrees: () async => nativeBearing,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Norden nach oben ausrichten'), findsNothing);

    idleTick.value++;
    await tester.pump();

    expect(find.byTooltip('Norden nach oben ausrichten'), findsOneWidget);
    final compass = find.bySemanticsLabel('Norden nach oben ausrichten');
    expect(compass, findsOneWidget);
    expect(tester.getSize(compass), const Size.square(56));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.pumpWidget(const SizedBox.shrink());
    displayedBearing.dispose();
    idleTick.dispose();
  });
}
