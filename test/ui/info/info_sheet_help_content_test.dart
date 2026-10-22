import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/info/info_sheet_help_content.dart';

void main() {
  testWidgets('legend omits unused plan and network-style entries',
      (tester) async {
    var openedTips = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
              child: InfoSheetHelpContent(onOpenTips: () => openedTips++)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blau durchgezogen'), findsOneWidget);
    expect(find.text('Blau gestrichelt'), findsOneWidget);
    expect(find.textContaining('Schiebestücke'), findsOneWidget);
    expect(find.text('Radl-Komfort-Index'), findsOneWidget);
    expect(find.textContaining('mindestens 70 Prozent'), findsOneWidget);
    expect(find.text('Erläuterung'), findsOneWidget);
    expect(find.text('Farben (MunichWays-Bewertung)'), findsOneWidget);
    expect(find.textContaining('Plan / Lücke'), findsNothing);
    expect(find.textContaining('RadlVorrang-Netz'), findsNothing);
    expect(find.textContaining('Weitere Strecken'), findsNothing);
    expect(find.textContaining('durchgezogene Linie'), findsNWidgets(2));
    expect(find.textContaining('gestrichelte Linie'), findsNWidgets(3));
    expect(find.text('Unbewertete Wege (OSM)'), findsOneWidget);
    expect(find.textContaining('Befestigter Fahrradweg'), findsOneWidget);
    expect(find.textContaining('Wohn- oder Nebenstraße'), findsOneWidget);
    expect(find.textContaining('dezent gelbe Linie'), findsOneWidget);
    expect(find.textContaining('ohne MunichWays-Bewertung'), findsNWidgets(2));
    expect(find.textContaining('Halte eine bewertete Linie'), findsNothing);
    expect(find.text('Ziel auswählen'), findsNothing);
    expect(find.text('Details zu Streckenabschnitten'), findsNothing);
    expect(find.text('Tipps & Bedienung'), findsNWidgets(2));
    final topLink = find.widgetWithText(TextButton, 'Tipps & Bedienung');
    final bottomButton = find.widgetWithText(FilledButton, 'Tipps & Bedienung');
    expect(tester.getTopLeft(topLink).dy,
        lessThan(tester.getTopLeft(find.text('Radl-Komfort-Index')).dy));
    await tester.tap(topLink);
    expect(openedTips, 1);
    await tester.ensureVisible(bottomButton);
    await tester.tap(bottomButton);
    expect(openedTips, 2);
    expect(find.textContaining('Halte eine farbige Linie'), findsNothing);
  });
}
