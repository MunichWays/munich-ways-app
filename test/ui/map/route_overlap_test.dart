import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/ui/map/route_overlap.dart';

void main() {
  test('builds one continuous feature for an outbound and return overlap', () {
    const start = LatLng(48.14, 11.57);
    const middle = LatLng(48.14, 11.571);
    const turn = LatLng(48.14, 11.572);
    final geoJson = buildRouteOverlapGeoJson(
      const [start, middle, turn, middle, start],
    );

    final features = geoJson['features'] as List;
    expect(features, hasLength(1));
    expect(
      features.single['geometry']['coordinates'],
      [
        [start.longitude, start.latitude],
        [middle.longitude, middle.latitude],
        [turn.longitude, turn.latitude],
      ],
    );
  });

  test('does not mark a route without repeated segments', () {
    final geoJson = buildRouteOverlapGeoJson(
      const [
        LatLng(48.14, 11.57),
        LatLng(48.141, 11.571),
        LatLng(48.142, 11.572),
      ],
    );

    expect(geoJson['features'], isEmpty);
  });
}
