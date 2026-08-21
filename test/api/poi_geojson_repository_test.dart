import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/poi_geojson_repository.dart';

void main() {
  test('keeps complete POI properties while validating GeoJSON', () {
    final result = parsePoiFeatureCollection('''
      {
        "type": "FeatureCollection",
        "properties": {"schemaVersion": 1},
        "features": [{
          "type": "Feature",
          "geometry": {"type": "Point", "coordinates": [11.5, 48.1]},
          "properties": {
            "amenity": "drinking_water",
            "osm_id": 123,
            "wheelchair": "yes"
          }
        }]
      }
    ''');

    expect(result['properties']['schemaVersion'], 1);
    final properties = result['features'][0]['properties'];
    expect(properties['osm_id'], 123);
    expect(properties['wheelchair'], 'yes');
  });

  test('rejects data that is not a GeoJSON FeatureCollection', () {
    expect(
      () => parsePoiFeatureCollection('{"type":"Feature","features":[]}'),
      throwsFormatException,
    );
  });
}
