import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/route_transfer.dart';
import 'package:munich_ways/api/saved_routes_store.dart';
import 'package:munich_ways/model/saved_route.dart';

Map<String, dynamic> fixture() => jsonDecode(
        File('test_resources/routing/route-transfer.json').readAsStringSync())
    as Map<String, dynamic>;
void main() {
  test(
      'real Komoot tour retains eight named stops through storage and GPX export',
      () {
    final transfer = RouteTransfer.fromGpx(
        File('test_resources/routing/komoot-discovery.gpx').readAsStringSync());
    expect(transfer.plan.length, 10);
    expect(transfer.plan[1].displayName, 'Amsterdamer Straße (Geheimtipp)');
    expect(transfer.plan[2].displayName, 'Schwabinger See');
    expect(transfer.plan[8].displayName, 'Nymphenburger Kanal');
    expect(transfer.route.supportsVoiceGuidance, false);
    final stored = RouteTransfer.fromStorageJson(transfer.toStorageJson());
    final exported = RouteTransfer.fromGpx(stored.toGpx());
    expect(exported.plan.map((p) => p.displayName),
        transfer.plan.map((p) => p.displayName));
    expect(
        exported.plan.map((p) => p.latLng), transfer.plan.map((p) => p.latLng));
    expect(exported.route.points, transfer.route.points);
    expect(exported.name, transfer.name);
  });
  test(
      'standard waypoints preserve order, escape names and reject invalid data',
      () {
    const prefix =
        '<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1">';
    const track =
        '<trk><trkseg><trkpt lat="48" lon="11"/><trkpt lat="49" lon="12"/></trkseg></trk></gpx>';
    const waypoint = '<wpt lat="48.5" lon="11.5"><name>A &amp; B</name></wpt>';
    final transfer = RouteTransfer.fromGpx('$prefix$waypoint$track');
    expect(
        RouteTransfer.fromGpx(transfer.toGpx()).plan[1].displayName, 'A & B');
    expect(
        () => RouteTransfer.fromGpx(
            '$prefix${waypoint.replaceFirst('48.5', 'NaN')}$track'),
        throwsFormatException);
    expect(
        () => RouteTransfer.fromGpx(
            '$prefix${List.filled(21, waypoint).join()}$track'),
        throwsFormatException);
    final old = RouteTransfer.fromStorageJson(
        transfer.toStorageJson()..remove('trackPlan'));
    expect(old.plan.length, 2);
  });
  test('GPX filenames retain names while rejecting filesystem syntax', () {
    expect(RouteTransfer.gpxFilename('GreenCity-über-Hackerbrücke'),
        'GreenCity-über-Hackerbrücke.gpx');
    expect(RouteTransfer.gpxFilename('Tour.gpx'), 'Tour.gpx');
    expect(RouteTransfer.gpxFilename('../Tour: A/B?'), '.._Tour_ A_B_.gpx');
    expect(RouteTransfer.gpxFilename('NUL'), 'MunichWays-Route.gpx');
  });
  test('shared web fixture roundtrips geometry, all legs, names and maneuvers',
      () {
    final transfer = RouteTransfer.fromJson(fixture());
    final restored = RouteTransfer.fromGpx(transfer.toGpx());
    expect(restored.name, 'Isar & Brücke – Testroute');
    expect(restored.plan.length, 4);
    expect(restored.route.points, transfer.route.points);
    expect(restored.route.maneuvers.length, 6);
    expect(restored.native, transfer.native);
  });
  test('same geometry with changed navigation path is rejected', () {
    final data = fixture();
    data['response']['routes'][0]['legs'][1]['steps'][0]['geometry']
        ['coordinates'][0] = [11.7, 48.2];
    expect(() => RouteTransfer.fromJson(data), throwsFormatException);
  });
  test('imports the actual GPX produced by the web exporter', () {
    final transfer = RouteTransfer.fromGpx(
        File('test_resources/routing/route-transfer.gpx').readAsStringSync());
    expect(transfer.plan.length, 4);
    expect(transfer.route.maneuvers.length, 6);
    expect(transfer.route.points.length, 4);
  });
  test('damaged native snapshot cannot silently become a track', () {
    final transfer = RouteTransfer.fromJson(fixture());
    expect(
        () => RouteTransfer.fromGpx(
            transfer.toGpx().replaceFirst('lat="48.15"', 'lat="49.15"')),
        throwsFormatException);
    final data = fixture()..['version'] = 2;
    expect(() => RouteTransfer.fromJson(data), throwsFormatException);
    data['version'] = 1;
    data['response']['routes'][0]['legs'][1]['steps'] = [];
    expect(() => RouteTransfer.fromJson(data), throwsFormatException);
  });
  test('foreign track stays map-only; disconnections and entities are rejected',
      () {
    const xml =
        '<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1"><trk><name>Track</name><trkseg><trkpt lat="48" lon="11"/><trkpt lat="48.1" lon="11.1"/></trkseg></trk></gpx>';
    final transfer = RouteTransfer.fromGpx(xml);
    expect(transfer.route.supportsVoiceGuidance, false);
    expect(transfer.route.distance, greaterThan(0));
    expect(RouteTransfer.fromStorageJson(transfer.toStorageJson()).route.points,
        transfer.route.points);
    expect(
        () => RouteTransfer.fromGpx(
            xml.replaceFirst('</trk>', '<trkseg/></trk>')),
        throwsFormatException);
    expect(() => RouteTransfer.fromGpx('<!DOCTYPE gpx>$xml'),
        throwsFormatException);
  });
  test(
      'snapshots survive restart; same name imports do not overwrite, old plans remain readable',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('munichways-gpx-test');
    addTearDown(() => directory.delete(recursive: true));
    final store = SavedRoutesStore(directory: directory);
    final transfer = RouteTransfer.fromJson(fixture());
    final original = SavedRoute(
        name: 'Tour',
        start: transfer.plan.first,
        stops: transfer.plan.sublist(1, 3),
        destination: transfer.plan.last);
    await store.add(original);
    await store.addImported(original.copyWith(snapshot: transfer));
    await store.addImported(original.copyWith(snapshot: transfer));
    final loaded = await SavedRoutesStore(directory: directory).load();
    expect(loaded.length, 3);
    expect((await store.loadSnapshot(loaded.first)).snapshot!.route.points,
        transfer.route.points);
    expect(loaded.last.snapshot, isNull);
    await store.add(loaded.first.copyWith(name: 'Renamed'));
    expect((await store.load()).length, 3);
    expect((await store.load()).first.snapshotId, loaded.first.snapshotId);
    final id = loaded.first.snapshotId!;
    await File('${directory.path}/route-snapshots/$id.json').delete();
    expect((await store.load()).first.snapshotId, id);
    expect((await store.load()).first.snapshot, isNull);
    await expectLater(store.loadSnapshot((await store.load()).first),
        throwsA(isA<FileSystemException>()));
    await store.store([loaded.last]);
    expect(
        await Directory('${directory.path}/route-snapshots').list().length, 0);
  });
}
