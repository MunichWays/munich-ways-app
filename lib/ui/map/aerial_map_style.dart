import 'dart:convert';

import 'package:munich_ways/ui/map/vector_basemap_constants.dart';

const bavariaAerialAttribution =
    '© Datenquellen: Bayerische Vermessungsverwaltung, Europäische Union, '
    'enthält Copernicus Sentinel-2 Daten 2018, verarbeitet durch das '
    'Bundesamt für Kartographie und Geodäsie (BKG)';

/// Keeps the standard map underneath the optional imagery, including when a
/// tile is unavailable. Sources, label anchors and app overlays stay compatible.
String createAerialMapStyle(String baseStyle) {
  final style = jsonDecode(baseStyle) as Map<String, dynamic>;
  final sources = style['sources'] as Map<String, dynamic>;
  sources['bavaria-aerial'] = {
    'type': 'raster',
    'tiles': [
      'https://wmtsod1.bayernwolke.de/wmts/by_dop/smerc/{z}/{x}/{y}',
    ],
    'tileSize': 256,
    'minzoom': 0,
    'maxzoom': 19,
    // Advertised extent, not an exact state boundary. Outside it, the standard
    // map is still available and unnecessary imagery requests are avoided.
    'bounds': [
      8.945107890491915,
      47.248466288051446,
      13.90891310401004,
      50.57987000589413
    ],
    'attribution': bavariaAerialAttribution,
  };
  final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
  final anchor = layers.indexWhere(
    (layer) => layer['id'] == kOpenFreeMapBasemapOverlayBelowLayerId,
  );
  if (anchor < 0) throw const FormatException('Missing basemap overlay anchor');
  layers.insert(anchor, {
    'id': 'bavaria-aerial',
    'type': 'raster',
    'source': 'bavaria-aerial',
  });
  for (final layer in layers.skip(anchor + 1)) {
    if (layer['type'] != 'symbol') continue;
    final layout = layer['layout'] as Map<String, dynamic>?;
    if (layout?['text-field'] == null) continue;
    final paint = layer['paint'] as Map<String, dynamic>? ?? {};
    paint['text-color'] = '#ffffff';
    paint['text-halo-color'] = '#172016';
    paint['text-halo-width'] = 1.5;
    layer['paint'] = paint;
  }
  style['layers'] = layers;
  return jsonEncode(style);
}
