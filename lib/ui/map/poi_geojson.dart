import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/place.dart';

Place? nearestPoiPlace(
  Map<String, dynamic> featureCollection,
  LatLng origin, {
  required String fallbackName,
}) {
  final features = featureCollection['features'];
  if (features is! List) return null;
  const distance = Distance();
  Place? nearest;
  var nearestMeters = double.infinity;
  for (final rawFeature in features) {
    if (rawFeature is! Map) continue;
    final geometry = rawFeature['geometry'];
    if (geometry is! Map || geometry['type'] != 'Point') continue;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) continue;
    final longitude = coordinates[0];
    final latitude = coordinates[1];
    if (longitude is! num || latitude is! num) continue;
    final latitudeValue = latitude.toDouble();
    final longitudeValue = longitude.toDouble();
    if (!latitudeValue.isFinite ||
        !longitudeValue.isFinite ||
        latitudeValue < -90 ||
        latitudeValue > 90 ||
        longitudeValue < -180 ||
        longitudeValue > 180) {
      continue;
    }
    final location = LatLng(latitudeValue, longitudeValue);
    final meters = distance.as(LengthUnit.Meter, origin, location);
    if (meters >= nearestMeters) continue;
    final properties = rawFeature['properties'];
    final rawName = properties is Map ? properties['name'] : null;
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : fallbackName;
    nearest = Place(name, location);
    nearestMeters = meters;
  }
  return nearest;
}
