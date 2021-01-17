import 'package:http/http.dart';
import 'package:http_interceptor/http_client_with_interceptor.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/common/logging_interceptor.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/ui/map/geojson_converter.dart';

class MunichwaysApi {
  final String _gesamtnetzV2Url =
      "https://www.munichways.com/App/radlvorrangnetz_masterliste_V03.geojson";

  Client _client = HttpClientWithInterceptor.build(interceptors: [
    LoggingInterceptor(),
  ]);

  GeojsonConverter _converter = GeojsonConverter();

  Future<Set<MPolyline>> getGesamtnetz() async {
    var response = await _client.get(_gesamtnetzV2Url);
    switch (response.statusCode) {
      case 200:
        return _converter.getPolylines(geojson: response.jsonBody());
      default:
        log.d("Failed to retrieve $_gesamtnetzV2Url ${response.body}");
        throw ApiException(response);
    }
  }
}

class ApiException implements Exception {
  final Response response;

  ApiException(this.response);
}
