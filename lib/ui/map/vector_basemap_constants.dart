/// [OSM Liberty / OSM OpenMapTiles](https://github.com/openmaptiles/osm-liberty-gl-style)
/// with the vector source pointed at `https://tiles.openfreemap.org/planet`
/// (OMT schema). The Positron fork remains in the assets for easy switching.
const String kOpenFreeMapLibertyStyleAsset =
    'assets/map/osm_openmaptiles_style.json';

/// First detailed basemap label above custom route and Radl-Netz overlays.
/// Keeping overlays below this layer makes house numbers and all following
/// water, road and POI labels readable over colored network lines.
const String kOpenFreeMapBasemapOverlayBelowLayerId = 'housenumber';
