import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/reviews/app_review_service.dart';
import 'package:munich_ways/ui/info/info_sheet.dart';
import 'package:munich_ways/ui/info/info_sheet_feedback_content.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _ReviewService extends AppReviewService {
  int opens = 0;
  bool succeeds = true;
  Completer<bool>? pending;

  @override
  Future<bool> openStoreListing() async {
    opens++;
    if (pending != null) return pending!.future;
    return succeeds;
  }
}

void main() {
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'MunichWays',
        packageName: 'com.munichways.app',
        version: '3.2.1',
        buildNumber: '76',
        buildSignature: '',
      ));
  Future<void> showInfo(WidgetTester tester, _ReviewService service,
      {bool english = false,
      double textScale = 1,
      Future<bool> Function(Uri)? launchFeedback}) async {
    await tester.pumpWidget(MaterialApp(
      locale: Locale(english ? 'en' : 'de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Info'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => InfoSheet(
                        reviewService: service, launchExternal: launchFeedback),
                  ),
                ),
              )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.text('Feedback'), findsOneWidget);
    expect(find.text(english ? 'Rate the app' : 'App bewerten'), findsNothing);
    final menu = find.text('Feedback');
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(service.opens, 0);
  }

  for (final english in [false, true]) {
    testWidgets(
        'manual review is localized, accessible and keeps feedback ($english)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final service = _ReviewService();
        await showInfo(tester, service, english: english, textScale: 2);
        expect(find.text('mail@munichways.de'), findsOneWidget);
        expect(find.byType(InfoSheetFeedbackContent), findsOneWidget);
        expect(find.byType(BottomSheetDragHandle), findsOneWidget);
        expect(tester.getSize(find.byType(BottomSheetFrame)).width, 360);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        final button = find.text(english ? 'Rate the app' : 'App bewerten');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(service.opens, 1);
        expect(find.byType(InfoSheetFeedbackContent), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
        'failed manual launch explains retry and subsequent launch works ($english)',
        (tester) async {
      final service = _ReviewService()..succeeds = false;
      await showInfo(tester, service, english: english);
      final button = find.text(english ? 'Rate the app' : 'App bewerten');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
          find.text(english
              ? 'Could not open the store. Please try again later.'
              : 'Store konnte nicht geöffnet werden. Bitte später erneut versuchen.'),
          findsOneWidget);
      service.succeeds = true;
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(service.opens, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('email address opens feedback with subject and app version',
      (tester) async {
    Uri? launched;
    final service = _ReviewService();
    await showInfo(tester, service, launchFeedback: (uri) async {
      launched = uri;
      return true;
    });
    await tester.tap(find.text('mail@munichways.de'));
    await tester.pumpAndSettle();
    expect(launched?.scheme, 'mailto');
    expect(launched?.path, 'mail@munichways.de');
    expect(launched?.queryParameters['subject'], 'Feedback Munichways App');
    expect(launched?.queryParameters['body'],
        'Appversion: Version 3.2.1+76 · Android\n\n');
    expect(service.opens, 0);
    expect(find.byType(InfoSheetFeedbackContent), findsOneWidget);
  });

  for (final english in [false, true]) {
    testWidgets('email launch failure is localized and can retry ($english)',
        (tester) async {
      var attempts = 0;
      await showInfo(tester, _ReviewService(), english: english,
          launchFeedback: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('email app unavailable');
        return true;
      });
      await tester.tap(find.text('mail@munichways.de'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              english ? 'No email app found' : 'Keine E-Mail-App gefunden'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.text('mail@munichways.de'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('closing the feedback sheet dismisses info without launching',
      (tester) async {
    final service = _ReviewService();
    await showInfo(tester, service);
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.byType(InfoSheetFeedbackContent), findsNothing);
    expect(find.text('Info'), findsOneWidget);
    expect(service.opens, 0);
  });

  testWidgets('closing info during launch does not use a disposed context',
      (tester) async {
    final service = _ReviewService()..pending = Completer<bool>();
    await showInfo(tester, service);
    await tester.tap(find.text('App bewerten'));
    await tester.pumpWidget(const SizedBox());
    service.pending!.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('feedback uses supplied texts and opens the MunichWays website',
      (tester) async {
    Uri? launched;
    await showInfo(tester, _ReviewService(), launchFeedback: (uri) async {
      launched = uri;
      return true;
    });
    expect(
        find.text(
            'Gefällt dir MunichWays? Deine Bewertung hilft anderen, die App zu entdecken.'),
        findsOneWidget);
    expect(
        find.text(
            'Fragen oder Ideen? Schreib uns gerne. Wir arbeiten ehrenamtlich – eine Antwort kann etwas dauern.'),
        findsOneWidget);
    final website = find.text('Über MunichWays');
    await tester.ensureVisible(website);
    await tester.tap(website);
    await tester.pumpAndSettle();
    expect(launched, Uri.parse('https://www.munichways.de/'));
  });

  testWidgets('feedback back button and system Back return to the info menu',
      (tester) async {
    await showInfo(tester, _ReviewService());
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    expect(find.byType(InfoSheetFeedbackContent), findsNothing);
    await tester.tap(find.text('Feedback'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(InfoSheetFeedbackContent), findsNothing);
    expect(find.text('Feedback'), findsOneWidget);
    expect(find.byType(InfoSheet), findsOneWidget);
  });
}
