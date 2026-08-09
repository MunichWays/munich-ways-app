import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/map/network_geojson.dart';

void main() {
  test('line style follows Happy-Bike color rather than network type', () {
    MPolyline segment(String color, {required bool priorityNetwork}) =>
        MPolyline(
          points: const [LatLng(48.1, 11.5), LatLng(48.2, 11.6)],
          details: StreetDetails(
            farbe: color,
            isMunichWaysRadlVorrangNetz: priorityNetwork,
          ),
        );

    final result = buildNetworkGeoJson(
      [
        segment('grün', priorityNetwork: true),
        segment('gelb', priorityNetwork: false),
        segment('rot', priorityNetwork: true),
        segment('schwarz', priorityNetwork: false),
      ],
      (color) => color ?? '',
    );
    final features =
        result.featureCollection['features'] as List<Map<String, dynamic>>;
    final properties = features
        .map((feature) => feature['properties'] as Map<String, dynamic>)
        .toList();

    expect(properties.map((value) => value['lineDashed']), [
      false,
      false,
      true,
      true,
    ]);
    expect(properties.map((value) => value['gesamtnetz']), [
      false,
      true,
      false,
      true,
    ]);
  });
}
