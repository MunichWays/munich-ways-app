import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong/latlong.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/ui/map/geojson_converter.dart';

import 'test_utils.dart';

void main() {
  test('parse', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/20200923_radlvorrangnetz.geojson');
    GeojsonConverter converter = GeojsonConverter();

    //WHEN
    Set<MPolyline> polylines = converter.getPolylines(
      geojson: json.decode(jsonString),
    );

    //THEN
    expect(polylines.length, 794);
    expect(polylines.first.points[0], LatLng(48.132019, 11.553315));
  });

  test('parse with grey lines', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/20201027_radlvorrangnetz.geojson');
    GeojsonConverter converter = GeojsonConverter();

    //WHEN
    var polylines = converter.getPolylines(
      geojson: json.decode(jsonString),
    );

    //THEN
    expect(polylines.length, 882);
  });

  test('parse gesamtnetzV2', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/20201121_gesamtnetz_V02.geojson');
    GeojsonConverter converter = GeojsonConverter();

    //WHEN
    var polylines = converter.getPolylines(
      geojson: json.decode(jsonString),
    );

    //THEN
    expect(polylines.length, 2726);
  });

  test('parse radlvorrangnetz_V03', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/20210111_radlvorrangnetz_V03.geojson');
    GeojsonConverter converter = GeojsonConverter();

    //WHEN
    var polylines = converter.getPolylines(geojson: json.decode(jsonString));

    //THEN
    expect(polylines.length, 2726);
  });
}
