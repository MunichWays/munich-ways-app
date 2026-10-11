import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/reviews/app_review_diagnostics.dart';
import 'package:munich_ways/reviews/app_review_service.dart';
import 'package:munich_ways/ui/info/info_sheet.dart';
import 'package:munich_ways/ui/info/info_sheet_diagnostics_content.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _DiagnosticsService extends AppReviewService {
  int reads = 0;
  bool fail = false;
  @override
  Future<AppReviewDiagnostics> readDiagnostics() async {
    reads++;
    if (fail) throw StateError('unavailable');
    return AppReviewDiagnostics(
      completedTrips: reads == 1 ? 2 : 3,
      requestAttempted: reads > 1,
      storeAvailable: true,
      events: [
        (
          time: DateTime.utc(2026, 10, 11),
          event: ReviewDiagnosticEvent.nativeHandoff
        )
      ],
    );
  }
}

void main() {
  setUp(() => PackageInfo.setMockInitialValues(
      appName: 'MunichWays',
      packageName: 'com.munichways.app',
      version: '3.2.1',
      buildNumber: '76',
      buildSignature: ''));

  Future<void> openAbout(WidgetTester tester, _DiagnosticsService service,
      {bool en = false, double scale = 1}) async {
    await tester.pumpWidget(MaterialApp(
      locale: Locale(en ? 'en' : 'de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(
          body: InfoSheet(
              reviewService: service,
              settingsDiagnostics: () => {'Zoom buttons': 'Yes'},
              runtimeDiagnostics: () => {'Routing mode': 'automatic'})),
    ));
    await tester.pumpAndSettle();
    final about =
        find.text(en ? 'About & attributions' : 'Über & Quellenangaben');
    await tester.ensureVisible(about);
    await tester.tap(about);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'diagnostics sits between terms and version, refreshes, copies and returns to About',
      (tester) async {
    final service = _DiagnosticsService();
    await openAbout(tester, service);
    final button = find.text('Diagnosedaten');
    await tester.ensureVisible(button);
    final terms = find.text('Nutzungsbedingungen');
    final version = find.textContaining('Version 3.2.1+76');
    expect(
        tester.getTopLeft(button).dy, greaterThan(tester.getTopLeft(terms).dy));
    expect(
        tester.getTopLeft(button).dy, lessThan(tester.getTopLeft(version).dy));
    expect(service.reads, 0);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('Version 3.2.1'), findsNothing);
    expect(find.textContaining('3.2.1+76'), findsOneWidget);
    expect(find.text('Bewertungszähler: 2/3'), findsNothing);
    expect(find.text('Routing mode: automatic'), findsNothing);
    expect(find.text('Zoom buttons: Yes'), findsNothing);
    expect(tester.getTopLeft(find.text('Einstellungen')).dy,
        lessThan(tester.getTopLeft(find.text('Karte & Navigation')).dy));
    for (final title in [
      'Einstellungen',
      'Karte & Navigation',
      'App-Bewertung'
    ]) {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
    expect(find.text('Bewertungszähler: 2/3'), findsOneWidget);
    final value = tester.widget<Text>(find.text('Bewertungszähler: 2/3'));
    final spans = (value.textSpan! as TextSpan).children!;
    expect((spans.last as TextSpan).style?.fontWeight, FontWeight.w600);
    expect(
        value.style?.fontSize,
        Theme.of(tester.element(find.text('Bewertungsz\u00e4hler: 2/3')))
            .textTheme
            .bodySmall
            ?.fontSize);
    expect(find.textContaining('an native API übergeben'), findsOneWidget);
    expect(find.text('Routing mode: automatic'), findsOneWidget);
    expect(find.text('Zoom buttons: Yes'), findsOneWidget);
    await tester.ensureVisible(find.text('Aktualisieren'));
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    expect(find.text('Bewertungszähler: 3/3'), findsOneWidget);
    expect(find.text('Einmaliger Anfrageversuch vermerkt: Ja'), findsOneWidget);
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData')
        copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.ensureVisible(find.text('Kopieren'));
    await tester.tap(find.text('Kopieren'));
    await tester.pumpAndSettle();
    expect(copied, contains('Bewertungszähler: 3/3'));
    expect(copied, contains('Routing mode: automatic'));
    expect(copied, contains('Zoom buttons: Yes'));
    expect(copied, isNot(contains('Version: Version')));
    expect(copied, contains('an native API übergeben'));
    expect(find.text('Kopiert'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(InfoSheetDiagnosticsContent), findsNothing);
    expect(find.text('Über & Quellenangaben'), findsOneWidget);
  });

  for (final en in [false, true]) {
    testWidgets(
        'diagnostics recovers from read failure and supports large text ($en)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _DiagnosticsService()..fail = true;
      await openAbout(tester, service, en: en, scale: 2);
      final button = find.text(en ? 'Diagnostics' : 'Diagnosedaten');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
          find.textContaining(en
              ? 'Could not load diagnostics'
              : 'Diagnosedaten konnten nicht'),
          findsOneWidget);
      service.fail = false;
      await tester.tap(find.text(en ? 'Refresh' : 'Aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.text(en ? 'Review counter: 3/3' : 'Bewertungszähler: 3/3'),
          findsNothing);
      final review = find.text(en ? 'App review' : 'App-Bewertung');
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(find.text(en ? 'Review counter: 3/3' : 'Bewertungszähler: 3/3'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(en ? 'Back' : 'Zurück'));
      await tester.pumpAndSettle();
      expect(find.byType(InfoSheetDiagnosticsContent), findsNothing);
    });
  }
}
