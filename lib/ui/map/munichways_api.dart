import 'package:http/http.dart';
import 'package:http_interceptor/http_client_with_interceptor.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/common/logging_interceptor.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/ui/map/geojson_converter.dart';

class MunichwaysApi {
  final String _baseUrl = "https://www.munichways.com/App/";
  final String _radlvorrangnetzName = "radlvorrangnetz.geojson";
  final String _gesamtnetzName = "gesamtnetz.geojson";

  Client _client = HttpClientWithInterceptor.build(interceptors: [
    LoggingInterceptor(),
  ]);

  GeojsonConverter _converter = GeojsonConverter();

  Future<Set<MPolyline>> getRadlvorrangnetz() async {
    return _getNetz(_radlvorrangnetzName);
  }

  Future<Set<MPolyline>> getGesamtnetz() async {
    return _getNetz(_gesamtnetzName);
  }

  Future<Set<MPolyline>> _getNetz(String filename) async {
    var response = await _client.get("$_baseUrl$filename");
    switch (response.statusCode) {
      case 200:
        return _converter.getPolylines(geojson: response.jsonBody());
      default:
        log.d("Failed to retrieve $filename ${response.body}");
        throw ApiException(response);
    }
  }
}

class ApiException implements Exception {
  final Response response;

  ApiException(this.response);
}
