import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/route_transfer.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/route_import_dialog.dart';
import 'package:munich_ways/ui/theme.dart';

import '../../support/wakelock_stub.dart';

class _Settings extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

void main() {
  setUp(stubWakelock);
  final transfer = RouteTransfer.fromJson(jsonDecode(
      File('test_resources/routing/route-transfer.json').readAsStringSync()));

  for (final english in [false, true]) {
    for (final size in [const Size(320, 640), const Size(640, 320)]) {
      testWidgets(
          'import actions stay reachable with large text ($english, $size)',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = MapScreenViewModel(store: _Settings());
        addTearDown(model.dispose);
        await tester.pumpWidget(MaterialApp(
          theme: darkThemeData,
          locale: Locale(english ? 'en' : 'de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: EdgeInsets.only(bottom: size.width < 400 ? 250 : 0),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showRouteImportDialog(context, transfer, model),
                child: const Text('Open'),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final use = find.widgetWithText(FilledButton,
            english ? 'Use without saving' : 'Ohne Speichern übernehmen');
        final save = find.widgetWithText(
            FilledButton, english ? 'Save and use' : 'Speichern & übernehmen');
        await tester.ensureVisible(use);
        expect(use.hitTestable(), findsOneWidget);
        await tester.ensureVisible(save);
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getTopLeft(use).dy, lessThan(tester.getTopLeft(save).dy));
        expect(
            tester
                .widget<FilledButton>(use)
                .style!
                .backgroundColor!
                .resolve({}),
            AppButtonStyles.secondary(tester.element(use))
                .backgroundColor!
                .resolve({}));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip(english ? 'Cancel' : 'Abbrechen'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(model.selectedSavedRoute, isNull);
      });
    }
  }
}
