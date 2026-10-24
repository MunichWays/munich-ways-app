import 'package:latlong2/latlong.dart';

class Place {
  final String? displayName;
  final LatLng latLng;
  final int? favoriteOrder;
  final List<String> alternativeNames;
  // Transient structured search data; persisted places already have resolved coordinates.
  final Map<String, String> searchAddress;

  Place(
    this.displayName,
    this.latLng, {
    this.favoriteOrder,
    this.searchAddress = const {},
    List<String> alternativeNames = const [],
  }) : alternativeNames = List.unmodifiable(alternativeNames);

  Place withFavoriteOrder(int? order) => Place(displayName, latLng,
      favoriteOrder: order, alternativeNames: alternativeNames);

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'latLng': latLng,
        if (favoriteOrder != null) 'favoriteOrder': favoriteOrder,
        if (alternativeNames.isNotEmpty) 'alternativeNames': alternativeNames,
      };

  Place.fromJson(Map<String, dynamic> json)
      : searchAddress = const {},
        displayName = json['displayName'] as String?,
        latLng = LatLng.fromJson(json['latLng']),
        favoriteOrder = json['favoriteOrder'] as int?,
        alternativeNames = List.unmodifiable(
          (json['alternativeNames'] as List? ?? const []).whereType<String>(),
        );

  @override
  String toString() {
    return 'Place{displayName: $displayName}';
  }

  @override
  bool operator ==(Object other) =>
      other is Place &&
      displayName == other.displayName &&
      latLng == other.latLng;

  @override
  int get hashCode => Object.hash(displayName, latLng);
}
