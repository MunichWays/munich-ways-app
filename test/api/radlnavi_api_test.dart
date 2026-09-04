import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/api_exception.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/route.dart';

void main() {
  test(
      'route params and successful response, route should send out correct request and parse response to route',
      () async {
    //Given
    RadlNaviApi api = RadlNaviApi(client: MockClient((req) async {
      //Then
      expect(req.url.scheme, "https");
      expect(req.url.host, "api.radlnavi.munichways.de");
      expect(req.url.path,
          "/route/v1/bike/11.578090968904041,48.142439149231784;11.588108539581299,48.14585899848997");
      expect(req.url.query,
          "alternatives=false&steps=true&annotations=false&comfort=true&geometries=geojson&overview=full&continue_straight=default");
      expect(req.headers['Accept'], "application/json");
      expect(req.headers['User-Agent'], "com.munichways.app/flutter");

      return Response(
          '{"code":"Ok","routes":[{"comfort":{"index":78,"coverage":82,"sufficientCoverage":true,"distribution":{"black":2,"red":7,"yellow":18,"green":68,"unrated":5}},"geometry":{"type":"LineString","coordinates":[[11.57812642,48.14242731],[11.58234567,48.14456789],[11.58815123,48.14586654]]},"legs":[{"steps":[],"distance":1119,"duration":319.4,"summary":"","weight":344.5}],"distance":1119,"duration":319.4,"weight_name":"cyclability","weight":344.5}]}',
          200,
          headers: {"content-type": "application/json; charset=UTF-8"});
    }));

    //When
    LatLng from = LatLng(48.142439149231784, 11.578090968904041);
    LatLng to = LatLng(48.14585899848997, 11.588108539581299);
    CycleRoute actualRoute = await api.route([from, to]);

    //Then
    expect(actualRoute.points.length, 3);
    expect(actualRoute.points.first.latitude, 48.14242731);
    expect(actualRoute.points.first.longitude, 11.57812642);
    expect(actualRoute.duration, 319.4);
    expect(actualRoute.distance, 1119);
    expect(actualRoute.comfort?.index, 78);
    expect(actualRoute.comfort?.coverage, 82);
    expect(actualRoute.comfort?.sufficientCoverage, isTrue);
    expect(actualRoute.comfort?.distribution.green, 68);
    expect(actualRoute.comfort?.distribution.unrated, 5);
  });

  test('parses OSRM turn-by-turn maneuvers', () async {
    final api = RadlNaviApi(client: MockClient((_) async {
      return Response(
        '{"code":"Ok","routes":[{"geometry":"_p~iF~ps|U_ulLnnqC_mqNvxq`@","legs":[{"steps":[{"distance":80,"duration":20,"name":"Testweg","maneuver":{"location":[11.57,48.14],"type":"turn","modifier":"right"}},{"distance":20,"duration":5,"name":"","maneuver":{"location":[11.571,48.141],"type":"arrive"}}]}],"distance":100,"duration":25}]}',
        200,
        headers: {"content-type": "application/json; charset=UTF-8"},
      );
    }));

    final route = await api.route(const [
      LatLng(48.14, 11.57),
      LatLng(48.141, 11.571),
    ]);

    expect(route.maneuvers, hasLength(2));
    expect(route.maneuvers.first.type, 'turn');
    expect(route.maneuvers.first.modifier, 'right');
    expect(route.maneuvers.first.roadName, 'Testweg');
    expect(route.maneuvers.last.type, 'arrive');
    expect(route.comfort, isNull);
  });

  test('ignores malformed optional comfort metadata', () async {
    final api = RadlNaviApi(client: MockClient((_) async {
      return Response(
        '{"code":"Ok","routes":[{"comfort":{"index":78,"coverage":"unknown","sufficientCoverage":true,"distribution":{}},"geometry":{"type":"LineString","coordinates":[[11.57,48.14],[11.571,48.141]]},"legs":[{"steps":[]}],"distance":100,"duration":25}]}',
        200,
        headers: {"content-type": "application/json; charset=UTF-8"},
      );
    }));

    final route = await api.route(const [
      LatLng(48.14, 11.57),
      LatLng(48.141, 11.571),
    ]);

    expect(route.distance, 100);
    expect(route.comfort, isNull);
  });

  test('separates a final walking section from the cycling route', () async {
    final api = RadlNaviApi(client: MockClient((_) async {
      return Response(
        '{"code":"Ok","routes":[{"geometry":{"type":"LineString","coordinates":[[11.5700,48.1400],[11.5710,48.1410],[11.5715,48.1415]]},"legs":[{"steps":[{"mode":"cycling","name":"Straße","maneuver":{"location":[11.5700,48.1400],"type":"depart"}},{"mode":"walking","name":"Gehweg","maneuver":{"location":[11.5710,48.1410],"type":"turn"}},{"mode":"walking","name":"","maneuver":{"location":[11.5715,48.1415],"type":"arrive"}}]}],"distance":200,"duration":60}]}',
        200,
        headers: {'content-type': 'application/json; charset=UTF-8'},
      );
    }));

    final route = await api.route(const [
      LatLng(48.1400, 11.5700),
      LatLng(48.1416, 11.5716),
    ]);

    expect(route.points, const [
      LatLng(48.1400, 11.5700),
      LatLng(48.1410, 11.5710),
    ]);
    expect(route.destinationConnector, const [
      LatLng(48.1410, 11.5710),
      LatLng(48.1415, 11.5715),
      LatLng(48.1416, 11.5716),
    ]);
    expect(route.maneuvers, hasLength(1));
    expect(route.maneuvers.single.type, 'depart');
  });

  test('response with error message, route should throw ApiException',
      () async {
    //Given
    RadlNaviApi api = RadlNaviApi(client: MockClient((req) async {
      //Then
      return Response(
          '{"message":"Number of coordinates needs to be at least two.","code":"InvalidOptions"}',
          400,
          headers: {"content-type": "application/json; charset=UTF-8"});
    }));

    //When / Then
    LatLng from = LatLng(48.142439149231784, 11.578090968904041);
    LatLng to = LatLng(48.14585899848997, 11.588108539581299);
    expect(() => api.route([from, to]), throwsA(TypeMatcher<ApiException>()));
  });
}
