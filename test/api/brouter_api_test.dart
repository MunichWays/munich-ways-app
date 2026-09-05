import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/api_exception.dart';
import 'package:munich_ways/api/brouter_api.dart';
import 'package:munich_ways/routing/routing_preferences.dart';

void main() {
  test('sends a BRouter request and parses its GeoJSON route', () async {
    final api = BRouterApi(client: MockClient((request) async {
      expect(request.url.path, '/brouter');
      expect(request.url.queryParameters, {
        'lonlats': '11.57,48.14|13.405,52.52',
        'profile': 'trekking',
        'alternativeidx': '0',
        'format': 'geojson',
      });
      expect(request.headers['User-Agent'], 'com.munichways.app/flutter');
      return Response(
        '{"type":"FeatureCollection","features":[{"type":"Feature",'
        '"properties":{"track-length":"1234","total-time":"456"},'
        '"geometry":{"type":"LineString","coordinates":'
        '[[11.57,48.14,520],[13.405,52.52,34]]}}]}',
        200,
      );
    }));

    final route = await api.route(const [
      LatLng(48.14, 11.57),
      LatLng(52.52, 13.405),
    ]);

    expect(route.points, hasLength(2));
    expect(route.points.last, const LatLng(52.52, 13.405));
    expect(route.distance, 1234);
    expect(route.duration, 456);
    expect(route.supportsVoiceGuidance, isFalse);
  });

  test('throws ApiException for a BRouter error', () async {
    final api = BRouterApi(
        client: MockClient(
      (_) async => Response('section not found', 400),
    ));

    expect(
      () => api.route(const [
        LatLng(48.14, 11.57),
        LatLng(52.52, 13.405),
      ]),
      throwsA(isA<ApiException>()),
    );
  });

  test('retries once when the BRouter watchdog stops a request', () async {
    var requestCount = 0;
    final api = BRouterApi(client: MockClient((request) async {
      requestCount++;
      if (requestCount == 1) {
        expect(request.url.queryParameters['profile'], 'trekking');
        return Response('killed by thread-priority-watchdog', 503);
      }
      expect(request.url.queryParameters['profile'], 'shortest');
      return Response(
        '{"features":[{"properties":{"track-length":1500,"total-time":1080},'
        '"geometry":{"coordinates":[[11.57,48.14],[12.3155,45.4408]]}}]}',
        200,
      );
    }));

    final route = await api.route(const [
      LatLng(48.14, 11.57),
      LatLng(45.4408, 12.3155),
    ]);

    expect(requestCount, 2);
    expect(route.points, hasLength(2));
    expect(route.duration, 337.5);
  });

  test('uses cycling time for the selected shortest profile', () async {
    final api = BRouterApi(client: MockClient((request) async {
      expect(request.url.queryParameters['profile'], 'shortest');
      return Response(
        '{"features":[{"properties":{"track-length":3000,"total-time":2160},'
        '"geometry":{"coordinates":[[11.57,48.14],[11.58,48.15]]}}]}',
        200,
      );
    }));

    final route = await api.route(
      const [
        LatLng(48.14, 11.57),
        LatLng(48.15, 11.58),
      ],
      profile: BRouterProfile.shortest,
    );

    expect(route.duration, 675);
  });
}
