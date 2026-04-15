const String kOpenFreeMapLibertyStyleUrl =
    'https://tiles.openfreemap.org/styles/positron';

// Kept for compatibility with call sites; for MapLibre this can be a remote URL.
const String kOpenFreeMapLibertyStyleAsset = kOpenFreeMapLibertyStyleUrl;

/// First road-name symbol layer in OpenFreeMap Liberty (`highway-name-minor` /
/// `highway-name-major` stack above this). Custom line layers should use
/// `belowLayerId: kOpenFreeMapLibertyStreetNameBelowLayerId` so street labels
/// paint on top.
const String kOpenFreeMapLibertyStreetNameBelowLayerId = 'highway-name-path';
