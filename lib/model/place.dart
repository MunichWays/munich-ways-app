import 'package:latlong2/latlong.dart';

class Place {
  final String? displayName;
  final LatLng latLng;

  Place(this.displayName, this.latLng);

  Map<String, dynamic> toJson() =>
      {'displayName': displayName, 'latLng': latLng};

  Place.fromJson(Map<String, dynamic> json)
      : displayName = json['displayName'] as String?,
        latLng = LatLng.fromJson(json['latLng']);

  @override
  String toString() {
    return 'Place{displayName: $displayName}';
  }
}
