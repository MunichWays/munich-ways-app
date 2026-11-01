import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/secret_tip_geometry.dart';
import 'package:munich_ways/model/street_details.dart';

class SecretTip {
  const SecretTip(this.details, this.location);
  final StreetDetails details;
  final LatLng location;
}

/// Group separately from the OSM-keyed street lookup used by network taps.
Map<String, SecretTip> groupSecretTips(Iterable<StreetDetails> streets) {
  final groups = <String, List<StreetDetails>>{};
  for (final street in streets) {
    final id = street.munichwaysId?.trim();
    if (id == null ||
        id.isEmpty ||
        id == '-' ||
        street.secretTipLocation == null) continue;
    groups.putIfAbsent(id, () => []).add(street);
  }
  return {
    for (final entry in groups.entries)
      entry.key: SecretTip(
          entry.value.first.secretTipDetails, _groupLocation(entry.value)),
  };
}

LatLng _groupLocation(List<StreetDetails> streets) {
  final lines = <dynamic>[];
  for (final street in streets) {
    final geometry = street.secretTipGeometry;
    if (geometry?['type'] == 'LineString') {
      lines.add(geometry!['coordinates']);
    } else if (geometry?['type'] == 'MultiLineString') {
      lines.addAll(geometry!['coordinates'] as List);
    }
  }
  return secretTipLocationFromGeometry(
          {'type': 'MultiLineString', 'coordinates': lines}) ??
      streets.first.secretTipLocation!;
}
