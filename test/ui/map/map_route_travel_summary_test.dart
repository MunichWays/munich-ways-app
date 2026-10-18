import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/map_overlay/map_route_travel_summary.dart';
import 'package:munich_ways/ui/map/navigation_remaining.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Ahem deliberately uses square glyphs. Check compact layout against the
    // actual Material font shipped with the same Flutter SDK used by CI.
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((package) => package['name'] == 'flutter');
    final flutterDirectory =
        Directory.fromUri(configFile.uri.resolve(flutter['rootUri'] as String));
    final fonts = flutterDirectory.uri
        .resolve('../../bin/cache/artifacts/material_fonts/');
    final loader = FontLoader('TestRoboto');
    for (final name in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
      loader.addFont(File.fromUri(fonts.resolve(name))
          .readAsBytes()
          .then(ByteData.sublistView));
    }
    await loader.load();
  });
  late DateTime now;
  late CycleRoute route;
  setUp(() {
    now = DateTime(2026, 10, 17, 11, 23);
    route = CycleRoute(
        const [LatLng(48.14, 11.57), LatLng(48.15, 11.57)], 6900, 1320);
  });

  Future<void> show(WidgetTester tester,
          {bool navigating = false,
          NavigationRemaining? sample,
          double scale = 1}) =>
      tester.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'TestRoboto'),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
                body: Center(
                    child: SizedBox(
              width: 280,
              child: MapRouteTravelSummary(
                  route: route,
                  navigationStarted: navigating,
                  remaining: sample,
                  now: () => now),
            ))),
          )));

  testWidgets('compact preview keeps minutes, arrival and distance on one line',
      (tester) async {
    await show(tester);
    expect(find.text('22 Min'), findsOneWidget);
    expect(find.text('11:45'), findsOneWidget);
    expect(find.text('6,9 km'), findsOneWidget);
    expect(find.byIcon(Icons.sports_score), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNothing);
    final minutes = tester.getRect(find.text('22 Min'));
    final arrival = tester.getRect(find.text('11:45'));
    final distance = tester.getRect(find.text('6,9 km'));
    final panel = tester.getRect(find.byType(MapRouteTravelSummary));
    expect(minutes.center.dy, arrival.center.dy);
    expect(arrival.center.dy, distance.center.dy);
    expect(minutes.right, lessThan(arrival.left));
    expect(arrival.right, lessThan(distance.left));
    expect(panel.left, lessThan(minutes.left));
    expect(panel.right, greaterThanOrEqualTo(distance.right));
    expect(panel.height, lessThanOrEqualTo(28));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'planning clock updates by minute, resumes and cancels on dispose',
      (tester) async {
    await show(tester);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('11:46'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('12:06'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation uses its snapshot clock, including paused rebuilds',
      (tester) async {
    final sample = NavigationRemaining.estimate(route, 1, estimatedAt: now);
    await show(tester, navigating: true, sample: sample);
    expect(find.text('≈ 22 Min'), findsOneWidget);
    now = now.add(const Duration(minutes: 20));
    await tester.pump(const Duration(minutes: 20));
    await show(tester, navigating: true, sample: sample);
    expect(find.text('11:45'), findsOneWidget);
    await show(tester, navigating: true);
    expect(find.text('—:—'), findsOneWidget);
    await show(tester,
        navigating: true,
        sample: NavigationRemaining.estimate(route, 1, estimatedAt: now));
    expect(find.text('12:05'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('large text keeps its font size and uses horizontal scrolling',
      (tester) async {
    await show(tester,
        navigating: true,
        scale: 2,
        sample: NavigationRemaining.estimate(route, 1, estimatedAt: now));
    expect(tester.getCenter(find.text('≈ 22 Min')).dy,
        tester.getCenter(find.text('6,9 km')).dy);
    expect(tester.getSize(find.byType(MapRouteTravelSummary)).height,
        lessThanOrEqualTo(64));
    final scroll = find.byType(SingleChildScrollView);
    expect(tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.horizontal);
    await tester.drag(scroll, const Offset(-500, 0));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byType(MapRouteTravelSummary));
    expect(panel.right,
        greaterThanOrEqualTo(tester.getRect(find.text('6,9 km')).right));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
