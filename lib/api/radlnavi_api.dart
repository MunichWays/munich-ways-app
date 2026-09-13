import 'dart:convert';

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
class RadlNaviApi
    implements RoutingProvider, RouteComfortProvider, DirectRoutingProvider {
  Client? _client;
  final String baseUrl;
  final String variant;
  RadlNaviApi? _directApi;
  Future<RadlNaviApi>? _directDiscovery;
  int _directConfigurationRevision = 0;

  static Uri _endpoint(String base, String path, [Map<String, String>? query]) {
    final uri = Uri.parse(base.contains('://') ? base : 'https://$base');
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ApiException('Invalid RadlNavi base URL');
    }
    final prefix = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri.replace(path: '$prefix/$path', queryParameters: query);
  }

  Future<RadlNaviApi> _discoverDirect() async {
    final response = await _client!
        .get(_endpoint(baseUrl, 'routing_variants'))
        .timeout(const Duration(seconds: 3));
    if (response.statusCode != 200)
      throw ApiException('Direct routing unavailable');
    final direct = response.jsonBody()['direct'];
    if (direct is! Map ||
        direct['available'] != true ||
        direct['base_url'] is! String) {
      throw ApiException('Direct routing unavailable');
    }
    final url = direct['base_url'] as String;
    _endpoint(
        url, 'route'); // Validate before caching, including local HTTP/port.
    return RadlNaviApi(baseUrl: url, variant: 'direct', client: _client);
  }

  // Optional metadata must never invalidate the standard route. An empty
  // header clears a previously advertised endpoint; older APIs omit it.
  void _rememberDirectEndpoint(Response response) {
    if (variant != 'standard') return;
    final url = response.headers['x-direct-api-url'];
    if (url == null) return;
    _directConfigurationRevision++;
    _directApi = null;
    _directDiscovery = null;
    try {
      if (url.trim().isEmpty) return;
      _endpoint(url, 'route');
      _directApi =
          RadlNaviApi(baseUrl: url, variant: 'direct', client: _client);
    } catch (_) {
      // Invalid optional metadata falls back to the existing discovery path.
    }
  }

  @override
  Future<CycleRoute> routeDirect(List<LatLng> coordinates) async {
    if (variant == 'direct') return route(coordinates);
    if (_directApi == null) {
      final revision = _directConfigurationRevision;
      final discovery = _directDiscovery ??= _discoverDirect();
      try {
        final discovered = await discovery;
        if (revision == _directConfigurationRevision) {
          _directApi ??= discovered;
        }
      } catch (_) {
        if (revision == _directConfigurationRevision) rethrow;
      } finally {
        // A late discovery must not overwrite or clear newer configuration.
        if (identical(_directDiscovery, discovery)) _directDiscovery = null;
      }
      if (revision != _directConfigurationRevision) {
        return routeDirect(coordinates);
      }
    }
    return _directApi!.route(coordinates);
  }

  static const String RADLNAVI_URL = "api.radlnavi.munichways.de";

  RadlNaviApi(
      {this.baseUrl = RADLNAVI_URL,
      this.variant = 'standard',
      Client? client = null}) {
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
      // Preserve the exact route for optional, subsequent comfort analysis.
      'annotations': 'nodes,distance',
      'variant': variant,
      // GeoJSON preserves the backend coordinates without encoded-polyline
      // rounding, which otherwise becomes visible beside rating lines at high
      // navigation zoom levels.
      'geometries': 'geojson',
      'overview': 'full',
      'continue_straight': 'default',
    };

    Uri uri =
        _endpoint(baseUrl, 'route/v1/bike/$coordinatesString', queryParameters);
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

        _rememberDirectEndpoint(response);
        final displaySections = _displaySections(points, steps, access.route);
        final pushingSteps =
            steps.where((step) => _isUnriddenMode(step['mode'])).length;
        log.d('Route display: variant=$variant, steps=${steps.length}, '
            'pushingSteps=$pushingSteps, sections=${displaySections.length}');
        if (displaySections.isEmpty && pushingSteps > 0) {
          log.w(
              'Pushing display unavailable: step geometry does not match route');
        }
        return CycleRoute(
          access.route,
          distance.toDouble(),
          duration.toDouble(),
          maneuvers: spokenManeuvers,
          destinationConnector: access.connector,
          displaySections: displaySections,
          comfort: _parseComfort(firstRoute['comfort']),
          analysisContext:
              _parseAnalysisContext(firstRoute['legs'], json['waypoints']),
        );
      default:
        throw ApiException("Error retrieving route: " + response.body);
    }
  }

  RouteAnalysisContext? _parseAnalysisContext(
      Object? value, Object? waypoints) {
    if (value is! List ||
        value.isEmpty ||
        waypoints is! List ||
        waypoints.length != value.length + 1) return null;
    LatLng? endpoint(Object? waypoint) {
      final location = waypoint is Map ? waypoint['location'] : null;
      if (location is! List ||
          location.length != 2 ||
          location.any((v) => v is! num || !v.isFinite) ||
          (location[0] as num).abs() > 180 ||
          (location[1] as num).abs() > 90) return null;
      return LatLng(
          (location[1] as num).toDouble(), (location[0] as num).toDouble());
    }

    final legs = <RouteAnalysisLeg>[];
    for (var i = 0; i < value.length; i++) {
      final leg = value[i];
      final annotation = leg is Map ? leg['annotation'] : null;
      final nodes = annotation is Map ? annotation['nodes'] : null;
      final distances = annotation is Map ? annotation['distance'] : null;
      final start = endpoint(waypoints[i]);
      final end = endpoint(waypoints[i + 1]);
      // Broken optional metadata must never invalidate navigation.
      if (nodes is! List ||
          nodes.length < 2 ||
          nodes.any((id) => id is! int || id <= 0) ||
          distances is! List ||
          distances.length != nodes.length - 1 ||
          distances.any((d) => d is! num || !d.isFinite || d < 0) ||
          start == null ||
          end == null) return null;
      legs.add(RouteAnalysisLeg(
          nodes: nodes.cast<int>(),
          distance: distances.map((d) => (d as num).toDouble()).toList(),
          start: start,
          end: end));
    }
    return RouteAnalysisContext(legs.map((leg) => leg.nodes).toList(),
        legs: legs, baseUrl: baseUrl, variant: variant);
  }

  @override
  Future<RouteComfort> analyzeComfort(RouteAnalysisContext context) async {
    final nodeIds = <int>[];
    for (final nodes in context.legNodeIds) {
      // Match the existing backend's route_node_ids contract. Repeated visits
      // elsewhere in the route must remain in their original order.
      nodeIds.addAll(
          nodeIds.isNotEmpty && nodes.isNotEmpty && nodeIds.last == nodes.first
              ? nodes.skip(1)
              : nodes);
    }
    if (nodeIds.isEmpty) throw ApiException('Missing route analysis nodes');
    final response = await _client!.post(
      _endpoint(context.baseUrl ?? baseUrl, 'tag_distribution'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'com.munichways.app/flutter',
      },
      body: jsonEncode(context.legs.isEmpty
          ? {'node_ids': nodeIds, 'variant': context.variant}
          : {
              'legs': context.legs.map((leg) => leg.toJson()).toList(),
              'variant': context.variant
            }),
    );
    if (response.statusCode != 200) {
      throw ApiException('Could not retrieve route comfort');
    }
    final json = response.jsonBody();
    final comfort = _parseComfort(json['comfort']);
    if (json['ok'] != true || comfort == null) {
      throw ApiException('Invalid route comfort response');
    }
    return comfort;
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

  List<RouteDisplaySection> _displaySections(
    List<LatLng> route,
    List<Map<String, dynamic>> steps,
    List<LatLng> navigableRoute,
  ) {
    // Match ordered step geometry, not nearest locations: loops and repeated
    // visits to a waypoint can have different modes on the same physical way.
    List<LatLng> withoutDuplicates(List<LatLng> points) {
      final result = <LatLng>[];
      for (final point in points) {
        if (result.isEmpty || result.last != point) result.add(point);
      }
      return result;
    }

    try {
      final points = withoutDuplicates(route);
      if (points.length < 2) return const [];
      final modes = <bool>[];
      var cursor = 0;
      for (final step in steps) {
        final maneuver = step['maneuver'] as Map<String, dynamic>?;
        if (maneuver?['type'] == 'arrive') continue;
        final geometry = withoutDuplicates(_parseGeometry(step['geometry']));
        if (geometry.isEmpty || geometry.first != points[cursor]) {
          return const [];
        }
        for (final point in geometry.skip(1)) {
          cursor++;
          if (cursor >= points.length || point != points[cursor]) {
            return const [];
          }
          modes.add(_isUnriddenMode(step['mode']));
        }
      }
      if (cursor != points.length - 1) return const [];
      // Final walking access is already rendered by destinationConnector.
      final limit = withoutDuplicates(navigableRoute).length - 1;
      final sections = <RouteDisplaySection>[];
      var first = 0;
      for (var edge = 0; edge < limit; edge++) {
        if (edge == limit - 1 || modes[edge] != modes[edge + 1]) {
          sections.add(RouteDisplaySection(points.sublist(first, edge + 2),
              pushing: modes[edge]));
          first = edge + 1;
        }
      }
      return List.unmodifiable(sections);
    } catch (_) {
      // Incomplete optional geometry must not break a usable navigation route.
      return const [];
    }
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
