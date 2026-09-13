import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';

/// Separate sources prevent a solid blue line from filling the dash gaps.
Map<String, dynamic> buildRouteDisplayGeoJson(CycleRoute route,
    {required bool dashed}) {
  final sections = <List<LatLng>>[
    if (route.displaySections.isEmpty && !dashed) route.points,
    for (final section in route.displaySections)
      if (section.pushing == dashed) section.points,
    if (dashed) route.destinationConnector,
  ];
  return {
    'type': 'FeatureCollection',
    'features': [
      for (final points in sections)
        if (points.length >= 2)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                for (final point in points) [point.longitude, point.latitude],
              ],
            },
          },
    ],
  };
}
