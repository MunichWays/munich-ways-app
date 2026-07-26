import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/localization/app_locale_controller.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';
import 'package:munich_ways/routing/routing_service.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/settings/settings_sheet_content.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('selects routing mode and BRouter profile and shows info',
      (tester) async {
    final store = _MemorySettingsStore();
    final model = MapScreenViewModel(
      store: store,
      routingService: RoutingService(
        radlNavi: _UnusedProvider(),
        bRouter: _UnusedProvider(),
        radlNaviCoverage: _AlwaysCovered(),
      ),
    );
    final localeController = AppLocaleController(store: store);
    await localeController.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: localeController,
        child: MaterialApp(
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
              child: SettingsSheetContent(
                model: model,
                onReloadRadnetz: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('RadlNavi (Oberbayern) / BRouter (weltweit)'),
      findsOneWidget,
    );

    await tester.tap(find.text('BRouter überall'));
    await tester.pump();
    expect(model.routingMode, RoutingMode.bRouterEverywhere);
    expect(store.data.routingMode, RoutingMode.bRouterEverywhere);

    await tester.tap(find.text('Trekking (Standard)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rennrad (schnell)').last);
    await tester.pumpAndSettle();
    expect(model.bRouterProfile, BRouterProfile.fastBike);
    expect(store.data.bRouterProfile, BRouterProfile.fastBike);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Automatisch nutzt RadlNavi'),
      findsOneWidget,
    );
  });
}

class _MemorySettingsStore extends SettingsStore {
  SettingsData data = SettingsData.defaults;

  @override
  Future<SettingsData> load() async => data;

  @override
  Future<void> saveRoutingMode(RoutingMode routingMode) async {
    data = data.copyWith(routingMode: routingMode);
  }

  @override
  Future<void> saveBRouterProfile(BRouterProfile profile) async {
    data = data.copyWith(bRouterProfile: profile);
  }
}

class _AlwaysCovered implements RoutingCoverage {
  @override
  Future<bool> contains(LatLng point) async => true;
}

class _UnusedProvider implements RoutingProvider {
  @override
  Future<CycleRoute> route(
    List<LatLng> coordinates, {
    BRouterProfile profile = BRouterProfile.trekking,
  }) async =>
      throw StateError('Routing is not expected in this widget test.');
}
