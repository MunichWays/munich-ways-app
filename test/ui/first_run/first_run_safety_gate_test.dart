import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/first_run/first_run_safety_gate.dart';
import 'package:munich_ways/ui/theme.dart';

void main() {
  Future<void> showNotice(
    WidgetTester tester, {
    bool show = true,
    String language = 'de',
    bool dark = false,
    double textScale = 1,
    Future<void> Function()? onDismiss,
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
    expect(
        find.text('Entspannt unterwegs – mit offenen Augen'), findsOneWidget);
    expect(
        find.text(
            'Achte auf dich und den Verkehr. Unsere Navigation kann Fehler '
            'enthalten. Beachte die Situation vor Ort und die Verkehrsregeln.'),
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
    await tester.tap(find.text('Nutzungsbedingungen'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Der Link konnte nicht geöffnet werden. Bitte versuche es erneut.'),
        findsOneWidget);
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
