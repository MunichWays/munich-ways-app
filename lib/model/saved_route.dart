import 'package:munich_ways/model/route_transfer.dart';
import 'package:munich_ways/model/place.dart';

class SavedRoute {
  const SavedRoute({
    required this.name,
    required this.start,
    required this.stops,
    required this.destination,
    this.isFavorite = false,
    this.favoriteOrder,
    this.snapshotId,
    this.snapshot,
  });

  final String name;
  final Place? start;
  final List<Place> stops;
  final Place destination;
  final bool isFavorite;
  final int? favoriteOrder;
  final String? snapshotId;
  final RouteTransfer? snapshot;

  SavedRoute copyWith({
    String? name,
    bool? isFavorite,
    int? favoriteOrder,
    bool clearFavoriteOrder = false,
    String? snapshotId,
    RouteTransfer? snapshot,
  }) =>
      SavedRoute(
        name: name ?? this.name,
        snapshotId: snapshotId ?? this.snapshotId,
        snapshot: snapshot ?? this.snapshot,
        start: start,
        stops: stops,
        destination: destination,
        isFavorite: isFavorite ?? this.isFavorite,
        favoriteOrder:
            clearFavoriteOrder ? null : favoriteOrder ?? this.favoriteOrder,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (snapshotId != null) 'snapshotId': snapshotId,
        'start': start?.toJson(),
        'stops': stops.map((place) => place.toJson()).toList(),
        'destination': destination.toJson(),
        if (isFavorite) 'isFavorite': true,
        if (favoriteOrder != null) 'favoriteOrder': favoriteOrder,
      };

  SavedRoute.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        start = json['start'] == null
            ? null
            : Place.fromJson(json['start'] as Map<String, dynamic>),
        stops = (json['stops'] as List<dynamic>)
            .map((entry) => Place.fromJson(entry as Map<String, dynamic>))
            .toList(),
        destination = Place.fromJson(
          json['destination'] as Map<String, dynamic>,
        ),
        isFavorite = json['isFavorite'] as bool? ?? false,
        favoriteOrder = json['favoriteOrder'] as int?,
        snapshotId = json['snapshotId'] as String?,
        snapshot = null;
}
