import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/geojson_converter.dart';

import 'test_utils.dart';

void main() {
  test('parse', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/20200923_radlvorrangnetz.geojson');
    GeojsonConverter converter = GeojsonConverter();

    //WHEN
    var polylines = converter.getPolylines(
        json: json.decode(jsonString), pattern: GeojsonConverter.DASHED);

    //THEN
    expect(polylines.length, 794);
  });
}
