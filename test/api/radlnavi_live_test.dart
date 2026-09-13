// Opt-in only: flutter test --no-pub --dart-define=RADLNAVI_LIVE_TEST=true
// test/api/radlnavi_live_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/radlnavi_api.dart';

void main() {
  test('live standard and direct: two stops, maneuvers and separate comfort',
      () async {
    final client = Client();
    addTearDown(client.close);
    final api = RadlNaviApi(
        client: client,
        baseUrl: const String.fromEnvironment('RADLNAVI_BASE_URL',
            defaultValue: RadlNaviApi.RADLNAVI_URL));
    const points = [
      LatLng(48.156304, 11.540013),
      LatLng(48.102548, 11.568796),
      LatLng(48.120477, 11.655645),
      LatLng(47.991860, 11.828568)
    ];
    final report = <String, Object>{};
    for (final direct in [false, true]) {
      final watch = Stopwatch()..start();
      final route = await (direct ? api.routeDirect(points) : api.route(points))
          .timeout(const Duration(seconds: 30));
      final routeMs = watch.elapsedMilliseconds;
      expect(route.points, isNotEmpty);
      expect(route.supportsVoiceGuidance, isTrue);
      expect(route.maneuvers, isNotEmpty);
      final context = route.analysisContext!;
      expect(context.legs, hasLength(3));
      expect(context.variant, direct ? 'direct' : 'standard');
      if (direct) expect(context.baseUrl, isNot(api.baseUrl));
      watch.reset();
      final comfort = await api
          .analyzeComfort(context)
          .timeout(const Duration(seconds: 45));
      expect(comfort.coverage, inInclusiveRange(0, 100));
      report[context.variant] = {
        'route_ms': routeMs,
        'analysis_ms': watch.elapsedMilliseconds,
        'distance_m': route.distance,
        'maneuvers': route.maneuvers.length,
        'index': comfort.index,
        'coverage': comfort.coverage
      };
    }
    // A reproducible smoke measurement, not a throughput or tail-latency claim.
    print(jsonEncode(report));
  },
      skip: !const bool.fromEnvironment('RADLNAVI_LIVE_TEST'),
      timeout: const Timeout(Duration(minutes: 3)));
}
