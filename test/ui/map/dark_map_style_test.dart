import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/dark_map_style.dart';

void main() {
  test('cycling style emphasizes only paved paths and tracks', () {
    final source =
        File('assets/map/osm_openmaptiles_style.json').readAsStringSync();
    final style =
        jsonDecode(createCyclingMapStyle(source)) as Map<String, dynamic>;
    final layers = (style['layers'] as List).cast<Map<String, dynamic>>();

    final roadShield =
        layers.firstWhere((layer) => layer['id'] == 'road_shield');
    expect(roadShield['layout']['visibility'], 'none');

    final path = layers.firstWhere(
      (layer) => layer['id'] == 'road_path_pedestrian_paved_cycle',
    );
    expect(path['paint']['line-color'], '#4f98a5');
    expect(path['paint']['line-dasharray'], const [0.6, 1.4]);
    expect(path['layout']['line-cap'], 'round');
    expect(
      path['filter'],
      contains(equals(const ['==', 'surface', 'paved'])),
    );
    expect(path['filter'].toString(), contains('cycleway'));
    expect(path['filter'].toString(), contains('bicycle'));
    expect(path['filter'].toString(), contains('yes'));
    expect(path['filter'].toString(), contains('designated'));
    expect(path['paint']['line-width']['stops'].last[1], 6);

    final track = layers.firstWhere(
      (layer) => layer['id'] == 'road_service_track_paved_track',
    );
    expect(
      track['filter'],
      contains(equals(const ['==', 'surface', 'paved'])),
    );
    expect(
      track['filter'],
      contains(equals(const ['==', 'class', 'track'])),
    );
    expect(track['minzoom'], 12);
    expect(track['paint']['line-dasharray'], const [0.6, 1.4]);
    expect(track['layout']['line-cap'], 'round');
    expect(track['paint']['line-width']['stops'].first, [12, 0.8]);
    expect(track['paint']['line-width']['stops'][1], [14, 1.5]);
    expect(track['paint']['line-width']['stops'].last, [20, 6]);

    for (final id in const [
      'road_minor_minor_street',
      'tunnel_minor_minor_street',
      'bridge_street_minor_street',
    ]) {
      final minorStreet = layers.firstWhere((layer) => layer['id'] == id);
      expect(minorStreet['paint']['line-color'], '#b8d3c7');
      expect(minorStreet['filter'].toString(), contains('minor'));
      expect(minorStreet['filter'].toString(), isNot(contains('subclass')));
    }

    final motorway =
        layers.firstWhere((layer) => layer['id'] == 'road_motorway');
    expect(motorway['paint'], isNot(contains('line-opacity')));
    expect(motorway['paint']['line-width']['stops'].last[1], 18);

    final rail = layers.firstWhere((layer) => layer['id'] == 'road_major_rail');
    expect(rail['paint'], isNot(contains('line-opacity')));
    expect(rail['paint']['line-width']['stops'].last[1], 2);
  });

  test('night style keeps layers and darkens the basemap', () {
    final source =
        File('assets/map/osm_openmaptiles_style.json').readAsStringSync();
    final original = jsonDecode(source) as Map<String, dynamic>;
    final dark = jsonDecode(createDarkMapStyle(source)) as Map<String, dynamic>;

    expect(
      (dark['layers'] as List).length,
      greaterThan((original['layers'] as List).length),
    );
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

    final minorStreet = (dark['layers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((layer) => layer['id'] == 'road_minor_minor_street');
    expect(minorStreet['paint']['line-color'], '#46675c');

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
