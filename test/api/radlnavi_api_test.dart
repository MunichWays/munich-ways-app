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
      expect(req.url.path,
          "/route/v1/bike/11.578090968904041,48.142439149231784;11.588108539581299,48.14585899848997");
      expect(req.url.query,
          "alternatives=false&steps=false&annotations=false&geometries=polyline&overview=full&continue_straight=default");
      expect(req.headers['Accept'], "application/json");
      expect(req.headers['User-Agent'], "com.munichways.app/flutter");

      return Response(
          '{"code":"Ok","routes":[{"geometry":"eyydHijteAGEbC_R^G~@{FmB{@aGyBKHmASUR}CqAoAwAgBwC]cBW{DGiGMuAIB","legs":[{"steps":[],"distance":1119.2,"duration":319.4,"summary":"","weight":344.5}],"distance":1119.2,"duration":319.4,"weight_name":"cyclability","weight":344.5}],"waypoints":[{"hint":"S0cegFdHHoAOAAAARwAAAAAAAAAAAAAA4muQPw51oUAAAAAAAAAAAAkAAAAvAAAAAAAAAAAAAAAXAAAADquwAFuY3gLrqrAAZ5jeAgAAvwET0MiO","distance":2.927425,"name":"","location":[11.578126,48.142427]},{"hint":"2SgegN8oHoAVAAAAMQAAAAAAAACABwAA5KeZQK5SJkEAAAAAJwvQQw4AAAAgAAAAAAAAAOAEAAAXAAAAN9KwAMql3gIN0rAAw6XeAgAArxUT0MiO","distance":3.222205,"name":"Weidenweg","location":[11.588151,48.145866]}]}',
          200,
          headers: {"content-type": "application/json; charset=UTF-8"});
    }));

    //When
    LatLng from = LatLng(48.142439149231784, 11.578090968904041);
    LatLng to = LatLng(48.14585899848997, 11.588108539581299);
    Route actualRoute = await api.route([from, to]);

    //Then
    expect(actualRoute.points.length, 18);
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
