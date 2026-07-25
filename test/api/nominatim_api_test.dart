import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/nominatim_api.dart';
import 'package:munich_ways/model/place.dart';

void main() {
  test('search', () async {
    //Given
    NominatimApi api = NominatimApi(client: MockClient((req) async {
      //Then
      expect(req.url.path, "/search");
      expect(req.url.queryParameters['q'], 'Marienplatz');
      expect(req.url.queryParameters['format'], 'jsonv2');
      expect(
        req.url.queryParameters['viewbox'],
        '11.226124,48.387154,11.926124,47.887154',
      );
      expect(req.url.queryParameters['bounded'], '1');
      expect(req.url.queryParameters['limit'], '15');
      expect(req.headers['Accept'], "application/json");
      expect(req.headers['User-Agent'], "com.munichways.app/flutter");

      return Response(
          '[{"place_id":259230432,"licence":"Data © OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright","osm_type":"relation","osm_id":7366154,"boundingbox":["48.1364448","48.1376056","11.5745117","11.5771149"],"lat":"48.137031750000006","lon":"11.575924590567384","display_name":"Marienplatz, Angerviertel, Bezirksteil Angerviertel, Altstadt-Lehel, München, Bayern, 80331, Deutschland","place_rank":26,"category":"highway","type":"pedestrian","importance":0.6050818737381083}]',
          200,
          headers: {"content-type": "application/json; charset=UTF-8"});
    }));
    String query = "Marienplatz";

    //When
    List<Place> places = await api.search(query);

    //Then
    expect(places.length, 1);
    Place place = places[0];
    expect(place.displayName,
        "Marienplatz, Angerviertel, Bezirksteil Angerviertel, Altstadt-Lehel, München, Bayern, 80331, Deutschland");
    expect(place.latLng, LatLng(48.137031750000006, 11.575924590567384));
  });

  test('retries without Munich bounds when local search is empty', () async {
    var requestCount = 0;
    final api = NominatimApi(client: MockClient((request) async {
      requestCount++;
      if (requestCount == 1) {
        expect(request.url.queryParameters['bounded'], '1');
        return Response('[]', 200);
      }
      expect(request.url.queryParameters.containsKey('bounded'), isFalse);
      expect(request.url.queryParameters.containsKey('viewbox'), isFalse);
      return Response(
        '[{"display_name":"Alexanderplatz, Berlin","lat":"52.5219","lon":"13.4132"}]',
        200,
      );
    }));

    final places = await api.search('Alexanderplatz Berlin');

    expect(requestCount, 2);
    expect(places.single.displayName, 'Alexanderplatz, Berlin');
  });
}
