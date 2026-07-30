import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/munichways/geojson_converter.dart';

import 'test_utils.dart';

void main() {
  test('parse radlvorrangnetz_masterliste_V03', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/20210117_radlvorrangnetz_masterliste_V03.geojson');
    GeojsonConverter converter = GeojsonConverter();

    //WHEN
    var polylines = converter.getPolylines(geojson: json.decode(jsonString));

    //THEN
    expect(polylines.length, 3037);
  });

  test('parse radlvorrangnetz_app_V03', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/20210124_radlvorrangnetz_app_V03.geojson');
    GeojsonConverter converter = GeojsonConverter();

    //WHEN
    var polylines = converter.getPolylines(geojson: json.decode(jsonString));

    //THEN
    expect(polylines.length, 3106);
  });

  test('parse radlvorrangnetz_app_V04', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/20210413_radlvorrangnetz_app_V04.geojson');
    GeojsonConverter converter = GeojsonConverter();

    //WHEN
    var polylines = converter.getPolylines(geojson: json.decode(jsonString));

    //THEN
    expect(polylines.length, 3332);
  });

  test('parses lightweight Munich ratings and ignores blue features', () {
    final geojson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {
            'munichways_id': 'LHM123',
            'osm_id': null,
            'color': 'green',
            'munichways_mw_rv_route': 'Premium',
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [11.5, 48.1],
              [11.6, 48.2],
            ],
          },
        },
        {
          'type': 'Feature',
          'properties': {
            'munichways_id': '',
            'osm_id': 456,
            'color': 'blue',
            'munichways_mw_rv_route': '-',
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [11.6, 48.2],
              [11.7, 48.3],
            ],
          },
        },
      ],
    };

    final polylines = GeojsonConverter().getPolylines(
      geojson: geojson,
      happyBikeLevelFormat: true,
    );

    expect(polylines, hasLength(1));
    final details = polylines.single.details!;
    expect(details.munichwaysId, 'LHM123');
    expect(details.farbe, 'grün');
    expect(details.isMunichWaysRadlVorrangNetz, isTrue);
  });
}
