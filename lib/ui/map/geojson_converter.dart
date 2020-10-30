import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/street_details.dart';

abstract class OnTapListener {
  void onTap(dynamic feature);
}

/// Converts geojson to google maps polylines
class GeojsonConverter {
  Set<MPolyline> getPolylines({@required geojson}) {
    Set<MPolyline> polylines = {};
    var _features;
    if (geojson['type'].toString() == "FeatureCollection") {
      _features = geojson['features'];
      _features.forEach((feature) {
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
      log.d('ignore ${feature['properties']['munichways_id']}');
      return;
    }

    polylines.add(MPolyline(
      details: StreetDetails.fromJson(feature),
      points: coordinates,
    ));
  }
}

/// Map framework independet Polyline data class
class MPolyline {
  List<LatLng> points;
  StreetDetails details;

  MPolyline({this.points, this.details, feature});
}
