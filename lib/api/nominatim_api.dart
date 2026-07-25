import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';

import 'api_exception.dart';

class NominatimApi {
  Client? client;
  final String baseUrl;

  static const String NOMINATIM_PROXY_URL = "nominatim.svendroid.net";

  NominatimApi({this.baseUrl = NOMINATIM_PROXY_URL, this.client}) {
    if (client == null) {
      client = Client();
    }
  }

  // https://nominatim.org/release-docs/latest/api/Search/
  Future<List<Place>> search(String query, {LatLng? searchCenter}) async {
    final center = searchCenter ?? const LatLng(48.137154, 11.576124);
    final localPlaces = await _request(
      query,
      localOnly: true,
      center: center,
    );
    if (localPlaces.isNotEmpty) {
      return localPlaces;
    }
    return _request(query, localOnly: false, center: center);
  }

  Future<List<Place>> _request(
    String query, {
    required bool localOnly,
    required LatLng center,
  }) async {
    final queryParameters = {
      'q': query,
      'format': 'jsonv2',
      'limit': '15',
      if (localOnly) ...{
        'viewbox': _viewBox(center),
        'bounded': '1',
      },
    };
    Uri uri = Uri.https(baseUrl, 'search', queryParameters);
    Response response = await client!.get(uri, headers: {
      "Accept": "application/json",
      "User-Agent": "com.munichways.app/flutter"
    }).timeout(const Duration(seconds: 8));
    switch (response.statusCode) {
      case 200:
        log.d(response.body);
        log.d(response.jsonBody());
        List jsonList = response.jsonBody() as List;
        var list = jsonList.map((json) {
          return Place(json['display_name'],
              LatLng(double.parse(json['lat']), double.parse(json['lon'])));
        }).toList();
        return list;
      default:
        throw ApiException("Error retrieving places: " + response.body);
    }
  }

  static String _viewBox(LatLng center) =>
      '${center.longitude - 0.35},${center.latitude + 0.25},'
      '${center.longitude + 0.35},${center.latitude - 0.25}';
}
