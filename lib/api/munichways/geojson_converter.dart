import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';

/// Converts geojson to google maps polylines
class GeojsonConverter {
  Set<MPolyline> getPolylines({
    required geojson,
    bool happyBikeLevelFormat = false,
  }) {
    Set<MPolyline> polylines = {};
    var _features;
    if (geojson['type'].toString() == "FeatureCollection") {
      _features = geojson['features'];
      _features.forEach((feature) {
        if (feature['geometry'] == null) {
          log.d('missing geometry property: $feature');
          return;
        }
        switch (feature['geometry']['type']) {
          case "LineString":
            List<dynamic> lCoordinates = feature['geometry']['coordinates'];
            List<LatLng> polylineCoordinates = [];
            lCoordinates.forEach((eCoordinate) {
              polylineCoordinates.add(LatLng(eCoordinate[1], eCoordinate[0]));
            });
            _addPolyline(
              polylines,
              feature,
              polylineCoordinates,
              happyBikeLevelFormat,
            );
            break;
          case "MultiLineString":
            List<dynamic> mlCoordinates = feature['geometry']['coordinates'];
            List<LatLng> polylineCoordinates = [];
            mlCoordinates.forEach((eeCoordinate) {
              eeCoordinate.forEach((eCoordinate) {
                polylineCoordinates.add(LatLng(eCoordinate[1], eCoordinate[0]));
              });
            });
            _addPolyline(
              polylines,
              feature,
              polylineCoordinates,
              happyBikeLevelFormat,
            );
            break;
          default:
            log.d("unknown geometry ${feature['geometry']['type']}");
        }
      });
    }
    return polylines;
  }

  void _addPolyline(
    Set<MPolyline> polylines,
    dynamic feature,
    List<LatLng> coordinates,
    bool happyBikeLevelFormat,
  ) {
    final colorProperty = happyBikeLevelFormat ? 'color' : 'farbe';
    String color = feature['properties'][colorProperty].toString();
    if (['grau', 'blue'].contains(color)) {
      log.d('ignore grau ${feature['properties']['munichways_id']}');
      return;
    }

    polylines.add(MPolyline(
      details: happyBikeLevelFormat
          ? StreetDetails.fromHappyBikeLevelJson(feature)
          : StreetDetails.fromJson(feature),
      points: coordinates,
    ));
  }
}
