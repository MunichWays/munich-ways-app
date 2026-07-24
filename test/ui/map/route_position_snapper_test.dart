import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/ui/map/route_position_snapper.dart';

void main() {
  const route = [
    LatLng(48.1400, 11.5700),
    LatLng(48.1400, 11.5800),
  ];

  test('snaps a nearby GPS position to the route', () {
    const position = LatLng(48.1401, 11.5750);

    final snapped = RoutePositionSnapper.snap(
      position,
      route,
      maxDistanceMeters: 15,
    );

    expect(snapped.latitude, closeTo(48.1400, 0.000001));
    expect(snapped.longitude, closeTo(11.5750, 0.000001));
  });

  test('keeps a position that is clearly off route', () {
    const position = LatLng(48.1410, 11.5750);

    final snapped = RoutePositionSnapper.snap(
      position,
      route,
      maxDistanceMeters: 15,
    );

    expect(snapped, position);
  });

  test('snaps to a route endpoint instead of extending the segment', () {
    const position = LatLng(48.14005, 11.58005);

    final snapped = RoutePositionSnapper.snap(
      position,
      route,
      maxDistanceMeters: 15,
    );

    expect(snapped.latitude, closeTo(route.last.latitude, 0.000001));
    expect(snapped.longitude, closeTo(route.last.longitude, 0.000001));
  });
}
