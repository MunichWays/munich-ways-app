import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/first_run/first_run_safety_gate.dart';
import 'package:munich_ways/ui/info/app_tip.dart';
import 'package:munich_ways/ui/info/info_sheet_tips_content.dart';
import 'package:munich_ways/ui/theme.dart';

void main() {
  Future<void> showNotice(
    WidgetTester tester, {
    bool show = true,
    bool tutorial = false,
    String language = 'de',
    bool dark = false,
    double textScale = 1,
    Future<void> Function()? onDismiss,
    Future<void> Function()? onDismissTutorial,
    Future<bool> Function(Uri)? openTerms,
    Widget Function(BuildContext, bool)? mapBuilder,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: dark ? darkThemeData : themeData,
      locale: Locale(language),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: FirstRunSafetyGate(
        showNotice: show,
        onDismiss: onDismiss ?? () async {},
        showTutorial: tutorial,
        onDismissTutorial: onDismissTutorial ?? () async {},
        openTerms: openTerms,
        builder: mapBuilder ??
            (_, enabled) => Scaffold(
                  body: Text(enabled ? 'Map started' : 'Map preloading'),
                ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('uses the shorter German text while preloading the map',
      (tester) async {
    await showNotice(tester);
    expect(find.text('So einfach wie Radfahren!'), findsOneWidget);
    expect(find.text('Entspannt Rad fahren im Alltag.'), findsOneWidget);
    expect(find.text('Ziel auf der Karte länger drücken'), findsOneWidget);
    expect(find.text('„Route hierhin“ wählen, dann „Starten“ antippen'),
        findsOneWidget);
    expect(find.text('Navigationshinweisen folgen'), findsOneWidget);
    expect(
        find.text(
            'Achte auf dich und den Verkehr. Die Navigation oder die Kartenbasis '
            'können Fehler enthalten. Beachte die Situation vor Ort.'),
        findsOneWidget);
    expect(find.text('Los geht’s'), findsOneWidget);
    expect(find.byTooltip('Schließen'), findsOneWidget);
    expect(find.text('Map started'), findsNothing);
    expect(find.text('Map preloading'), findsOneWidget);
    expect(find.text('Map preloading').hitTestable(), findsNothing);
  });

  for (final action in ['button', 'close', 'back']) {
    testWidgets('$action closes once without waiting for storage',
        (tester) async {
      final saved = Completer<void>();
      var dismissals = 0;
      await showNotice(tester, onDismiss: () async {
        dismissals++;
        await saved.future;
      });
      switch (action) {
        case 'button':
          await tester.tap(find.text('Los geht’s'));
        case 'close':
          await tester.tap(find.byTooltip('Schließen'));
        case 'back':
          await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.text('Map started'), findsOneWidget);
      expect(dismissals, 1);
      saved.completeError(StateError('Transient storage failure'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Map started'), findsOneWidget);
    });
  }

  testWidgets('updates go straight to the map without recording dismissal',
      (tester) async {
    var dismissals = 0;
    await showNotice(tester, show: false, onDismiss: () async => dismissals++);
    expect(find.text('Map started'), findsOneWidget);
    expect(find.text('Los geht’s'), findsNothing);
    expect(dismissals, 0);
  });

  testWidgets(
      'notice then optional offer preserves one map and defers permissions',
      (tester) async {
    var mounts = 0;
    var disposals = 0;
    var notices = 0;
    var tutorials = 0;
    final states = <bool>[];
    await showNotice(
      tester,
      tutorial: true,
      onDismiss: () async => notices++,
      onDismissTutorial: () async => tutorials++,
      mapBuilder: (_, enabled) => _PreloadedMap(
        enabled: enabled,
        onMount: () => mounts++,
        onDispose: () => disposals++,
        onBuild: states.add,
        onTap: () {},
      ),
    );
    final closeNotice = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Los geht’s'))
        .onPressed!;
    closeNotice();
    closeNotice(); // A queued second tap must not also dismiss the tutorial.
    await tester.pumpAndSettle();
    expect(find.text('Neu hier?'), findsOneWidget);
    expect(states.last, isFalse);
    expect(notices, 1);
    expect(tutorials, 0);
    expect(mounts, 1);
    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();
    expect(states.last, isTrue);
    expect(tutorials, 1);
    expect(mounts, 1);
    expect(disposals, 0);
  });

  testWidgets('shows exactly the agreed top three with back and next',
      (tester) async {
    var completions = 0;
    await showNotice(tester,
        show: false,
        tutorial: true,
        onDismissTutorial: () async => completions++);
    await tester.tap(find.text('Tipps ansehen'));
    await tester.pumpAndSettle();
    final expected = [
      AppTip.resumeNavigation,
      AppTip.savedPlaceMenu,
      AppTip.exploreMap
    ];
    for (var index = 0; index < expected.length; index++) {
      expect(find.text('${index + 1} / 3'), findsOneWidget);
      expect(
          tester
              .widget<InfoSheetTipContent>(find.byType(InfoSheetTipContent))
              .tip,
          expected[index]);
      expect(find.text(expected[index].body(false)), findsOneWidget);
      expect(find.text('Map started'), findsNothing);
      if (index == 1) {
        await tester.tap(find.byKey(const ValueKey('previous-tip')));
        await tester.pumpAndSettle();
        expect(find.text('1 / 3'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('next-tip')));
        await tester.pumpAndSettle();
      }
      await tester.tap(index == 2
          ? find.text('Fertig')
          : find.byKey(const ValueKey('next-tip')));
      await tester.pumpAndSettle();
    }
    expect(completions, 1);
    expect(find.text('Map started'), findsOneWidget);
    expect(find.byType(InfoSheetTipContent), findsNothing);
  });

  testWidgets(
      'all tips are optional after the top three and keep the same frame',
      (tester) async {
    var completions = 0;
    await showNotice(tester,
        show: false,
        tutorial: true,
        onDismissTutorial: () async => completions++);
    await tester.tap(find.text('Tipps ansehen'));
    await tester.pumpAndSettle();
    final frame = find.byKey(const ValueKey('tip-viewer-frame'));
    final size = tester.getSize(frame);
    expect(find.text('Alle Tipps ansehen'), findsNothing);
    for (var index = 0; index < 2; index++) {
      await tester.tap(find.byKey(const ValueKey('next-tip')));
      await tester.pumpAndSettle();
      expect(tester.getSize(frame), size);
    }
    await tester.tap(find.text('Alle Tipps ansehen'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 9'), findsOneWidget);
    expect(tester.getSize(frame), size);
    expect(completions, 0);
    for (var index = 3; index < orderedAppTips.length; index++) {
      await tester.tap(find.byKey(const ValueKey('next-tip')));
      await tester.pumpAndSettle();
      expect(tester.getSize(frame), size);
      expect(
          tester
              .widget<InfoSheetTipContent>(find.byType(InfoSheetTipContent))
              .tip,
          orderedAppTips[index]);
    }
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(completions, 1);
    expect(find.text('Map started'), findsOneWidget);
  });

  for (final action in ['later', 'close', 'back']) {
    testWidgets('tutorial $action closes without waiting for storage',
        (tester) async {
      final saved = Completer<void>();
      var completions = 0;
      await showNotice(tester, show: false, tutorial: true,
          onDismissTutorial: () async {
        completions++;
        await saved.future;
      });
      if (action == 'later') {
        await tester.tap(find.text('Später'));
      } else {
        await tester.tap(find.text('Tipps ansehen'));
        await tester.pumpAndSettle();
        if (action == 'close') {
          await tester.tap(find.byTooltip('Schließen'));
        } else {
          await tester.binding.handlePopRoute();
        }
      }
      await tester.pumpAndSettle();
      expect(completions, 1);
      expect(find.text('Map started'), findsOneWidget);
      saved.completeError(StateError('Transient tutorial write failure'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Map started'), findsOneWidget);
    });
  }

  testWidgets(
      'tutorial position survives theme/language change and backgrounding',
      (tester) async {
    var completions = 0;
    await showNotice(tester,
        show: false,
        tutorial: true,
        onDismissTutorial: () async => completions++);
    await tester.tap(find.text('Tipps ansehen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('next-tip')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await showNotice(tester,
        show: false,
        tutorial: true,
        language: 'en',
        dark: true,
        onDismissTutorial: () async => completions++);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text(AppTip.savedPlaceMenu.title(true)), findsOneWidget);
    expect(completions, 0);
  });

  for (final size in [const Size(360, 640), const Size(640, 320)]) {
    for (final language in ['de', 'en']) {
      testWidgets('tutorial fits $size at 200 percent text in $language',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await showNotice(tester,
            show: false,
            tutorial: true,
            language: language,
            dark: true,
            textScale: 2);
        expect(tester.takeException(), isNull);
        await tester
            .tap(find.text(language == 'de' ? 'Tipps ansehen' : 'View tips'));
        await tester.pumpAndSettle();
        for (var index = 0; index < 3; index++) {
          final next = index == 2
              ? find.text(language == 'de' ? 'Fertig' : 'Done')
              : find.byKey(const ValueKey('next-tip'));
          expect(next.hitTestable(), findsOneWidget);
          expect(
              find
                  .byTooltip(language == 'de' ? 'Schließen' : 'Close')
                  .hitTestable(),
              findsOneWidget);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
        expect(find.text('Map started'), findsOneWidget);
      });
    }
  }

  testWidgets('terms link can fail and recover without dismissing the notice',
      (tester) async {
    final urls = <Uri>[];
    var dismissals = 0;
    await showNotice(tester,
        onDismiss: () async => dismissals++,
        openTerms: (uri) async {
          urls.add(uri);
          return urls.length > 1;
        });
    await tester.ensureVisible(find.text('Nutzungsbedingungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nutzungsbedingungen'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Der Link konnte nicht geöffnet werden. Bitte versuche es erneut.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Nutzungsbedingungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nutzungsbedingungen'));
    await tester.pumpAndSettle();
    expect(urls, [Uri.parse(appTermsUrl), Uri.parse(appTermsUrl)]);
    expect(dismissals, 0);
    expect(find.text('Los geht’s'), findsOneWidget);
    expect(find.text('Map started'), findsNothing);
  });

  testWidgets('backgrounding and rebuilding never count as dismissal',
      (tester) async {
    var dismissals = 0;
    await showNotice(tester, onDismiss: () async => dismissals++);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await showNotice(tester, dark: true, onDismiss: () async => dismissals++);
    expect(find.text('Los geht’s'), findsOneWidget);
    expect(dismissals, 0);
  });

  testWidgets('preloads once, hides map accessibility and enables it on close',
      (tester) async {
    var mounts = 0;
    var disposals = 0;
    var taps = 0;
    final states = <bool>[];
    Widget mapBuilder(BuildContext _, bool enabled) => _PreloadedMap(
          enabled: enabled,
          onMount: () => mounts++,
          onDispose: () => disposals++,
          onBuild: states.add,
          onTap: () => taps++,
        );
    final semantics = tester.ensureSemantics();
    try {
      await showNotice(tester, mapBuilder: mapBuilder);
      expect(mounts, 1);
      expect(states.last, isFalse);
      expect(find.bySemanticsLabel('Map action'), findsNothing);
      await tester.tap(find.text('Map action'), warnIfMissed: false);
      expect(taps, 0);
      await showNotice(tester, dark: true, mapBuilder: mapBuilder);
      expect(mounts, 1);
      expect(disposals, 0);
      await tester.tap(find.text('Los geht’s'));
      await tester.pumpAndSettle();
      expect(states.last, isTrue);
      expect(mounts, 1);
      expect(disposals, 0);
      expect(find.bySemanticsLabel('Map action'), findsOneWidget);
      await tester.tap(find.text('Map action'));
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox());
      expect(disposals, 1);
    } finally {
      semantics.dispose();
    }
  });

  for (final size in [const Size(360, 640), const Size(640, 320)]) {
    for (final language in ['de', 'en']) {
      testWidgets('notice fits $size at 200 percent text in $language',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          await showNotice(tester,
              language: language, dark: true, textScale: 2);
          expect(tester.takeException(), isNull);
          final action =
              find.text(language == 'de' ? 'Los geht’s' : 'Let’s go');
          expect(action.hitTestable(), findsOneWidget);
          expect(
              find
                  .byTooltip(language == 'de' ? 'Schließen' : 'Close')
                  .hitTestable(),
              findsOneWidget);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await tester.scrollUntilVisible(
            find.text(
                language == 'de' ? 'Nutzungsbedingungen' : 'Terms of use'),
            100,
            scrollable: find.byType(Scrollable),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(find.text('Map started'), findsOneWidget);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}

class _PreloadedMap extends StatefulWidget {
  const _PreloadedMap(
      {required this.enabled,
      required this.onMount,
      required this.onDispose,
      required this.onBuild,
      required this.onTap});
  final bool enabled;
  final VoidCallback onMount;
  final VoidCallback onDispose;
  final ValueChanged<bool> onBuild;
  final VoidCallback onTap;
  @override
  State<_PreloadedMap> createState() => _PreloadedMapState();
}

class _PreloadedMapState extends State<_PreloadedMap> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild(widget.enabled);
    return Scaffold(
        body: TextButton(
            onPressed: widget.onTap, child: const Text('Map action')));
  }
}
