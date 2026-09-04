import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';

import '../model/route.dart';
import 'api_exception.dart';

// routing api based on munichways weights
// see https://github.com/MunichWays/munichways-radlnavi for the routing profile
// is based on https://github.com/Project-OSRM/osrm-backend, checkout their docs for api
class RadlNaviApi implements RoutingProvider {
  Client? _client;
  final String baseUrl;

  static const String RADLNAVI_URL = "api.radlnavi.munichways.de";

  RadlNaviApi({this.baseUrl = RADLNAVI_URL, Client? client = null}) {
    if (client == null) {
      _client = Client();
    } else {
      _client = client;
    }
  }

  // https://github.com/Project-OSRM/osrm-backend/blob/master/docs/http.md#route-service
  @override
  Future<CycleRoute> route(
    List<LatLng> coordinates, {
    BRouterProfile profile = BRouterProfile.trekking,
  }) async {
    String coordinatesString = coordinates
        .map((e) => '${e.longitude.toString()},${e.latitude.toString()}')
        .join(';');

    final queryParameters = {
      'alternatives': 'false',
      'steps': 'true',
      'annotations': 'false',
      // The backend calculates this from its MunichWays ratings. Keeping the
      // calculation server-side gives web and app identical results.
      'comfort': 'true',
      // GeoJSON preserves the backend coordinates without encoded-polyline
      // rounding, which otherwise becomes visible beside rating lines at high
      // navigation zoom levels.
      'geometries': 'geojson',
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
        final firstRoute =
            (json['routes'] as List?)?.firstOrNull as Map<String, dynamic>?;
        if (firstRoute == null) {
          throw ApiException('RadlNavi response contains no route');
        }
        final points = _parseGeometry(firstRoute['geometry']);
        var distance = firstRoute['distance'] as num;
        var duration = firstRoute['duration'] as num;
        final maneuvers = <RouteManeuver>[];
        final steps = <Map<String, dynamic>>[];
        for (final leg in firstRoute['legs'] as List? ?? const []) {
          for (final rawStep in leg['steps'] as List? ?? const []) {
            final step = rawStep as Map<String, dynamic>;
            steps.add(step);
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

        final access = _splitDestinationAccess(
          points,
          steps,
          coordinates.last,
        );
        var spokenManeuvers = maneuvers;
        if (access.walkingStart != null) {
          final firstWalkingManeuver = maneuvers.indexWhere(
            (maneuver) =>
                const Distance().as(
                  LengthUnit.Meter,
                  maneuver.location,
                  access.walkingStart!,
                ) <=
                1,
          );
          if (firstWalkingManeuver >= 0) {
            spokenManeuvers = maneuvers.sublist(0, firstWalkingManeuver);
          }
        }

        return CycleRoute(
          access.route,
          distance.toDouble(),
          duration.toDouble(),
          maneuvers: spokenManeuvers,
          destinationConnector: access.connector,
          comfort: _parseComfort(firstRoute['comfort']),
        );
      default:
        throw ApiException("Error retrieving route: " + response.body);
    }
  }

  RouteComfort? _parseComfort(Object? value) {
    if (value is! Map<String, dynamic>) return null;

    final index = _percentage(value['index'], nullable: true);
    final coverage = _percentage(value['coverage']);
    final sufficientCoverage = value['sufficientCoverage'];
    final rawDistribution = value['distribution'];
    if (coverage == null ||
        sufficientCoverage is! bool ||
        rawDistribution is! Map<String, dynamic>) {
      return null;
    }

    final black = _percentage(rawDistribution['black']);
    final red = _percentage(rawDistribution['red']);
    final yellow = _percentage(rawDistribution['yellow']);
    final green = _percentage(rawDistribution['green']);
    final unrated = _percentage(rawDistribution['unrated']);
    if (black == null ||
        red == null ||
        yellow == null ||
        green == null ||
        unrated == null ||
        black + red + yellow + green + unrated != 100 ||
        (sufficientCoverage && index == null)) {
      return null;
    }

    return RouteComfort(
      index: index,
      coverage: coverage,
      sufficientCoverage: sufficientCoverage,
      distribution: RouteComfortDistribution(
        black: black,
        red: red,
        yellow: yellow,
        green: green,
        unrated: unrated,
      ),
    );
  }

  int? _percentage(Object? value, {bool nullable = false}) {
    if (nullable && value == null) return null;
    if (value is! num || !value.isFinite) return null;
    final integer = value.toInt();
    if (value.toDouble() != integer || integer < 0 || integer > 100) {
      return null;
    }
    return integer;
  }

  List<LatLng> _parseGeometry(Object? geometry) {
    if (geometry is Map<String, dynamic>) {
      final coordinates = geometry['coordinates'];
      if (geometry['type'] != 'LineString' || coordinates is! List) {
        throw ApiException('Invalid RadlNavi GeoJSON geometry');
      }
      return coordinates.map((coordinate) {
        if (coordinate is! List || coordinate.length < 2) {
          throw ApiException('Invalid RadlNavi route coordinate');
        }
        return LatLng(
          (coordinate[1] as num).toDouble(),
          (coordinate[0] as num).toDouble(),
        );
      }).toList();
    }

    // Compatibility with older RadlNavi/OSRM deployments and recorded fixtures.
    if (geometry is String) {
      return decodePolyline(geometry)
          .map((coordinate) => LatLng(
                coordinate[0].toDouble(),
                coordinate[1].toDouble(),
              ))
          .toList();
    }
    throw ApiException('Missing RadlNavi route geometry');
  }

  _DestinationAccess _splitDestinationAccess(
    List<LatLng> route,
    List<Map<String, dynamic>> steps,
    LatLng destination,
  ) {
    LatLng? walkingStart;
    for (final step in steps.reversed) {
      final maneuver = step['maneuver'] as Map<String, dynamic>? ?? const {};
      if (maneuver['type'] == 'arrive') continue;
      if (!_isUnriddenMode(step['mode'])) break;
      final location = maneuver['location'] as List?;
      if (location != null && location.length >= 2) {
        walkingStart = LatLng(
          (location[1] as num).toDouble(),
          (location[0] as num).toDouble(),
        );
      }
    }

    var splitIndex = route.length - 1;
    if (walkingStart != null && route.length > 1) {
      var nearestDistance = double.infinity;
      for (var index = route.length - 1; index >= 1; index--) {
        final candidateDistance = const Distance().as(
          LengthUnit.Meter,
          route[index],
          walkingStart,
        );
        if (candidateDistance < nearestDistance) {
          nearestDistance = candidateDistance;
          splitIndex = index;
        }
      }
    }

    final solidRoute = route.sublist(0, splitIndex + 1);
    final connector =
        walkingStart == null ? <LatLng>[] : route.sublist(splitIndex).toList();
    final connectorStart = connector.isEmpty ? route.last : connector.last;
    if (const Distance().as(
          LengthUnit.Meter,
          connectorStart,
          destination,
        ) >
        1) {
      if (connector.isEmpty) connector.add(route.last);
      connector.add(destination);
    }
    return _DestinationAccess(solidRoute, connector, walkingStart);
  }

  static bool _isUnriddenMode(Object? mode) {
    final value = mode?.toString().toLowerCase() ?? '';
    return value == 'walking' ||
        value == 'pushing bike' ||
        value == 'pushing' ||
        value == 'inaccessible';
  }
}

class _DestinationAccess {
  const _DestinationAccess(this.route, this.connector, this.walkingStart);

  final List<LatLng> route;
  final List<LatLng> connector;
  final LatLng? walkingStart;
}
