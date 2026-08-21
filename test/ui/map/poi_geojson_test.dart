import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/ui/map/poi_geojson.dart';

void main() {
  test('selects the nearest valid POI and keeps its name', () {
    final result = nearestPoiPlace(
      {
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [11.7, 48.2],
            },
            'properties': {'name': 'Weiter Brunnen'},
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [11.5005, 48.1005],
            },
            'properties': {'name': 'Naher Brunnen'},
          },
        ],
      },
      const LatLng(48.1, 11.5),
      fallbackName: 'Trinkwasserbrunnen',
    );

    expect(result?.displayName, 'Naher Brunnen');
    expect(result?.latLng, const LatLng(48.1005, 11.5005));
  });

  test('uses a fallback name and ignores malformed features', () {
    final result = nearestPoiPlace(
      {
        'features': [
          {'geometry': null},
          {
            'geometry': {
              'type': 'Point',
              'coordinates': [11.51, 48.11],
            },
            'properties': <String, dynamic>{},
          },
        ],
      },
      const LatLng(48.1, 11.5),
      fallbackName: 'Trinkwasserbrunnen',
    );

    expect(result?.displayName, 'Trinkwasserbrunnen');
  });
}
