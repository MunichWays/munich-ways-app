/// Fork of Positron (https://tiles.openfreemap.org/styles/positron). MapLibre loads this via
/// a pubspec asset path (see `assets/map/openfreemap_positron_style.json`).
const String kOpenFreeMapLibertyStyleAsset =
    'assets/map/openfreemap_positron_style.json';

/// First water *name* symbol layer in OpenFreeMap Positron / OpenMapTiles-based
/// styles (`water_name_*` and `highway-name-*` stack above this). Custom line
/// layers must use `belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId` so
/// river/lake labels and street names all paint on top of route / Radl-Netz lines.
const String kOpenFreeMapBasemapOverlayBelowLayerId = 'waterway_line_label';
