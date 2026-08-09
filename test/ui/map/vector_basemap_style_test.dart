import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/vector_basemap_constants.dart';

void main() {
  test('Liberty basemap shows house numbers at address-selection zooms', () {
    final style = jsonDecode(
      File('assets/map/osm_openmaptiles_style.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final layers = style['layers'] as List<dynamic>;
    final houseNumberLayer = layers.cast<Map<String, dynamic>>().singleWhere(
          (layer) => layer['id'] == 'housenumber',
        );

    expect(houseNumberLayer['type'], 'symbol');
    expect(houseNumberLayer['source-layer'], 'housenumber');
    expect(houseNumberLayer['minzoom'], lessThanOrEqualTo(17));
    expect(
      (houseNumberLayer['layout'] as Map<String, dynamic>)['text-field'],
      '{housenumber}',
    );
    expect(kOpenFreeMapBasemapOverlayBelowLayerId, 'housenumber');
  });
}
