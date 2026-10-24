import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/address_entrances.dart';
import 'package:munich_ways/api/nominatim_api.dart';
import 'package:munich_ways/model/place.dart';

Map<String, String> address(String number) => {
      'road': 'Schloßschmidstraße',
      'house_number': number,
      'city': 'München',
      'postcode': '80639',
    };

List<Map<String, dynamic>> results(String number, String type) => [
      {
        'category': 'building',
        'type': 'apartments',
        'name': '',
        'lat': '48.1466430',
        'lon': '11.5167847',
        'address': address(number),
        'entrances': [
          {
            'type': type,
            'lat': '48.1467013',
            'lon': '11.5169022',
            'extratags': {'addr:housenumber': number}
          }
        ],
      },
      {
        'category': 'place',
        'type': 'house',
        'name': '',
        'lat': '48.1467013',
        'lon': '11.5169022',
        'address': address(number),
        'extratags': {'entrance': type},
      }
    ];

void main() {
  for (final type in ['yes', 'home', 'main', 'shop']) {
    test(
        'entrance=$type replaces both address centroids and deduplicates fallback',
        () async {
      final api = NominatimApi(client: MockClient((req) async {
        expect(req.url.queryParameters['entrances'], '1');
        expect(req.url.queryParameters['dedupe'], '0');
        return Response(jsonEncode(results('16', type)), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      final places = await api.search('Schloßschmidstraße 16');
      expect(places, hasLength(1));
      expect(places.single.latLng, const LatLng(48.1467013, 11.5169022));
      final primary = Place('Schloßschmidstraße 16, 80639 München',
          const LatLng(48.1466430, 11.5167847),
          searchAddress: address('16'));
      final enriched =
          await api.resolveEntrances([primary], 'Schloßschmidstraße 16');
      expect(enriched.single.displayName, primary.displayName);
      expect(enriched.single.latLng, places.single.latLng);
    });
  }

  test('number 23 selects only its entrance on a multi-address building', () {
    final raw = results('23', 'yes');
    raw.first['address'] = address('19,21,23,25');
    final resolved = addressEntrances(raw, 'Schloßschmidstraße 23');
    expect(resolved.first['address']['house_number'], '23');
    expect(resolved.first['lat'], '48.1467013');
  });

  test(
      'other addresses and absent or exit-only entrances keep the primary coordinates',
      () async {
    for (final raw in [results('23', 'yes'), results('16', 'exit'), []]) {
      final api = NominatimApi(
          client: MockClient((_) async => Response(jsonEncode(raw), 200,
              headers: {'content-type': 'application/json; charset=utf-8'})));
      final primary = Place(
          'Schloßschmidstraße 16', const LatLng(48.1466430, 11.5167847),
          searchAddress: address('16'));
      expect(
          (await api.resolveEntrances([primary], 'Schloßschmidstraße 16'))
              .single,
          same(primary));
    }
  });

  test('entrance lookup can recover after a transient failure', () async {
    var calls = 0;
    final api = NominatimApi(client: MockClient((_) async {
      calls++;
      return calls == 1
          ? Response('unavailable', 503)
          : Response(jsonEncode(results('16', 'home')), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final primary = Place(
        'Schloßschmidstraße 16', const LatLng(48.1466430, 11.5167847),
        searchAddress: address('16'));
    await expectLater(api.resolveEntrances([primary], 'Schloßschmidstraße 16'),
        throwsException);
    expect(
        (await api.resolveEntrances([primary], 'Schloßschmidstraße 16'))
            .single
            .latLng,
        const LatLng(48.1467013, 11.5169022));
  });

  test(
      'streets without a requested house number do not trigger an optional lookup',
      () async {
    final api = NominatimApi(
        client:
            MockClient((_) async => throw StateError('unexpected request')));
    final street = Place('Schloßschmidstraße', const LatLng(48.146, 11.516),
        searchAddress: address('16'));
    expect(
        await api.resolveEntrances([street], 'Schloßschmidstraße'), [street]);
  });
}
