import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/poi_geojson_repository.dart';
import 'package:munich_ways/model/example_places.dart';
import 'package:munich_ways/model/poi_details.dart';
import 'dart:convert';

void main() {
  test('bundled map POIs match the seeded routing destinations', () {
    final places = initialExamplePlaces();
    expect(places.map((place) => place.displayName),
        ['Green City e.V.', 'Unlock Escape']);
    final collection =
        parsePoiFeatureCollection(jsonEncode(examplePlacesGeoJson()));
    final features = collection['features'] as List;
    expect(features.length, places.length);
    for (var i = 0; i < places.length; i++) {
      final details = PoiDetails.fromGeoJsonFeature(features[i]);
      expect(details.title, places[i].displayName);
      expect(details.location, places[i].latLng);
      expect(details.type, PoiType.place);
      expect(details.tags['address'], exampleDestinations[i].address);
      expect(details.osmUrl,
          'https://www.openstreetmap.org/node/${exampleDestinations[i].osmId}');
    }
  });
}
