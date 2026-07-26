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
    final uri = Uri.https(baseUrl, '/brouter', {
      'lonlats': lonLats,
      'profile': profile.apiName,
      'alternativeidx': '0',
      'format': 'geojson',
    });
    log.d(uri.toString());

    final response = await _client.get(uri, headers: const {
      'Accept': 'application/geo+json, application/json',
      'User-Agent': 'com.munichways.app/flutter',
    });
    if (response.statusCode != 200) {
      throw ApiException('Error retrieving BRouter route: ${response.body}');
    }

    try {
      final json = response.jsonBody();
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

      return CycleRoute(
        points,
        _number(properties['track-length'], 'track-length'),
        _number(properties['total-time'], 'total-time'),
        supportsVoiceGuidance: false,
      );
    } catch (error) {
      throw ApiException('Invalid BRouter response: $error');
    }
  }

  double _number(Object? value, String name) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
    throw FormatException('Missing or invalid $name');
  }
}
