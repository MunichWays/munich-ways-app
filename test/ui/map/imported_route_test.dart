import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/routing/routing_provider.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_service.dart';
import 'dart:async';
import 'package:munich_ways/api/saved_routes_store.dart';
import '../../support/wakelock_stub.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/route_transfer.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';

class _Settings extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

class _Snapshots extends SavedRoutesStore {
  final ready = Completer<SavedRoute>();
  @override
  Future<SavedRoute> loadSnapshot(SavedRoute route) => ready.future;
}

class _Provider implements RoutingProvider {
  var ready = Completer<CycleRoute>();
  @override
  Future<CycleRoute> route(List<LatLng> coordinates,
          {BRouterProfile profile = BRouterProfile.trekking}) =>
      ready.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(stubWakelock);
  test('import stays exact until deliberate refresh or editing', () async {
    final transfer = RouteTransfer.fromJson(jsonDecode(
        File('test_resources/routing/route-transfer.json').readAsStringSync()));
    final model = MapScreenViewModel(store: _Settings());
    addTearDown(model.dispose);
    final saved = SavedRoute(
        name: transfer.name,
        start: transfer.plan.first,
        stops: transfer.plan.sublist(1, 3),
        destination: transfer.plan.last,
        snapshot: transfer);
    model.setSavedRoutePlan(saved);
    expect(model.isOriginalRoute, true);
    expect(model.automaticReroutingEnabled, false);
    expect(model.canSelectTemporaryShortestRoute, false);
    expect(model.route.state, MapRouteState.SHOWN);
    model.setSavedRoutePlan(saved);
    expect(model.route.route!.points, transfer.route.points);
    model.clearDestination();
    expect(model.isOriginalRoute, false);
    expect(model.automaticReroutingEnabled, true);
  });
  test(
      'manual refresh recalculates and can recover without changing saved snapshot',
      () async {
    final transfer = RouteTransfer.fromJson(jsonDecode(
        File('test_resources/routing/route-transfer.json').readAsStringSync()));
    final provider = _Provider();
    final model = MapScreenViewModel(
        store: _Settings(),
        routingService: RoutingService(
            radlNavi: provider,
            bRouter: provider,
            radlNaviCoverage: OberbayernCoverage()));
    addTearDown(model.dispose);
    final saved = SavedRoute(
        name: transfer.name,
        start: transfer.plan.first,
        stops: transfer.plan.sublist(1, 3),
        destination: transfer.plan.last,
        snapshot: transfer);
    model.setSavedRoutePlan(saved);
    final refreshed = model.refreshRoute();
    await Future<void>.delayed(Duration.zero);
    expect(model.isOriginalRoute, false);
    expect(model.route.state, MapRouteState.LOADING);
    provider.ready.completeError(Exception('temporary failure'));
    expect(await refreshed, false);
    provider.ready = Completer<CycleRoute>();
    final retry = model.refreshRoute();
    await Future<void>.delayed(Duration.zero);
    provider.ready.complete(transfer.route);
    expect(await retry, true);
    expect(saved.snapshot, same(transfer));
    expect(model.selectedSavedRoute, same(saved));
    model.setSavedRoutePlan(saved);
    expect(model.isOriginalRoute, true);
    expect(model.route.route, same(transfer.route));
  });
  test('late lazy snapshot load cannot replace a newer selection', () async {
    final transfer = RouteTransfer.fromJson(jsonDecode(
        File('test_resources/routing/route-transfer.json').readAsStringSync()));
    final snapshots = _Snapshots();
    final model =
        MapScreenViewModel(store: _Settings(), snapshotStore: snapshots);
    addTearDown(model.dispose);
    final saved = SavedRoute(
        name: 'Saved',
        start: transfer.plan.first,
        stops: [],
        destination: transfer.plan.last,
        snapshotId: 'a' * 32);
    model.setSavedRoutePlan(saved);
    model.clearDestination();
    snapshots.ready.complete(saved.copyWith(snapshot: transfer));
    await Future<void>.delayed(Duration.zero);
    expect(model.destination, isNull);
    expect(model.isOriginalRoute, false);
  });
  test('failed snapshot loading does not strand an existing route calculation',
      () async {
    final transfer = RouteTransfer.fromJson(jsonDecode(
        File('test_resources/routing/route-transfer.json').readAsStringSync()));
    final snapshots = _Snapshots();
    final provider = _Provider();
    final model = MapScreenViewModel(
        store: _Settings(),
        snapshotStore: snapshots,
        routingService: RoutingService(
            radlNavi: provider,
            bRouter: provider,
            radlNaviCoverage: OberbayernCoverage()));
    addTearDown(model.dispose);
    model.setRoutePlan(
        start: transfer.plan.first, stops: [], destination: transfer.plan.last);
    await Future<void>.delayed(Duration.zero);
    model.setSavedRoutePlan(SavedRoute(
        name: 'Missing',
        start: transfer.plan.first,
        stops: [],
        destination: transfer.plan.last,
        snapshotId: 'a' * 32));
    snapshots.ready.completeError(const FileSystemException('missing'));
    await Future<void>.delayed(Duration.zero);
    provider.ready.complete(transfer.route);
    await Future<void>.delayed(Duration.zero);
    expect(model.route.state, MapRouteState.SHOWN);
    expect(model.route.route, transfer.route);
  });
  test('missing snapshot never silently loads a newly calculated route', () {
    final transfer = RouteTransfer.fromJson(jsonDecode(
        File('test_resources/routing/route-transfer.json').readAsStringSync()));
    final model = MapScreenViewModel(store: _Settings());
    addTearDown(model.dispose);
    final saved = SavedRoute(
        name: 'Missing',
        start: transfer.plan.first,
        stops: [],
        destination: transfer.plan.last,
        snapshotId: 'a' * 32);
    model.setSavedRoutePlan(saved);
    expect(model.destination, isNull);
  });
}
