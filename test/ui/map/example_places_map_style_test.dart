import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/example_places_map_style.dart';
import 'package:munich_ways/ui/map/vector_basemap_constants.dart';

void main() {
  test('offline example markers never request remote font glyphs', () {
    for (final dark in [false, true]) {
      final properties =
          ExamplePlacesMapStyle(dark: dark).markers('example-icon').toJson();
      expect(properties['icon-image'], 'example-icon');
      expect(properties['icon-allow-overlap'], isTrue);
      expect(properties.keys.where((key) => key.startsWith('text-')), isEmpty,
          reason:
              'Native MapLibre waits for glyphs for the whole symbol layer, '
              'including icons. A missing font must not hide the local marker.');
    }
  });

  test('example names use a font stack already used by the active basemap', () {
    final basemap = jsonDecode(
      File(kOpenFreeMapLibertyStyleAsset).readAsStringSync(),
    );
    final fonts = (basemap['layers'] as List)
        .map((layer) => (layer['layout'] as Map?)?['text-font'])
        .whereType<List>();
    for (final dark in [false, true]) {
      final properties = ExamplePlacesMapStyle(dark: dark).labels.toJson();
      expect(properties['text-field'], ['get', 'name']);
      expect(fonts, contains(equals(properties['text-font'])),
          reason: 'An implicit native default can request a font stack that '
              'the active glyph server does not serve.');
      expect(properties.containsKey('icon-image'), isFalse);
    }
  });
}
