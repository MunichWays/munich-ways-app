import 'dart:convert';

/// Rebalances the general basemap around cycling-relevant infrastructure.
String createCyclingMapStyle(String source) {
  final style = jsonDecode(source) as Map<String, dynamic>;
  final layers = style['layers'] as List<dynamic>? ?? const [];
  final cyclingLayers = <dynamic>[];
  for (final rawLayer in layers) {
    final layer = rawLayer as Map<String, dynamic>;
    final id = (layer['id'] as String? ?? '').toLowerCase();
    if (id == 'road_shield') {
      final layout =
          (layer['layout'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      layout['visibility'] = 'none';
      layer['layout'] = layout;
    }
    cyclingLayers.add(layer);
    if (id.contains('path_pedestrian')) {
      cyclingLayers.add(
        _pavedHighlightLayer(
          layer,
          idSuffix: 'paved_cycle',
          extraFilter: const [
            'any',
            ['==', 'subclass', 'cycleway'],
            [
              'all',
              ['in', 'subclass', 'footway', 'path', 'pedestrian'],
              ['==', 'bicycle', 'yes'],
            ],
          ],
          widthFactor: 1.35,
        ),
      );
    } else if (id.endsWith('service_track')) {
      final pavedTrack = _pavedHighlightLayer(
        layer,
        idSuffix: 'paved_track',
        extraFilter: const ['==', 'class', 'track'],
        widthFactor: 1.25,
      );
      // The original service/track curve has width 0 up to zoom 15.5.
      // Asphalt tracks are useful regional cycling links and should become
      // visible as soon as the vector tiles contain them.
      pavedTrack['minzoom'] = 12;
      (pavedTrack['paint'] as Map<String, dynamic>)['line-width'] = {
        'base': 1.2,
        'stops': const [
          [12, 0.8],
          [14, 2],
          [16, 3.5],
          [20, 10],
        ],
      };
      cyclingLayers.add(pavedTrack);
    }
  }
  style['layers'] = cyclingLayers;
  return jsonEncode(style);
}

Map<String, dynamic> _pavedHighlightLayer(
  Map<String, dynamic> source, {
  required String idSuffix,
  required List<dynamic> extraFilter,
  required double widthFactor,
}) {
  final layer = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  layer['id'] = '${source['id']}_$idSuffix';
  final filter = (layer['filter'] as List<dynamic>?) ?? <dynamic>['all'];
  layer['filter'] = [
    ...filter,
    const ['==', 'surface', 'paved'],
    extraFilter,
  ];
  final paint = layer['paint'] as Map<String, dynamic>;
  paint['line-color'] = '#4f98a5';
  paint['line-opacity'] = 1;
  paint['line-width'] = _scaleWidth(paint['line-width'], widthFactor);
  return layer;
}

/// Turns the bundled bright basemap into a restrained night map while keeping
/// sources, layer ids and filters unchanged for MunichWays overlays.
String createDarkMapStyle(String source) {
  final style =
      jsonDecode(createCyclingMapStyle(source)) as Map<String, dynamic>;
  final layers = style['layers'] as List<dynamic>? ?? const [];
  for (final rawLayer in layers) {
    final layer = rawLayer as Map<String, dynamic>;
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

dynamic _scaleWidth(dynamic value, double factor) {
  if (value is num) return value * factor;
  if (value is! Map<String, dynamic>) return value;
  final result = Map<String, dynamic>.of(value);
  final stops = result['stops'];
  if (stops is List) {
    result['stops'] = [
      for (final rawStop in stops)
        if (rawStop is List && rawStop.length >= 2 && rawStop[1] is num)
          [rawStop[0], (rawStop[1] as num) * factor]
        else
          rawStop,
    ];
  }
  return result;
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
  if (name.contains('paved_cycle') || name.contains('paved_track')) {
    return '#5fabb5';
  }
  if (name.contains('path_pedestrian')) return '#40515b';
  if (name.contains('rail')) return '#53636c';
  if (name.contains('motorway') || name.contains('trunk')) return '#735a3a';
  if (name.contains('road') || name.contains('street')) return '#40515b';
  if (name.contains('boundary')) return '#53636c';
  return '#33444e';
}
