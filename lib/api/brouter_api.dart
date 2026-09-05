import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/json_body_extension.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_provider.dart';

import '../model/route.dart';
import 'api_exception.dart';

/// Worldwide bicycle routing backed by the public BRouter HTTP service.
class BRouterApi implements RoutingProvider {
  BRouterApi({
    this.baseUrl = BRouterApi.defaultBaseUrl,
    Client? client,
  }) : _client = client ?? Client();

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
    };

    Response? response;
    var successfulProfile = profile;
    for (var attempt = 0; attempt < 2; attempt++) {
      final attemptProfile = attempt == 1 && profile != BRouterProfile.shortest
          ? BRouterProfile.shortest
          : profile;
      final uri = Uri.https(baseUrl, '/brouter', {
        ...queryParameters,
        'profile': attemptProfile.apiName,
      });
      log.d(uri.toString());
      response = await _client.get(uri, headers: const {
        'Accept': 'application/geo+json, application/json',
        'User-Agent': 'com.munichways.app/flutter',
      });
      if (response.statusCode == 200) {
        successfulProfile = attemptProfile;
        break;
      }
      if (attempt == 0 && _isTemporaryServerFailure(response)) {
        log.i(
          attemptProfile == BRouterProfile.shortest
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
      final destinationConnector = const Distance().as(
                LengthUnit.Meter,
                points.last,
                destination,
              ) >
              1
          ? [points.last, destination]
          : <LatLng>[];

      final distance = _number(properties['track-length'], 'track-length');
      final duration = successfulProfile == BRouterProfile.shortest
          ? distance / _shortestProfileCyclingSpeedMetersPerSecond
          : _number(properties['total-time'], 'total-time');

      return CycleRoute(
        points,
        distance,
        duration,
        supportsVoiceGuidance: false,
        destinationConnector: destinationConnector,
      );
    } catch (error) {
      throw ApiException('Invalid BRouter response: $error');
    }
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
