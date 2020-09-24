import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart';
import 'package:http_interceptor/http_client_with_interceptor.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/common/logging_interceptor.dart';
import 'package:munich_ways/ui/map/geojson_converter.dart';

class MunichwaysApi {
  final String _baseUrl = "https://www.munichways.com/App/";
  final String _radlvorrangnetzName = "radlvorrangnetz.geojson";
  final String _gesamtnetzName = "gesamtnetz.geojson";

  Client _client = HttpClientWithInterceptor.build(interceptors: [
    LoggingInterceptor(),
  ]);

  GeojsonConverter _converter = GeojsonConverter();

  Future<Set<Polyline>> getRadlvorrangnetz() async {
    return _getNetz(_radlvorrangnetzName, GeojsonConverter.DOTTED);
  }

  Future<Set<Polyline>> getGesamtnetz() async {
    return _getNetz(_gesamtnetzName, GeojsonConverter.DASHED);
  }

  Future<Set<Polyline>> _getNetz(String filename, List<PatternItem> pattern) async {
    var response = await _client.get("$_baseUrl$filename");
    switch (response.statusCode) {
      case 200:
        return _converter.getPolylines(
            json: json.decode(response.body), pattern: pattern);
      default:
        //TODO throw exception
        log.d("Failed to retrieve $filename ${response.body}");
        return null;
    }
  }
}