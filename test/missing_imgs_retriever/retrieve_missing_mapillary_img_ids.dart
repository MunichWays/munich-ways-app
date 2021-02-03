import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:latlong/latlong.dart';
import 'package:munich_ways/ui/map/geojson_converter.dart';

import '../test_utils.dart';
import 'local_properties.dart'; //you need to add this file yourself, containing a `String mapillaryClientId = <YOUR_CLIENTID>`
import 'mapillary_api.dart';

Future<void> main() async {
  // Is no test - should be transferred into a script but was to lazy to set it up, for a one time run.
  test('retrieve_missing_img_ids', () async {
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/20210117_radlvorrangnetz_masterliste_V03.geojson');
    GeojsonConverter converter = GeojsonConverter();
    var polylines = converter.getPolylines(geojson: json.decode(jsonString));
    MapillaryApi api = MapillaryApi(clientId: mapillaryClientId);

    var file = new File(
        '${DateFormat('yyyyMMdd-Hms').format(DateTime.now())}_img_ids.csv');
    var sink = file.openWrite();
    sink.writeln('cartodb_id,munichways_id,mapillary_img_id,mapillary_link');

    for (var p in polylines) {
      if (p.details.mapillaryImgId == null ||
          p.details.mapillaryImgId == 'vLk5t0YshakfGnl6q5fjUg') {
        if (p.points.isNotEmpty) {
          LatLng latLng = p.points[p.points.length ~/ 2];
          String key = await api.searchImages(latLng, radius: 10);
          sink.writeln(
              "${p.details.cartoDbId},${p.details.munichwaysId},$key,https://www.mapillary.com/map/im/$key");
        }
      }
    }

    sink.close();
  });
}
