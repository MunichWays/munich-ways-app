import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/place.dart';

void main() {
  test('existing saved places load without alternative names', () {
    final place = Place('Am Markt', const LatLng(48.52, 9.05));
    expect(place.toJson().containsKey('alternativeNames'), isFalse);
    final restored = Place.fromJson(jsonDecode(jsonEncode(place.toJson())));
    expect(restored, place);
    expect(restored.alternativeNames, isEmpty);
  });

  test('alternative names survive persistence and favorite reordering', () {
    final names = ['Marktplatz'];
    final place =
        Place('Am Markt', const LatLng(48.52, 9.05), alternativeNames: names);
    names.clear();
    expect(place.alternativeNames, ['Marktplatz']);
    final restored = Place.fromJson(jsonDecode(jsonEncode(place.toJson())));
    expect(restored.alternativeNames, ['Marktplatz']);
    expect(restored.withFavoriteOrder(2).alternativeNames, ['Marktplatz']);
    expect(restored.withFavoriteOrder(2).favoriteOrder, 2);
  });
}
