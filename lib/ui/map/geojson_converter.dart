import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';

/// Converts geojson to google maps polylines
class GeojsonConverter {
  Set<MPolyline> getPolylines({required geojson}) {
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
            _addPolyline(polylines, feature, polylineCoordinates);
            break;
          case "MultiLineString":
            List<dynamic> mlCoordinates = feature['geometry']['coordinates'];
            List<LatLng> polylineCoordinates = [];
            mlCoordinates.forEach((eeCoordinate) {
              eeCoordinate.forEach((eCoordinate) {
                polylineCoordinates.add(LatLng(eCoordinate[1], eCoordinate[0]));
              });
            });
            _addPolyline(polylines, feature, polylineCoordinates);
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
  ) {
    String color = feature['properties']['farbe'].toString();
    if ('grau' == color) {
      log.d('ignore grau ${feature['properties']['munichways_id']}');
      return;
    }

    polylines.add(MPolyline(
      details: StreetDetails.fromJson(feature),
      points: coordinates,
    ));
  }
}
