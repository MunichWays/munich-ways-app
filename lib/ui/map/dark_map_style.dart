import 'dart:convert';

/// Turns the bundled bright basemap into a restrained night map while keeping
/// sources, layer ids and filters unchanged for MunichWays overlays.
String createDarkMapStyle(String source) {
  final style = jsonDecode(source) as Map<String, dynamic>;
  final layers = style['layers'] as List<dynamic>? ?? const [];
  for (final rawLayer in layers) {
    final layer = rawLayer as Map<String, dynamic>;
    if (layer['id'] == 'road_shield') {
      // The basemap road shields are car-road references (for example A8 or
      // B2), not cycling-route markers. Keep the night map less cluttered.
      final layout =
          (layer['layout'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      layout['visibility'] = 'none';
      layer['layout'] = layout;
    }
    final type = layer['type'];
    final paint = layer['paint'] as Map<String, dynamic>?;
    if (paint == null) continue;
    switch (type) {
      case 'background':
        paint['background-color'] = '#0b1218';
      case 'fill':
        paint['fill-color'] = _nightColorFor(layer['id'] as String?);
        if (layer['id'] == 'road_area_pattern') {
          // The bundled pedestrian-area pattern is almost white and would
          // otherwise cover the dark fill at high zoom levels.
          paint.remove('fill-pattern');
        }
        if (paint.containsKey('fill-outline-color')) {
          paint['fill-outline-color'] = '#344854';
        }
      case 'fill-extrusion':
        if (_isBuildingLayer(layer['id'] as String?)) {
          // At zoom 14 the flat building layer is replaced by 3D buildings.
          // Give that separate layer its own restrained night color as well.
          paint['fill-extrusion-color'] = '#222d33';
        }
      case 'line':
        paint['line-color'] = _nightLineColorFor(layer['id'] as String?);
      case 'symbol':
        if (paint.containsKey('text-color')) {
          paint['text-color'] = '#dce7ed';
          paint['text-halo-color'] = '#101820';
          paint['text-halo-width'] = 1;
        }
    }
  }
  return jsonEncode(style);
}

bool _isBuildingLayer(String? id) =>
    id?.toLowerCase().contains('building') ?? false;

String _nightColorFor(String? id) {
  final name = id?.toLowerCase() ?? '';
  if (name.contains('water')) return '#102b3a';
  if (name.contains('park') ||
      name.contains('wood') ||
      name.contains('grass')) {
    return '#142a24';
  }
  if (name.contains('building')) return '#27333a';
  if (name == 'road_area_pattern') return '#263238';
  return '#182229';
}

String _nightLineColorFor(String? id) {
  final name = id?.toLowerCase() ?? '';
  if (name.contains('water')) return '#31566a';
  if (name.contains('motorway') || name.contains('trunk')) return '#735a3a';
  if (name.contains('road') || name.contains('street')) return '#40515b';
  if (name.contains('boundary')) return '#53636c';
  return '#33444e';
}
