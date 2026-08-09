import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/place_search/place_search_sheet.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

void main() {
  testWidgets('shows close button, compact handle, and three snap sizes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showPlaceSearchSheet(context),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Öffnen'));
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();

    final draggable = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(draggable.initialChildSize, 0.55);
    expect(draggable.minChildSize, 0.28);
    expect(draggable.maxChildSize, 1);
    expect(draggable.snapSizes, [0.28, 0.55, 1]);
    expect(find.byType(BottomSheetDragHandle), findsOneWidget);
    expect(find.byTooltip('Schließen'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });
  testWidgets('search field header can dismiss the small sheet',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showPlaceSearchSheet(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final draggable = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final resize = draggable.controller!.animateTo(
      0.28,
      duration: const Duration(milliseconds: 1),
      curve: Curves.linear,
    );
    await tester.pumpAndSettle();
    await resize;

    await tester.drag(find.byType(TextField), const Offset(0, 150));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
