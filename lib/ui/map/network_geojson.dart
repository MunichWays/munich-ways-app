import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';

/// Result of building the radl / gesamtnetz GeoJSON for MapLibre.
class NetworkGeoJsonResult {
  NetworkGeoJsonResult({
    required this.featureCollection,
    required this.detailsByFeatureId,
  });

  /// RFC 7946 FeatureCollection map (suitable for [MapLibreMapController.setGeoJsonSource]).
  final Map<String, dynamic> featureCollection;

  /// Maps GeoJSON feature id → details for tap handling.
  final Map<String, StreetDetails> detailsByFeatureId;
}

/// Stable id for a polyline feature (used as GeoJSON Feature `id`).
String networkFeatureId(MPolyline polyline) {
  final detailsId = streetDetailsFeatureId(polyline.details);
  if (detailsId != null) return detailsId;
  final c = polyline.details?.cartoDbId;
  if (c != null) return 'carto_$c';
  final pts = polyline.points;
  if (pts != null && pts.isNotEmpty) {
    final a = pts.first;
    final b = pts.last;
    return 'geom_${a.latitude}_${a.longitude}_${b.latitude}_${b.longitude}_${pts.length}';
  }
  return 'feature_${polyline.hashCode}';
}

/// Builds one FeatureCollection with per-feature `lineColor` in properties.
NetworkGeoJsonResult buildNetworkGeoJson(
  List<MPolyline> polylines,
  String Function(String? farbe) lineColorHex,
) {
  final detailsByFeatureId = <String, StreetDetails>{};
  final features = <Map<String, dynamic>>[];

  for (final polyline in polylines) {
    final details = polyline.details;
    final pts = polyline.points;
    if (details == null || pts == null || pts.isEmpty) continue;

    final fid = networkFeatureId(polyline);
    detailsByFeatureId[fid] = details;

    features.add({
      'type': 'Feature',
      'id': fid,
      'properties': {
        'lineColor': lineColorHex(details.farbe),
        'lineDashed': details.farbe == 'rot' || details.farbe == 'schwarz',
        'gesamtnetz': polyline.isGesamtnetz,
      },
      'geometry': {
        'type': 'LineString',
        'coordinates': pts.map((p) => [p.longitude, p.latitude]).toList(),
      },
    });
  }

  return NetworkGeoJsonResult(
    featureCollection: {
      'type': 'FeatureCollection',
      'features': features,
    },
    detailsByFeatureId: detailsByFeatureId,
  );
}
