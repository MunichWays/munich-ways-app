import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/api_exception.dart';
import 'package:munich_ways/api/geoapify_api.dart';

void main() {
  test('uses Munich bounds and proximity bias', () async {
    final api = GeoapifyApi(
      apiKey: 'test-key',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/geocode/autocomplete');
        expect(request.url.queryParameters['text'], 'Marienplaz');
        expect(
          request.url.queryParameters['filter'],
          'rect:11.226124,47.887154,11.926124,48.387154',
        );
        expect(
          request.url.queryParameters['bias'],
          'proximity:11.576124,48.137154',
        );
        expect(request.url.queryParameters['apiKey'], 'test-key');

        return Response(
          '''
          {"results":[{
            "address_line1":"Marienplatz",
            "street":"Marienplatz",
            "postcode":"80331",
            "city":"München",
            "lat":48.1370317,
            "lon":11.5759245
          }]}
          ''',
          200,
          headers: {'content-type': 'application/json; charset=UTF-8'},
        );
      }),
    );

    final places = await api.search(' Marienplaz ');

    expect(places, hasLength(1));
    expect(places.single.displayName, 'Marienplatz, 80331 München');
    expect(places.single.latLng, LatLng(48.1370317, 11.5759245));
  });

  test('removes duplicates with postcode and district differences', () async {
    final api = GeoapifyApi(
      apiKey: 'test-key',
      client: MockClient((_) async {
        return Response(
          '''
          {"results":[
            {
              "name":"Rathaus",
              "address_line1":"Rathaus, Marienplatz 8",
              "street":"Marienplatz",
              "housenumber":"8",
              "postcode":"80331",
              "city":"München",
              "district":"Altstadt-Lehel",
              "lat":48.137,
              "lon":11.576
            },
            {
              "name":"Rathaus",
              "address_line1":"Rathaus, Marienplatz 8",
              "street":"Marienplatz",
              "housenumber":"8",
              "postcode":"80333",
              "city":"München",
              "district":"Angerviertel",
              "lat":48.1371,
              "lon":11.5761
            }
          ]}
          ''',
          200,
          headers: {'content-type': 'application/json; charset=UTF-8'},
        );
      }),
    );

    final places = await api.search('Rathaus');

    expect(places, hasLength(1));
    expect(
      places.single.displayName,
      'Rathaus, Marienplatz 8, 80331 München',
    );
  });

  test('fails clearly when API key is missing', () async {
    final api = GeoapifyApi(apiKey: '');

    expect(
      () => api.search('Marienplatz'),
      throwsA(isA<ApiException>()),
    );
  });

  test('retries nationwide when Munich has no results', () async {
    var requestCount = 0;
    final api = GeoapifyApi(
      apiKey: 'test-key',
      client: MockClient((request) async {
        requestCount++;
        final filter = request.url.queryParameters['filter'];
        if (requestCount == 1) {
          expect(
            filter,
            'rect:11.226124,47.887154,11.926124,48.387154',
          );
          return Response('{"results":[]}', 200);
        }
        expect(filter, 'countrycode:de');
        return Response(
          '{"results":[{"address_line1":"Alexanderplatz","postcode":"10178","city":"Berlin","lat":52.5219,"lon":13.4132}]}',
          200,
        );
      }),
    );

    final places = await api.search('Alexanderplatz Berlin');

    expect(requestCount, 2);
    expect(places.single.displayName, 'Alexanderplatz, 10178 Berlin');
  });

  test('collapses house results to a street while query has no number',
      () async {
    final api = GeoapifyApi(
      apiKey: 'test-key',
      client: MockClient((_) async => Response(
            '{"results":['
            '{"address_line1":"Erika-Mann-Straße 19","street":"Erika-Mann-Straße","housenumber":"19","postcode":"80636","city":"München","lat":48.145,"lon":11.54},'
            '{"address_line1":"Erika-Mann-Straße 47","street":"Erika-Mann-Straße","housenumber":"47","postcode":"80636","city":"München","lat":48.146,"lon":11.541}'
            ']}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );

    final places = await api.search('Erika');

    expect(places, hasLength(1));
    expect(places.single.displayName, 'Erika-Mann-Straße, 80636 München');
  });

  test('keeps concrete house results when query contains a number', () async {
    final api = GeoapifyApi(
      apiKey: 'test-key',
      client: MockClient((_) async => Response(
            '{"results":['
            '{"address_line1":"Erika-Mann-Straße","street":"Erika-Mann-Straße","postcode":"80636","city":"München","lat":48.145,"lon":11.54},'
            '{"address_line1":"Erika-Mann-Straße 47","street":"Erika-Mann-Straße","housenumber":"47","postcode":"80636","city":"München","lat":48.146,"lon":11.541}'
            ']}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );

    final places = await api.search('Erika-Mann 47');

    expect(places, hasLength(2));
    expect(places.first.displayName, 'Erika-Mann-Straße, 80636 München');
    expect(places.last.displayName, 'Erika-Mann-Straße 47, 80636 München');
  });
}
