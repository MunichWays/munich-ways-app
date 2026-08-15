import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/dark_map_style.dart';

void main() {
  test('night style keeps layers and darkens the basemap', () {
    final source =
        File('assets/map/osm_openmaptiles_style.json').readAsStringSync();
    final original = jsonDecode(source) as Map<String, dynamic>;
    final dark = jsonDecode(createDarkMapStyle(source)) as Map<String, dynamic>;

    expect(
        (dark['layers'] as List).length, (original['layers'] as List).length);
    final background = (dark['layers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((layer) => layer['type'] == 'background');
    expect(background['paint']['background-color'], '#0b1218');

    final building3d = (dark['layers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((layer) => layer['id'] == 'building-3d');
    expect(building3d['paint']['fill-extrusion-color'], '#222d33');

    final roadShield = (dark['layers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((layer) => layer['id'] == 'road_shield');
    expect(roadShield['layout']['visibility'], 'none');

    final pedestrianArea = (dark['layers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((layer) => layer['id'] == 'road_area_pattern');
    expect(pedestrianArea['paint']['fill-color'], '#263238');
    expect(pedestrianArea['paint'], isNot(contains('fill-pattern')));

    final poiLayers = (dark['layers'] as List)
        .cast<Map<String, dynamic>>()
        .where((layer) => (layer['id'] as String).startsWith('poi_'));
    expect(poiLayers, isNotEmpty);
    for (final layer in poiLayers) {
      expect(layer['paint'], isNot(contains('icon-opacity')));
      expect(layer['paint']['text-color'], '#dce7ed');
      expect(layer['paint']['text-halo-color'], '#101820');
    }
  });
}
