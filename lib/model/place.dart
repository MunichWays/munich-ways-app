import 'package:latlong2/latlong.dart';

class Place {
  final String? displayName;
  final LatLng latLng;

  Place(this.displayName, this.latLng);

  @override
  String toString() {
    return 'Place{displayName: $displayName}';
  }
}
