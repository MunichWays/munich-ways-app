import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/street_details.dart';

void main() {
  test('maps V20 current-state, planning and link fields', () {
    final details = StreetDetails.fromV20Json({
      'properties': {
        'osm_id': 123,
        'osm_name': 'OSM-Name',
        'osm_class_bicycle': '2',
        'osm_smoothness': 'good',
        'osm_surface': 'asphalt',
        'osm_bicycle': 'designated',
        'osm_highway': 'cycleway',
        'osm_lit': 'yes',
        'osm_width': '2.5',
        'osm_access': 'yes',
        'munichways_id': 'LHM456',
        'munichways_name': 'MunichWays-Name',
        'munichways_current': 'Breiter Radweg',
        'munichways_target': 'Verbreiterung',
        'munichways_description': 'Beschreibung',
        'munichways_status_implementation': 'offen',
        'munichways_net_type_plan': 'Planungsnetz',
        'munichways_net_type_target': 'Zielnetz',
        'munichways_mw_rv_route': 'Premium',
        'munichways_route_link':
            '<a href="https://example.org/route">Strecke</a>',
        'munichways_measure_category_link':
            '<a href="https://example.org/measure">Kategorie</a>',
        'munichways_district_link':
            '<a href="https://example.org/district">Bezirk</a>',
        'munichways_links':
            '<a href="https://example.org/more">Weiterlesen</a>',
        'munichways_mapillary_link': 'https://www.mapillary.com/app/?pKey=789',
        'color': 'green',
      },
    });

    expect(details.osmId, '123');
    expect(details.osmName, 'OSM-Name');
    expect(details.munichwaysName, 'MunichWays-Name');
    expect(details.osmClassBicycle, '2');
    expect(details.happyBikeLevel, 'gemütlich');
    expect(details.farbe, 'grün');
    expect(details.mwRvRoute, 'Premium');
    expect(details.routeLinks!.single.url, 'https://example.org/route');
    expect(details.measureCategoryLinks!.single.title, 'Kategorie');
    expect(details.districtLinks!.single.title, 'Bezirk');
    expect(details.links!.single.title, 'Weiterlesen');
    expect(
      details.mapillaryLinks,
      ['https://www.mapillary.com/app/?pKey=789'],
    );
  });

  test('OSM class:bicycle overrides a differing exported rating color', () {
    final details = StreetDetails.fromV20Json({
      'properties': {
        'osm_class_bicycle': '-2',
        'munichways_color': 'red',
        'munichways_happy_bike_level': '-1',
        'color': 'red',
      },
    });

    expect(details.osmClassBicycle, '-2');
    expect(details.happyBikeLevel, 'sehr stressig');
    expect(details.farbe, 'schwarz');
  });

  test('OSM id takes precedence when several ways share a MunichWays id', () {
    final first = StreetDetails(
      osmId: '622091744',
      munichwaysId: 'LHM-Mitte.BA02_10147_MRR02|- |RV02S',
    );
    final second = StreetDetails(
      osmId: '999999999',
      munichwaysId: 'LHM-Mitte.BA02_10147_MRR02|- |RV02S',
    );

    expect(streetDetailsFeatureId(first), 'osm_622091744');
    expect(streetDetailsFeatureId(second), 'osm_999999999');
  });

  test('MunichWays id remains the fallback without an OSM mapping', () {
    final details = StreetDetails(munichwaysId: 'LHM-without-OSM');

    expect(streetDetailsFeatureId(details), 'LHM-without-OSM');
  });
}
