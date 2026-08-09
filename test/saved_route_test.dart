import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';

void main() {
  test('saved route JSON keeps start, stops, destination, and name', () {
    final route = SavedRoute(
      name: 'Isar-Runde',
      start: Place('Start', const LatLng(48.1, 11.5)),
      stops: [
        Place('Biergarten', const LatLng(48.2, 11.6)),
        Place('Brücke', const LatLng(48.3, 11.7)),
      ],
      destination: Place('Ziel', const LatLng(48.4, 11.8)),
    );

    final json = jsonDecode(jsonEncode(route.toJson())) as Map<String, dynamic>;
    final restored = SavedRoute.fromJson(json);

    expect(restored.name, 'Isar-Runde');
    expect(restored.start?.displayName, 'Start');
    expect(restored.stops.map((place) => place.displayName), [
      'Biergarten',
      'Brücke',
    ]);
    expect(restored.destination.displayName, 'Ziel');
    expect(restored.destination.latLng, const LatLng(48.4, 11.8));
  });

  test('saved route JSON keeps favorite state and order', () {
    final route = SavedRoute(
      name: 'Arbeitsweg',
      start: null,
      stops: [Place('Lieblingsweg', const LatLng(48.2, 11.6))],
      destination: Place('Arbeit', const LatLng(48.3, 11.7)),
      isFavorite: true,
      favoriteOrder: 1,
    );

    final json = jsonDecode(jsonEncode(route.toJson())) as Map<String, dynamic>;
    final restored = SavedRoute.fromJson(json);
    expect(restored.isFavorite, isTrue);
    expect(restored.favoriteOrder, 1);
  });
}
