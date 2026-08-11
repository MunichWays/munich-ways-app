import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/route_planner_sheet.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

class _SettingsStore extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

void main() {
  testWidgets('uses compact info, menus, and recalculates roles after reorder',
      (tester) async {
    final model = MapScreenViewModel(store: _SettingsStore())
      ..routeStart = Place('Anfang', const LatLng(48.1, 11.5))
      ..waypoints.add(Place('Stopp', const LatLng(48.2, 11.6)))
      ..destination = Place('Ende', const LatLng(48.3, 11.7));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showRoutePlannerSheet(context, model: model),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    final draggable = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(draggable.initialChildSize, 0.55);
    expect(draggable.minChildSize, 0.55);
    expect(draggable.maxChildSize, 1);
    expect(draggable.snapSizes, [0.55, 1]);
    expect(find.byType(BottomSheetDragHandle), findsOneWidget);

    expect(find.textContaining('Optional anderen Startpunkt'), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byTooltip('Schließen'), findsOneWidget);
    final titleRight = tester.getTopRight(find.text('Route planen')).dx;
    final infoLeft = tester.getTopLeft(find.byIcon(Icons.info_outline)).dx;
    final saveLeft = tester.getTopLeft(find.byIcon(Icons.save_outlined)).dx;
    final closeLeft = tester.getTopLeft(find.byIcon(Icons.close).first).dx;
    expect(infoLeft - titleRight, lessThan(20));
    expect(saveLeft, greaterThan(infoLeft + 30));
    expect(closeLeft, greaterThan(saveLeft + 30));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.navigation)).color,
      AppColors.mapAccentColor,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.sports_score)).color,
      AppColors.mapRed,
    );
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining('Optional anderen Startpunkt'), findsOneWidget);
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Route speichern'), findsOneWidget);
    expect(find.text('Routenname'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mehr Optionen').first);
    await tester.pumpAndSettle();
    expect(find.text('Ändern'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    final endPosition = tester.getCenter(find.text('Ende'));
    final startPosition = tester.getCenter(find.text('Anfang'));
    final gesture = await tester.startGesture(endPosition);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    final target = Offset(startPosition.dx, startPosition.dy - 32);
    for (var step = 1; step <= 8; step++) {
      await gesture.moveTo(
        Offset.lerp(endPosition, target, step / 8)!,
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final newStartRow = find.ancestor(
      of: find.text('Ende'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: newStartRow,
        matching: find.byIcon(Icons.navigation),
      ),
      findsOneWidget,
    );
    final newDestinationRow = find.ancestor(
      of: find.text('Stopp'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
        of: newDestinationRow,
        matching: find.byIcon(Icons.sports_score),
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens large from the second intermediate stop', (tester) async {
    final model = MapScreenViewModel(store: _SettingsStore())
      ..routeStart = Place('Start', const LatLng(48.1, 11.5))
      ..waypoints.addAll([
        for (var index = 1; index <= 2; index++)
          Place('Zwischenziel $index', LatLng(48.1 + index / 100, 11.5)),
      ])
      ..destination = Place('Ziel', const LatLng(48.3, 11.7));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showRoutePlannerSheet(context, model: model),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    final draggable = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    final handle = find.byType(BottomSheetDragHandle);
    expect(draggable.initialChildSize, 1);
    expect(tester.getTopLeft(handle).dy, lessThan(50));
    expect(find.text('Route berechnen'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Route berechnen')).dy,
      lessThan(tester.view.physicalSize.height),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('clears a custom start back to the current position',
      (tester) async {
    final model = MapScreenViewModel(store: _SettingsStore())
      ..routeStart = Place('Anfang', const LatLng(48.1, 11.5))
      ..destination = Place('Ziel', const LatLng(48.3, 11.7));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showRoutePlannerSheet(context, model: model),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    expect(find.text('Anfang'), findsOneWidget);
    expect(find.byTooltip('Aktuellen Standort verwenden'), findsOneWidget);
    await tester.tap(find.byTooltip('Aktuellen Standort verwenden'));
    await tester.pump();

    expect(find.text('Aktueller Standort'), findsOneWidget);
    expect(find.byTooltip('Aktuellen Standort verwenden'), findsNothing);
    final startIcon = tester.widget<Icon>(find.byIcon(Icons.navigation));
    expect(startIcon.color, AppColors.mapAccentColor);
    expect(
      tester
          .widget<CircleAvatar>(
            find.ancestor(
              of: find.byIcon(Icons.navigation),
              matching: find.byType(CircleAvatar),
            ),
          )
          .backgroundColor,
      Colors.white,
    );
  });

  testWidgets('header resizes route planner in both directions',
      (tester) async {
    final model = MapScreenViewModel(store: _SettingsStore())
      ..destination = Place('Ziel', const LatLng(48.3, 11.7));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showRoutePlannerSheet(context, model: model),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    final header = find.text('Route planen');
    final sheet = find.byType(DraggableScrollableSheet);
    final middleTop = tester.getTopLeft(sheet).dy;

    await tester.drag(header, const Offset(0, -300));
    await tester.pumpAndSettle();
    final largeTop = tester.getTopLeft(sheet).dy;
    expect(largeTop, lessThan(middleTop - 100));

    await tester.drag(header, const Offset(0, 300));
    await tester.pumpAndSettle();
    final middleAgainTop = tester.getTopLeft(sheet).dy;
    expect(middleAgainTop, closeTo(middleTop, 2));

    await tester.drag(header, const Offset(0, 250));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
