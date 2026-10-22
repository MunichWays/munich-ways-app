import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/route_transfer_io.dart';
import 'package:munich_ways/model/route_transfer.dart';
import 'package:munich_ways/ui/map/route_import_source_dialog.dart';
import 'package:munich_ways/ui/theme.dart';

void main() {
  final uri = Uri.parse('https://radlnavi.munichways.de/r/${'a' * 32}');
  final transfer = RouteTransfer.fromJson(jsonDecode(
      File('test_resources/routing/route-transfer.json').readAsStringSync()));

  Future<void> open(WidgetTester tester, RouteImportSourceDialog chooser,
      {void Function(RouteTransfer?)? result}) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      final route = await showDialog<RouteTransfer>(
                          context: context, builder: (_) => chooser);
                      result?.call(route);
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'GPX is primary and comes before the RadlNavi secondary link action',
      (tester) async {
    await open(tester, const RouteImportSourceDialog());
    final file = find.widgetWithText(FilledButton, 'GPX-Datei auswählen');
    final scan = find.widgetWithText(OutlinedButton, 'QR-Code scannen');
    final link = find.widgetWithText(FilledButton, 'Link laden');
    final website = find.widgetWithText(TextButton, 'zu RadlNavi');
    expect(tester.getTopLeft(file).dy,
        lessThan(tester.getTopLeft(find.text('oder aus RadlNavi')).dy));
    expect(tester.getTopLeft(scan).dy,
        lessThan(tester.getTopLeft(find.byType(TextField)).dy));
    expect(tester.getTopLeft(find.byType(TextField)).dy,
        lessThan(tester.getTopLeft(link).dy));
    expect(tester.getTopLeft(link).dy, lessThan(tester.getTopLeft(website).dy));
    final context = tester.element(file);
    expect(
        tester.widget<FilledButton>(file).style!.backgroundColor!.resolve({}),
        AppButtonStyles.primary(context).backgroundColor!.resolve({}));
    expect(
        tester.widget<FilledButton>(link).style!.backgroundColor!.resolve({}),
        AppButtonStyles.secondary(context).backgroundColor!.resolve({}));
  });

  testWidgets(
      'paste is explicit and fills the link field without requesting the camera',
      (tester) async {
    var reads = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        reads++;
        return {'text': uri.toString()};
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester, const RouteImportSourceDialog());
    expect(reads, 0);
    await tester.tap(find.byTooltip('Aus Zwischenablage einfügen'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        uri.toString());
  });

  testWidgets(
      'invalid link never loads; expired link can recover without leaving the chooser',
      (tester) async {
    var calls = 0;
    RouteTransfer? selected;
    await open(tester, RouteImportSourceDialog(loadLink: (value) async {
      expect(value, uri);
      if (++calls == 1) throw const ExpiredRouteLinkException();
      return transfer;
    }), result: (value) => selected = value);
    await tester.enterText(
        find.byType(TextField), 'https://evil.invalid/r/${'a' * 32}');
    await tester.tap(find.text('Link laden'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(
        find.textContaining('gültigen RadlNavi-Teilen-Link'), findsOneWidget);
    await tester.enterText(find.byType(TextField), uri.toString());
    await tester.tap(find.text('Link laden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('abgelaufen'), findsOneWidget);
    expect(selected, isNull);
    await tester.tap(find.text('Link laden'));
    await tester.pumpAndSettle();
    expect(selected, same(transfer));
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
      'network error permits retry and QR uses the same validated loader',
      (tester) async {
    var scans = 0, calls = 0;
    RouteTransfer? selected;
    await open(
        tester,
        RouteImportSourceDialog(scanLink: (_) async {
          scans++;
          return uri;
        }, loadLink: (value) async {
          expect(value, uri);
          if (++calls == 1) throw const SocketException('offline');
          return transfer;
        }),
        result: (value) => selected = value);
    await tester.tap(find.text('QR-Code scannen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Internetverbindung'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        uri.toString());
    await tester.tap(find.text('Link laden'));
    await tester.pumpAndSettle();
    expect(scans, 1);
    expect(calls, 2);
    expect(selected, same(transfer));
  });

  testWidgets(
      'picker cancellation, malformed file and subsequent import recover',
      (tester) async {
    var calls = 0;
    RouteTransfer? selected;
    await open(tester, RouteImportSourceDialog(pickFile: () async {
      calls++;
      if (calls == 1) return null;
      if (calls == 2) throw const FormatException('invalid');
      return transfer;
    }), result: (value) => selected = value);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('GPX-Datei auswählen'));
      await tester.pumpAndSettle();
      if (i == 0) expect(find.byType(Dialog), findsOneWidget);
      if (i == 1)
        expect(find.textContaining('Datei nicht lesbar'), findsOneWidget);
    }
    expect(selected, same(transfer));
  });

  testWidgets(
      'dismissal during a download ignores its late result and leaves underlying page open',
      (tester) async {
    final pending = Completer<RouteTransfer>();
    var calls = 0;
    RouteTransfer? selected;
    await open(tester, RouteImportSourceDialog(loadLink: (_) {
      calls++;
      return pending.future;
    }), result: (value) => selected = value);
    await tester.enterText(find.byType(TextField), uri.toString());
    await tester.tap(find.text('Link laden'));
    await tester.pump();
    await tester.tap(find.text('Link laden'), warnIfMissed: false);
    expect(calls, 1);
    await tester.tap(find.byTooltip('Abbrechen'));
    await tester.pump();
    // Complete before the dismissal animation disposes the widget.
    pending.complete(transfer);
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'narrow screen and large text keep the source chooser scrollable with a keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.6),
                viewInsets: const EdgeInsets.only(bottom: 250)),
            child: child!),
        home: const Scaffold(body: RouteImportSourceDialog())));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
        tester.getSize(find.byKey(const Key('route-import-panel'))).width, 336);
    expect(tester.takeException(), isNull);
  });
}
