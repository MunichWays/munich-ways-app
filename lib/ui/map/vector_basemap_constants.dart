/// [OSM Liberty / OSM OpenMapTiles](https://github.com/openmaptiles/osm-liberty-gl-style)
/// with the vector source pointed at `https://tiles.openfreemap.org/planet` (OMT
/// schema). The former `water_name_line` label layer is renamed to
/// `waterway_line_label` so the overlay anchor matches
/// [kOpenFreeMapBasemapOverlayBelowLayerId]. The Positron fork remains at
/// `assets/map/openfreemap_positron_style.json` for easy switching.
const String kOpenFreeMapLibertyStyleAsset =
    'assets/map/osm_openmaptiles_style.json';

/// OpenMapTiles waterway *line* label symbol layer (`water_name_line` in
/// unmodified OSM Liberty, renamed in our asset to match Positron’s id). Custom
/// line layers must use `belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId` so
/// other water/road labels paint on top of route / Radl-Netz lines.
const String kOpenFreeMapBasemapOverlayBelowLayerId = 'waterway_line_label';
