import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/search_location/nominatim_api.dart';

void main() {
  test('search', () async {
    //Given
    NominatimApi api = NominatimApi(client: MockClient((req) async {
      //Then
      expect(req.url.path, "/search");
      expect(req.url.query, "q=Marienplatz&format=jsonv2");
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
}
