import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';

import '../model/route.dart';
import 'api_exception.dart';

typedef _IndexedManeuver = ({int index, RouteManeuver maneuver});

/// Worldwide bicycle routing backed by the public BRouter HTTP service.
class BRouterApi implements RoutingProvider {
  BRouterApi({this.baseUrl = BRouterApi.defaultBaseUrl, Client? client})
      : _client = client ?? Client();

  static const String defaultBaseUrl = 'brouter.de';

  // BRouter's shortest profile is a foot profile and therefore reports its
  // total-time at walking speed. Use a conservative bicycle speed for the
  // duration shown by the app while keeping the shortest route geometry.
  static const double _shortestProfileCyclingSpeedMetersPerSecond = 16 / 3.6;

  final Client _client;
  final String baseUrl;

  @override
  Future<CycleRoute> route(
    List<LatLng> coordinates, {
    BRouterProfile profile = BRouterProfile.trekking,
  }) async {
    if (coordinates.length < 2) {
      throw ApiException('BRouter requires at least two coordinates.');
    }

    final lonLats = coordinates
        .map((point) => '${point.longitude},${point.latitude}')
        .join('|');
    final queryParameters = {
      'lonlats': lonLats,
      'profile': profile.apiName,
      'alternativeidx': '0',
      'format': 'geojson',
      // Explicit Locus-style command codes in GeoJSON properties.voicehints.
      'timode': '2',
    };

    Response? response;
    var successfulProfile = profile;
    for (var attempt = 0; attempt < 2; attempt++) {
      // Keep Fastbike on retry so the Direct fallback does not become shortest.
      final attemptProfile = attempt == 1 && profile == BRouterProfile.trekking
          ? BRouterProfile.shortest
          : profile;
      final uri = Uri.https(baseUrl, '/brouter', {
        ...queryParameters,
        'profile': attemptProfile.apiName,
      });
      log.d(uri.toString());
      response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/geo+json, application/json',
          'User-Agent': 'com.munichways.app/flutter',
        },
      );
      if (response.statusCode == 200) {
        successfulProfile = attemptProfile;
        break;
      }
      if (attempt == 0 && _isTemporaryServerFailure(response)) {
        log.i(
          profile != BRouterProfile.trekking
              ? 'BRouter is temporarily overloaded; retrying route calculation'
              : 'BRouter watchdog stopped the selected profile; '
                  'retrying with shortest',
        );
        await Future<void>.delayed(const Duration(milliseconds: 750));
        continue;
      }
      if (_isTemporaryServerFailure(response)) {
        throw ApiException(
          'BRouter ist momentan ausgelastet. '
          'Bitte versuche die Route in Kürze erneut.',
        );
      }
      throw ApiException('Error retrieving BRouter route: ${response.body}');
    }

    try {
      final json = response!.jsonBody();
      final feature = (json['features'] as List).first as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final properties =
          feature['properties'] as Map<String, dynamic>? ?? const {};
      final points = (geometry['coordinates'] as List).map((raw) {
        final coordinate = raw as List;
        return LatLng(
          (coordinate[1] as num).toDouble(),
          (coordinate[0] as num).toDouble(),
        );
      }).toList(growable: false);
      final destination = coordinates.last;
      final destinationConnector =
          const Distance().as(LengthUnit.Meter, points.last, destination) > 1
              ? [points.last, destination]
              : <LatLng>[];

      final distance = _number(properties['track-length'], 'track-length');
      final duration = successfulProfile == BRouterProfile.shortest
          ? distance / _shortestProfileCyclingSpeedMetersPerSecond
          : _number(properties['total-time'], 'total-time');

      final hints = _parseVoiceHints(properties['voicehints'], points);
      final maneuvers = hints == null || hints.isEmpty
          ? null
          : _withStopArrivals(hints, points, coordinates);
      final supportsVoiceGuidance = maneuvers != null && maneuvers.isNotEmpty;

      return CycleRoute(
        points,
        distance,
        duration,
        maneuvers: supportsVoiceGuidance ? maneuvers : const [],
        supportsVoiceGuidance: supportsVoiceGuidance,
        destinationConnector: destinationConnector,
      );
    } catch (error) {
      throw ApiException('Invalid BRouter response: $error');
    }
  }

  /// Unknown or malformed guidance must not discard otherwise usable geometry.
  /// Disable the whole hint set rather than silently omit a required maneuver.
  List<_IndexedManeuver>? _parseVoiceHints(Object? raw, List<LatLng> points) {
    if (raw == null) return const [];
    if (raw is! List) return null;
    final result = <_IndexedManeuver>[];
    var previousIndex = -1;
    for (final hint in raw) {
      if (hint is! List || hint.length < 5) return null;
      final index = hint[0];
      final command = hint[1];
      final exit = hint[2];
      if (index is! int ||
          command is! int ||
          exit is! int ||
          index <= previousIndex ||
          index >= points.length) return null;
      previousIndex = index;
      final instruction = switch (command) {
        1 => ('continue', 'straight'),
        2 => ('turn', 'left'),
        3 => ('turn', 'slight left'),
        4 => ('turn', 'sharp left'),
        5 => ('turn', 'right'),
        6 => ('turn', 'slight right'),
        7 => ('turn', 'sharp right'),
        8 => ('fork', 'slight left'),
        9 => ('fork', 'slight right'),
        10 || 11 || 15 => ('turn', 'uturn'),
        13 || 14 => ('roundabout', 'straight'),
        17 => ('off ramp', 'left'),
        18 => ('off ramp', 'right'),
        _ => null,
      };
      if (instruction == null) return null;
      final roundabout = command == 13 || command == 14;
      if (roundabout && exit == 0) return null;
      result.add(
        (
          index: index,
          maneuver: RouteManeuver(
            location: points[index],
            type: instruction.$1,
            modifier: instruction.$2,
            exit: roundabout ? exit.abs() : null,
          ),
        ),
      );
    }
    return result;
  }

  /// BRouter joins legs into one geometry and offsets the hint indices, but
  /// GeoJSON does not expose leg boundaries. Match each requested stop only
  /// when its nearest vertex is close, ordered and unambiguous. Keep the
  /// original stop location for the same arrival radius as other providers.
  List<RouteManeuver>? _withStopArrivals(
    List<_IndexedManeuver> hints,
    List<LatLng> points,
    List<LatLng> coordinates,
  ) {
    if (coordinates.length == 2) {
      return hints.map((hint) => hint.maneuver).toList(growable: false);
    }
    final indexed = [...hints];
    var previousIndex = 0;
    for (final stop in coordinates.skip(1).take(coordinates.length - 2)) {
      final distances = [
        for (final point in points)
          const Distance(roundResult: false).as(LengthUnit.Meter, point, stop),
      ];
      var nearest = 0;
      for (var index = 1; index < points.length; index++) {
        if (distances[index] < distances[nearest]) nearest = index;
      }
      // A stop further than the arrival radius may never be announced.
      if (distances[nearest] > 20 ||
          nearest <= previousIndex ||
          nearest == points.length - 1) return null;
      for (var index = 0; index < points.length; index++) {
        // Adjacent vertices can represent the same local snapped position.
        // A similarly close position elsewhere could be a different visit.
        if ((index - nearest).abs() > 1 &&
            distances[index] <= distances[nearest] + 1) return null;
      }
      indexed.add((
        index: nearest,
        maneuver: RouteManeuver(location: stop, type: 'arrive'),
      ));
      previousIndex = nearest;
    }
    // Include final arrival explicitly, also for consumers without stop names.
    indexed.add((
      index: points.length - 1,
      maneuver: RouteManeuver(location: coordinates.last, type: 'arrive'),
    ));
    indexed.sort((a, b) {
      final order = a.index.compareTo(b.index);
      if (order != 0) return order;
      return a.maneuver.type == 'arrive' ? -1 : 1;
    });
    return indexed.map((hint) => hint.maneuver).toList(growable: false);
  }

  bool _isTemporaryServerFailure(Response response) {
    final body = response.body.toLowerCase();
    return response.statusCode == 429 ||
        response.statusCode >= 500 ||
        body.contains('thread-priority-watchdog');
  }

  double _number(Object? value, String name) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
    throw FormatException('Missing or invalid $name');
  }
}
