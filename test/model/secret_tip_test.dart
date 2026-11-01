import 'package:munich_ways/model/secret_tip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/model/poi_details.dart';

void main() {
  StreetDetails parse(dynamic coordinates,
          {String type = 'LineString', String category = 'Geheimtipp'}) =>
      StreetDetails.fromV20Json({
        'properties': {'munichways_neuralgic_point': category},
        'geometry': {'type': type, 'coordinates': coordinates},
      });

  test('groups multiple OSM ways under one MunichWays ID', () {
    StreetDetails way(String mw, String osm, List coordinates) =>
        StreetDetails.fromV20Json({
          'properties': {
            'munichways_id': mw,
            'osm_id': osm,
            'munichways_neuralgic_point': 'Geheimtipp',
            'munichways_name': 'Isarblick',
            'munichways_current': 'Ist',
            'munichways_target': 'Soll',
            'osm_name': 'OSM',
            'osm_surface': 'asphalt',
            'osm_class_bicycle': '2'
          },
          'geometry': {'type': 'LineString', 'coordinates': coordinates},
        });
    final tips = groupSecretTips([
      way('MW-1', '100', [
        [11, 0],
        [11.02, 0]
      ]),
      way('MW-1', '200', [
        [11.02, 0],
        [11.1, 0]
      ]),
      way('MW-2', '300', [
        [12, 0],
        [12.1, 0]
      ]),
      way('', '400', [
        [13, 0],
        [13.1, 0]
      ]),
    ]);
    expect(tips.keys, ['MW-1', 'MW-2']);
    expect(tips['MW-1']!.location.longitude, closeTo(11.05, .00001));
    final details = tips['MW-1']!.details;
    expect(details.name, 'Isarblick');
    expect(details.munichwaysId, 'MW-1');
    expect(details.ist, 'Ist');
    expect(details.soll, 'Soll');
    expect(details.osmId, isNull);
    expect(details.osmName, isNull);
    expect(details.osmSurface, isNull);
    expect(details.osmClassBicycle, isNull);
    expect(details.happyBikeLevel, isNull);
    expect(details.farbe, isNull);
  });

  test('only Geheimtipp features become POIs', () {
    expect(parse([11, 48], type: 'Point').secretTipLocation, LatLng(48, 11));
    expect(
        parse([11, 48], type: 'Point', category: 'Gefahrenstelle')
            .secretTipLocation,
        isNull);
  });
  test('line midpoint follows length rather than vertex count', () {
    final point = parse([
      [11, 0],
      [11.01, 0],
      [11.1, 0]
    ]).secretTipLocation!;
    expect(point.longitude, closeTo(11.05, .00001));
    expect(point.latitude, closeTo(0, .00001));
  });
  test('multipart lines exclude gaps between parts', () {
    final point = parse([
      [
        [11, 0],
        [11.02, 0]
      ],
      [
        [12, 0],
        [12.06, 0]
      ]
    ], type: 'MultiLineString')
        .secretTipLocation!;
    expect(point.longitude, closeTo(12.02, .00001));
  });
  test('invalid and missing geometry cannot break details loading', () {
    expect(
        parse([
          [11, 48],
          ['broken', 48]
        ]).secretTipLocation,
        isNull);
    expect(parse([]).secretTipLocation, isNull);
    expect(parse([200, 48], type: 'Point').secretTipLocation, isNull);
    expect(
        StreetDetails.fromV20Json({
          'properties': {'munichways_neuralgic_point': 'Geheimtipp'}
        }).secretTipLocation,
        isNull);
  });
  test('secret tips retain their type and route position in POI details', () {
    final details = PoiDetails.fromGeoJsonFeature({
      'properties': {
        'amenity': 'munichways_secret_tip',
        'name': 'Isarblick',
        'description': 'Aussicht'
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [11, 48]
      },
    });
    expect(details.type, PoiType.secretTip);
    expect(details.title, 'Isarblick');
    expect(details.location, LatLng(48, 11));
    expect(details.osmUrl, isNull);
  });
}
