import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/ui/theme.dart';

abstract class OnTapListener {
  void onTap(dynamic feature);
}

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
      {@required geojson,
      width = 5,
      @required List<PatternItem> pattern,
      @required OnTapListener onTapListener}) {
    Set<Polyline> polylineCollection = {};
    var _features;
    if (geojson['type'].toString() == "FeatureCollection") {
      _features = geojson['features'];
      _features.forEach((feature) {
        switch (feature['geometry']['type']) {
          case "LineString":
            List<dynamic> lCoordinates = feature['geometry']['coordinates'];
            List<LatLng> polylineCoordinates = [];
            lCoordinates.forEach((eCoordinate) {
              polylineCoordinates.add(LatLng(
                  LatLng.fromJson(eCoordinate).longitude,
                  LatLng.fromJson(eCoordinate).latitude));
            });
            polylineCollection.add(_createPolyline(
                feature, polylineCoordinates, width, pattern, onTapListener));
            break;
          case "MultiLineString":
            List<dynamic> mlCoordinates = feature['geometry']['coordinates'];
            List<LatLng> polylineCoordinates = [];
            mlCoordinates.forEach((eeCoordinate) {
              eeCoordinate.forEach((eCoordinate) {
                polylineCoordinates.add(LatLng(
                    LatLng.fromJson(eCoordinate).longitude,
                    LatLng.fromJson(eCoordinate).latitude));
              });
            });
            polylineCollection.add(_createPolyline(
                feature, polylineCoordinates, width, pattern, onTapListener));
            break;
          default:
            log.d("unknown geometry ${feature['geometry']['type']}");
        }
      });
    }
    return polylineCollection;
  }

  Polyline _createPolyline(dynamic feature, List<LatLng> coordinates, int width,
      List<PatternItem> pattern, OnTapListener onTap) {
    return Polyline(
      polylineId: PolylineId(feature['properties']['munichways_id'].toString()),
      points: coordinates,
      width: width,
      color:
          AppColors.getPolylineColor(feature['properties']['farbe'].toString()),
      patterns: pattern,
      onTap: () {
        log.d("onTap Polyline $feature");
        onTap.onTap(feature);
      },
      consumeTapEvents: true,
    );
  }
}
