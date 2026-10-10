import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/info/app_tip.dart';
import 'package:munich_ways/ui/info/info_sheet.dart';
import 'package:munich_ways/ui/info/info_sheet_tips_content.dart';
import 'package:munich_ways/ui/info/tip_illustration.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'MunichWays',
      packageName: 'de.munichways',
      version: '3.2.0',
      buildNumber: '75',
      buildSignature: '',
    );
  });

  Future<void> openInfo(WidgetTester tester,
      {bool english = false, bool dark = false, double textScale = 1}) async {
    await tester.pumpWidget(MaterialApp(
      locale: Locale(english ? 'en' : 'de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: dark ? darkThemeData : themeData,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showMapInfoSheet(context),
                    child: const Text('Info')),
              )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.text(english ? 'Tips & controls' : 'Tipps & Bedienung'),
        findsNothing);
    await tester.tap(find.text(english ? 'Legend & tips' : 'Legende & Tipps'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.text(english ? 'Tips & controls' : 'Tipps & Bedienung'));
    await tester
        .tap(find.text(english ? 'Tips & controls' : 'Tipps & Bedienung'));
    await tester.pumpAndSettle();
  }

  for (final english in [false, true]) {
    testWidgets(
        'opens every tip independently and returns to the list (${english ? "en" : "de"})',
        (tester) async {
      await openInfo(tester, english: english);
      final items = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(InfoSheetTipsContent),
            matching: find.byType(Text),
          ))
          .map((text) => text.data)
          .toList();
      expect(items, orderedAppTips.map((tip) => tip.title(english)).toList());

      for (final tip in orderedAppTips) {
        final title = find.text(tip.title(english));
        await tester.ensureVisible(title);
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(find.byType(InfoSheetTipContent), findsOneWidget);
        expect(find.text(tip.body(english)), findsOneWidget);
        expect(tester.widget<TipIllustration>(find.byType(TipIllustration)).tip,
            tip);
        // Changing details resets the scroll to the title; descriptions below
        // the screenshot remain reachable.
        expect(find.text(tip.title(english)).hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text(tip.body(english)));
        expect(find.text(tip.body(english)).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip(english ? 'Back' : 'Zurück'));
        await tester.pumpAndSettle();
        expect(find.byType(InfoSheetTipsContent), findsOneWidget);
      }
      await tester.tap(find.byTooltip(english ? 'Close' : 'Schließen'));
      await tester.pumpAndSettle();
      expect(find.byType(InfoSheet), findsNothing);
    });
  }

  testWidgets(
      'system Back follows tip, list, legend, info; Close dismisses a detail',
      (tester) async {
    await openInfo(tester);
    await tester.tap(find.text(AppTip.resumeNavigation.title(false)));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(InfoSheetTipsContent), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Tipps & Bedienung'), findsOneWidget);
    expect(find.byType(InfoSheetTipsContent), findsNothing);
    expect(find.text('Farben (MunichWays-Bewertung)'), findsOneWidget);
    // The legend remains in the Back path; its button opens the tips again.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Tipps & Bedienung'), findsNothing);
    await tester.tap(find.text('Legende & Tipps'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tipps & Bedienung'));
    await tester.tap(find.text('Tipps & Bedienung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTip.resumeNavigation.title(false)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.byType(InfoSheet), findsNothing);
  });

  for (final english in [false, true]) {
    testWidgets(
        'browses tips in both directions without leaving details ($english)',
        (tester) async {
      await openInfo(tester, english: english);
      await tester.tap(find.text(orderedAppTips.first.title(english)));
      await tester.pumpAndSettle();
      final previous = find.byKey(const ValueKey('previous-tip'));
      final next = find.byKey(const ValueKey('next-tip'));
      final frame = find.byKey(const ValueKey('tip-viewer-frame'));
      final size = tester.getSize(frame);
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      for (var i = 0; i < orderedAppTips.length; i++) {
        expect(tester.getSize(frame), size);
        expect(
            tester.getSize(find.byKey(const ValueKey('tip-description'))).width,
            size.width);
        expect(
            tester
                .widget<InfoSheetTipContent>(find.byType(InfoSheetTipContent))
                .tip,
            orderedAppTips[i]);
        expect(
            find.text('${i + 1} / ${orderedAppTips.length}'), findsOneWidget);
        expect(next.hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text(orderedAppTips[i].body(english)));
        expect(next.hitTestable(), findsOneWidget);
        if (i < orderedAppTips.length - 1) {
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(find.text(orderedAppTips[i + 1].title(english)).hitTestable(),
              findsOneWidget);
        }
      }
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      for (var i = orderedAppTips.length - 2; i >= 0; i--) {
        await tester.tap(previous);
        await tester.pumpAndSettle();
        expect(find.text(orderedAppTips[i].title(english)).hitTestable(),
            findsOneWidget);
        expect(
            tester
                .widget<InfoSheetTipContent>(find.byType(InfoSheetTipContent))
                .tip,
            orderedAppTips[i]);
      }
      await tester.tap(find.byTooltip(english ? 'Back' : 'Zurück'));
      await tester.pumpAndSettle();
      expect(find.byType(InfoSheetTipsContent), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'horizontal swipes change tips; vertical scroll and boundaries preserve the tip',
      (tester) async {
    await openInfo(tester);
    await tester.tap(find.text(orderedAppTips.first.title(false)));
    await tester.pumpAndSettle();
    AppTip current() => tester
        .widget<InfoSheetTipContent>(find.byType(InfoSheetTipContent))
        .tip;
    Offset swipeStart() => Offset(
          tester.getRect(find.byType(InfoSheet)).center.dx,
          tester.getBottomLeft(find.byKey(const ValueKey('next-tip'))).dy + 100,
        );
    await tester.dragFrom(swipeStart(), const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(current(), orderedAppTips.first);
    await tester.dragFrom(swipeStart(), const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(current(), orderedAppTips[1]);
    await tester.dragFrom(swipeStart(), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(current(), orderedAppTips[1]);
    await tester.dragFrom(swipeStart(), const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(current(), orderedAppTips.first);
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(orderedAppTips.last.title(false)));
    await tester.tap(find.text(orderedAppTips.last.title(false)));
    await tester.pumpAndSettle();
    await tester.dragFrom(swipeStart(), const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(current(), orderedAppTips.last);
    await tester.dragFrom(swipeStart(), const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(current(), orderedAppTips[orderedAppTips.length - 2]);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('all tips remain readable with large text ($size)',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openInfo(tester, dark: true, textScale: 2);
      for (final tip in orderedAppTips) {
        final title = find.text(tip.title(false));
        await tester.ensureVisible(title);
        await tester.tap(title);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TipIllustration));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Schließen').hitTestable(), findsOneWidget);
        expect(find.byTooltip('Zurück').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.tap(find.byTooltip('Zurück'));
        await tester.pumpAndSettle();
      }
    });
  }
}
