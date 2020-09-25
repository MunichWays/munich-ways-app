import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Converts geojson to google maps polylines
class GeojsonConverter {
  static final List<PatternItem> dotted = [
    PatternItem.dot,
    PatternItem.gap(1),
  ];
  static final List<PatternItem> dashed = [
    PatternItem.dash(3),
    PatternItem.gap(5)
  ];

  Set<Polyline> getPolylines(
      {@required json, width = 5, @required List<PatternItem> pattern}) {
    List<LatLng> polylineCoordinates = [];
    Set<Polyline> polylineCollection = {};

    var collection = json;
    List<dynamic> _features;
    if (collection['type'].toString() == "FeatureCollection") {
      _features = collection['features'];
      _features.forEach((feature) {
        switch (feature['geometry']['type']) {
          case "LineString":
            List<dynamic> lCoordinates;
            lCoordinates = feature['geometry']['coordinates'];
            polylineCoordinates = [];
            lCoordinates.forEach((eCoordinate) {
              polylineCoordinates.add(LatLng(
                  LatLng
                      .fromJson(eCoordinate)
                      .longitude,
                  LatLng
                      .fromJson(eCoordinate)
                      .latitude));
            });
            polylineCollection.add(Polyline(
              polylineId:
              PolylineId(feature['properties']['munichways_id'].toString()),
              points: polylineCoordinates,
              width: width,
              color: _getColor(feature['properties']['farbe'].toString()),
              patterns: pattern,
            ));
            break;
          case "MultiLineString":
            List<dynamic> mlCoordinates = feature['geometry']['coordinates'];
            polylineCoordinates = [];
            mlCoordinates.forEach((eeCoordinate) {
              eeCoordinate.forEach((eCoordinate) {
                polylineCoordinates.add(LatLng(
                    LatLng
                        .fromJson(eCoordinate)
                        .longitude,
                    LatLng
                        .fromJson(eCoordinate)
                        .latitude));
              });
            });
            polylineCollection.add(Polyline(
              polylineId:
              PolylineId(feature['properties']['munichways_id'].toString()),
              points: polylineCoordinates,
              width: width,
              color: _getColor(feature['properties']['farbe'].toString()),
              patterns: pattern,
            ));
            break;
        }
      });
    }
    return polylineCollection;
  }

  Color _getColor(_color) {
    switch (_color) {
      case "schwarz":
        return Colors.black;
        break;
      case "grün":
        return Colors.green;
        break;
      case "gelb":
        return Colors.orange;
        break;
      case "rot":
        return Colors.red;
        break;
      default:
        return Colors.blueGrey;
    }
  }
}