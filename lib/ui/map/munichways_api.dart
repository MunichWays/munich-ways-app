import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart';
import 'package:http_interceptor/http_client_with_interceptor.dart';
import 'package:munich_ways/common/json_body_extension.dart';
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

  Future<Set<Polyline>> getRadlvorrangnetz(OnTapListener onTapListener) async {
    return _getNetz(_radlvorrangnetzName, GeojsonConverter.dotted, onTapListener);
  }

  Future<Set<Polyline>> getGesamtnetz(OnTapListener onTapListener) async {
    return _getNetz(_gesamtnetzName, GeojsonConverter.dashed, onTapListener);
  }

  Future<Set<Polyline>> _getNetz(String filename, List<PatternItem> pattern, OnTapListener onTapListener) async {
    var response = await _client.get("$_baseUrl$filename");
    switch (response.statusCode) {
      case 200:
        return _converter.getPolylines(
            geojson: response.jsonBody(), pattern: pattern, onTapListener: onTapListener);
      default:
        //TODO throw exception
        log.d("Failed to retrieve $filename ${response.body}");
        return null;
    }
  }
}