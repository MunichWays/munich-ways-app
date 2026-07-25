import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logger_setup.dart';

import '../model/route.dart';
import 'api_exception.dart';

// routing api based on munichways weights
// see https://github.com/MunichWays/radlnavi for munichways routing profile
// is based on https://github.com/Project-OSRM/osrm-backend, checkout their docs for api
class RadlNaviApi {
  Client? _client;
  final String baseUrl;

  static const String RADLNAVI_URL = "routing.floschnell.de";

  RadlNaviApi({this.baseUrl = RADLNAVI_URL, Client? client = null}) {
    if (client == null) {
      _client = Client();
    } else {
      _client = client;
    }
  }

  // https://github.com/Project-OSRM/osrm-backend/blob/master/docs/http.md#route-service
  Future<CycleRoute> route(List<LatLng> coordinates) async {
    String coordinatesString = coordinates
        .map((e) => '${e.longitude.toString()},${e.latitude.toString()}')
        .join(';');

    final queryParameters = {
      'alternatives': 'false',
      'steps': 'true',
      'annotations': 'false',
      'geometries': 'polyline',
      'overview': 'full',
      'continue_straight': 'default',
    };

    Uri uri =
        Uri.https(baseUrl, 'route/v1/bike/$coordinatesString', queryParameters);
    log.d(uri.toString());

    Response response = await _client!.get(uri, headers: {
      "Accept": "application/json",
      "User-Agent": "com.munichways.app/flutter"
    });
    switch (response.statusCode) {
      case 200:
        var json = response.jsonBody();
        var firstRoute = (json['routes'] as List).firstOrNull;
        var polyline = decodePolyline(firstRoute['geometry']);
        var distance = firstRoute['distance'] as num;
        var duration = firstRoute['duration'] as num;
        final maneuvers = <RouteManeuver>[];
        for (final leg in firstRoute['legs'] as List? ?? const []) {
          for (final rawStep in leg['steps'] as List? ?? const []) {
            final step = rawStep as Map<String, dynamic>;
            final maneuver =
                step['maneuver'] as Map<String, dynamic>? ?? const {};
            final location = maneuver['location'] as List?;
            if (location == null || location.length < 2) continue;
            maneuvers.add(RouteManeuver(
              location: LatLng(
                (location[1] as num).toDouble(),
                (location[0] as num).toDouble(),
              ),
              type: maneuver['type'] as String? ?? 'turn',
              modifier: maneuver['modifier'] as String?,
              roadName: step['name'] as String? ?? '',
              exit: (maneuver['exit'] as num?)?.toInt(),
            ));
          }
        }

        return CycleRoute(
            polyline
                .map((e) => LatLng(e[0].toDouble(), e[1].toDouble()))
                .toList(),
            distance.toDouble(),
            duration.toDouble(),
            maneuvers: maneuvers);
      default:
        throw ApiException("Error retrieving route: " + response.body);
    }
  }
}
