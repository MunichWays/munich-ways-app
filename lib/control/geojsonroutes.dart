import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Routes {
  Color setColor(_color) {
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

  Stream<dynamic> getJSONNetworks(networkValue) async* {
    var networkUrl = networkValue['url'];
    var collection = json.decode(await http.read(networkUrl));
    yield collection;
  }

  Stream<dynamic> getNetworks(networkKey, networkValue) async* {
    List<LatLng> polylineCoordinates = [];
    Set<Polyline> polylineCollection = {};
    List<PatternItem> POLYLINE_PATTERN_DOTTED = [];
    List<PatternItem> POLYLINE_PATTERN_DASHED = [];
    List<PatternItem> POLYLINE_PATTERN = [];
    int _width;
    POLYLINE_PATTERN_DOTTED.add(PatternItem.dot);
    POLYLINE_PATTERN_DOTTED.add(PatternItem.gap(1));
    POLYLINE_PATTERN_DASHED.add(PatternItem.dash(3));
    POLYLINE_PATTERN_DASHED.add(PatternItem.gap(5));
    int widthVorrangNetz = 5;
    int widthGesamtNetz = 7;
    if (networkKey.toString() == "vorrangnetz") {
      POLYLINE_PATTERN = POLYLINE_PATTERN_DOTTED;
      _width = widthVorrangNetz;
    } else {
      POLYLINE_PATTERN = POLYLINE_PATTERN_DASHED;
      _width = widthGesamtNetz;
    }
    await for (var i in getJSONNetworks(networkValue)) {
      var collection = i;
      int count_num = 0,
          count_num_des = 0,
          count_num_ist = 0,
          count_num_ls = 0,
          count_num_ms = 0;
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
                    LatLng.fromJson(eCoordinate).longitude,
                    LatLng.fromJson(eCoordinate).latitude));
              });
              polylineCollection.add(Polyline(
                polylineId: PolylineId(
                    feature['properties']['munichways_id'].toString()),
                points: polylineCoordinates,
                width: _width,
                color: setColor(feature['properties']['farbe'].toString()),
                patterns: POLYLINE_PATTERN,
              ));
              break;
            case "MultiLineString":
              List<dynamic> mlCoordinates = feature['geometry']['coordinates'];
              polylineCoordinates = [];
              mlCoordinates.forEach((eeCoordinate) {
                eeCoordinate.forEach((eCoordinate) {
                  polylineCoordinates.add(LatLng(
                      LatLng.fromJson(eCoordinate).longitude,
                      LatLng.fromJson(eCoordinate).latitude));
                });
              });
              polylineCollection.add(Polyline(
                polylineId: PolylineId(
                    feature['properties']['munichways_id'].toString()),
                points: polylineCoordinates,
                width: _width,
                color: setColor(feature['properties']['farbe'].toString()),
                patterns: POLYLINE_PATTERN,
              ));
              break;
          }
        });
      }
    }
    yield polylineCollection;
  }
}
