import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';
import 'package:http_interceptor/http_client_with_interceptor.dart';
import 'package:latlong/latlong.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logging_interceptor.dart';
import 'package:munich_ways/ui/map/munichways_api.dart';

import '../../lib/common/logger_setup.dart';

class MapillaryApi {
  final String clientId;
  Client _client = HttpClientWithInterceptor.build(interceptors: [
    LoggingInterceptor(),
  ]);
  final String _searchImgsUrl = "https://a.mapillary.com/v3/images";

  MapillaryApi({@required this.clientId});

  Future<String> searchImages(LatLng latLng, {int radius = 10}) async {
    var response = await _client.get(
        "$_searchImgsUrl?client_id=$clientId&closeto=${latLng.longitude},${latLng.latitude}&radius=$radius");
    switch (response.statusCode) {
      case 200:
        List<dynamic> features = response.jsonBody()['features'];
        if (features.isNotEmpty) {
          return features.first['properties']['key'];
        }
        return null;
      default:
        log.d("Failed to searchImages for $latLng - ${response.body}");
        throw ApiException(response);
    }
  }
}
