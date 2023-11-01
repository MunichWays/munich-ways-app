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
}
