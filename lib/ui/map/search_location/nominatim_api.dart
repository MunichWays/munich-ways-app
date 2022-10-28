import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';

import '../munichways_api.dart';

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
  Future<List<Place>> search(String query) async {
    final queryParameters = {
      'q': query,
      'format': 'jsonv2',
    };
    Uri uri = Uri.https(baseUrl, 'search', queryParameters);
    Response response = await client!.get(uri, headers: {
      "Accept": "application/json",
      "User-Agent": "com.munichways.app/flutter"
    });
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
}
