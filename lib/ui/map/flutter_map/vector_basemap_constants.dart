const String kOpenFreeMapLibertyStyleUrl =
    'https://tiles.openfreemap.org/styles/positron';

// Kept for compatibility with call sites; for MapLibre this can be a remote URL.
const String kOpenFreeMapLibertyStyleAsset = kOpenFreeMapLibertyStyleUrl;

/// First water *name* symbol layer in OpenFreeMap Positron / OpenMapTiles-based
/// styles (`water_name_*` and `highway-name-*` stack above this). Custom line
/// layers must use `belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId` so
/// river/lake labels and street names all paint on top of route / Radl-Netz lines.
const String kOpenFreeMapBasemapOverlayBelowLayerId = 'waterway_line_label';
