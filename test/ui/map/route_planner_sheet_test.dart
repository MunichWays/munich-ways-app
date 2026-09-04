import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/route_planner_sheet.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

class _SettingsStore extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

class _RoutesStore extends SavedRoutesStore {
  SavedRoute? saved;

  @override
  Future<void> add(SavedRoute route) async => saved = route;
}

void main() {
  testWidgets('shows current comfort while navigating and hides it after edit',
      (tester) async {
    final model = MapScreenViewModel(store: _SettingsStore())
      ..destination = Place('Ziel', const LatLng(48.3, 11.7))
      ..route = MapRoute(
        CycleRoute(
          const [],
          4200,
          1200,
          comfort: const RouteComfort(
            index: 78,
            coverage: 82,
            sufficientCoverage: true,
            distribution: RouteComfortDistribution(
              black: 2,
              red: 7,
              yellow: 18,
              green: 68,
              unrated: 5,
            ),
          ),
        ),
        MapRouteState.SHOWN,
      )
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    await model.startNavigation();

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

    expect(find.byKey(const ValueKey('route-comfort-summary')), findsOneWidget);
    expect(find.text('78/100'), findsOneWidget);

    final destinationMenu = find.byTooltip('Mehr Optionen').last;
    await tester.ensureVisible(destinationMenu);
    await tester.tap(destinationMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-comfort-summary')), findsNothing);
    expect(find.text('78/100'), findsNothing);
  });

  testWidgets('reuses and overwrites the selected saved route name',
      (tester) async {
    final original = SavedRoute(
      name: 'Isarrunde',
      start: Place('Start', const LatLng(48.1, 11.5)),
      stops: [Place('Alter Stopp', const LatLng(48.2, 11.6))],
      destination: Place('Ziel', const LatLng(48.3, 11.7)),
      isFavorite: true,
      favoriteOrder: 2,
    );
    final model = MapScreenViewModel(store: _SettingsStore())
      ..routeStart = original.start
      ..waypoints.addAll(original.stops)
      ..destination = original.destination
      ..selectedSavedRoute = original;
    final routesStore = _RoutesStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showRoutePlannerSheet(
                context,
                model: model,
                routesStore: routesStore,
              ),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Isarrunde');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(routesStore.saved?.name, 'Isarrunde');
    expect(routesStore.saved?.isFavorite, isTrue);
    expect(routesStore.saved?.favoriteOrder, 2);
  });

  testWidgets('uses compact menus and recalculates roles after reorder',
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

    expect(find.byIcon(Icons.info_outline), findsNothing);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    final saveButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.save_outlined),
    );
    expect(
      saveButton.style?.backgroundColor?.resolve({}),
      AppColors.secondaryButtonBackground,
    );
    expect(
      saveButton.style?.foregroundColor?.resolve({}),
      AppColors.uiPrimary,
    );
    expect(
      saveButton.style?.backgroundColor?.resolve({WidgetState.disabled}),
      AppColors.disabledBackground,
    );
    expect(
      saveButton.style?.foregroundColor?.resolve({WidgetState.disabled}),
      AppColors.disabledForeground,
    );
    expect(find.byTooltip('Schließen'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Route planen'));
    expect(title.maxLines, 2);
    expect(title.overflow, isNull);
    final titleRight = tester.getTopRight(find.text('Route planen')).dx;
    final saveLeft = tester.getTopLeft(find.byIcon(Icons.save_outlined)).dx;
    final closeLeft = tester.getTopLeft(find.byIcon(Icons.close).first).dx;
    expect(saveLeft - titleRight, lessThan(20));
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
    final destinationRow = tester.widget<ListTile>(
      find.ancestor(of: find.text('Ende'), matching: find.byType(ListTile)),
    );
    expect(destinationRow.tileColor, AppColors.secondaryButtonBackground);
    expect(destinationRow.textColor, AppColors.uiPrimary);
    final calculateButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Route berechnen'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(
      calculateButton.style?.backgroundColor?.resolve({}),
      AppColors.uiPrimary,
    );
    expect(calculateButton.style?.foregroundColor?.resolve({}), Colors.white);

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

  testWidgets('highlights destination selection until a destination exists',
      (tester) async {
    final model = MapScreenViewModel(store: _SettingsStore());

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

    final destinationRow = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Ziel auswählen'),
        matching: find.byType(ListTile),
      ),
    );
    expect(destinationRow.tileColor, AppColors.uiPrimary);
    expect(destinationRow.textColor, Colors.white);

    final calculateButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Route berechnen'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(calculateButton.onPressed, isNull);
    expect(
      calculateButton.style?.backgroundColor?.resolve({WidgetState.disabled}),
      AppColors.disabledBackground,
    );
    expect(
      calculateButton.style?.foregroundColor?.resolve({WidgetState.disabled}),
      AppColors.disabledForeground,
    );
  });

  testWidgets('uses dark surfaces for route planner states in dark mode',
      (tester) async {
    final model = MapScreenViewModel(store: _SettingsStore());

    await tester.pumpWidget(
      MaterialApp(
        theme: darkThemeData,
        darkTheme: darkThemeData,
        themeMode: ThemeMode.dark,
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

    final startBackground = tester
        .widget<CircleAvatar>(
          find.ancestor(
            of: find.byIcon(Icons.navigation),
            matching: find.byType(CircleAvatar),
          ),
        )
        .backgroundColor;
    expect(
      startBackground,
      darkThemeData.colorScheme.surfaceContainerHighest,
    );
    final calculateButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Route berechnen'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(
      calculateButton.style?.backgroundColor?.resolve({WidgetState.disabled}),
      darkThemeData.colorScheme.surfaceContainerHighest,
    );
    final disabledForeground =
        darkThemeData.colorScheme.onSurface.withValues(alpha: 0.38);
    expect(
      calculateButton.style?.foregroundColor?.resolve({WidgetState.disabled}),
      disabledForeground,
    );
    final saveButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.save_outlined),
    );
    expect(
      saveButton.style?.backgroundColor?.resolve({WidgetState.disabled}),
      darkThemeData.colorScheme.surfaceContainerHighest,
    );
    expect(
      saveButton.style?.foregroundColor?.resolve({WidgetState.disabled}),
      disabledForeground,
    );

    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    model.destination = Place('Ziel', const LatLng(48.3, 11.7));
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    final destinationRow = tester.widget<ListTile>(
      find.ancestor(of: find.text('Ziel'), matching: find.byType(ListTile)),
    );
    expect(
      destinationRow.tileColor,
      darkThemeData.colorScheme.secondaryContainer,
    );
    expect(
      destinationRow.textColor,
      darkThemeData.colorScheme.onSecondaryContainer,
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
