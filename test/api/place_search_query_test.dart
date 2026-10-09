import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/api/place_search_query.dart';

void main() {
  test('normalizes spoken and typed association names', () {
    for (final query in [
      'GreenCity ev',
      'GreenCity e.V.',
      'GreenCity e V',
      'Green City e V',
      'Green City e.V.',
      'Green City E.V.',
    ]) {
      expect(PlaceSearchQuery.normalize(query), 'Green City e.V.');
    }
  });

  test('keeps locations, punctuation, umlauts and house numbers', () {
    expect(PlaceSearchQuery.normalize(' Marktplatz,  72070 Tübingen '),
        'Marktplatz, 72070 Tübingen');
    expect(PlaceSearchQuery.normalize('GreenCity Lindurmstr 88'),
        'Green City Lindurmstr 88');
    expect(PlaceSearchQuery.normalize('EV Charging'), 'EV Charging');
    expect(PlaceSearchQuery.normalize('Leverkusen 1-3a'), 'Leverkusen 1-3a');
  });

  test('provides only one compound-name candidate for two words', () {
    expect(PlaceSearchQuery.compoundAlternative('Zürich Horn'), 'Zürichhorn');
    for (final query in [
      'Marienplatz',
      'Am Markt',
      'New York City',
      'Straße 16',
      'Marktplatz, Tübingen',
      'Green City e.V.'
    ]) {
      expect(PlaceSearchQuery.compoundAlternative(query), isNull);
    }
  });

  test('name comparison tolerates separators without changing address numbers',
      () {
    expect(PlaceSearchQuery.nameKey('GreenCity e V'),
        PlaceSearchQuery.nameKey('Green City e.V.'));
    expect(PlaceSearchQuery.nameKey('Zürich Horn'),
        PlaceSearchQuery.nameKey('Zürichhorn'));
    expect(PlaceSearchQuery.nameKey('Straße 16'),
        isNot(PlaceSearchQuery.nameKey('Straße 61')));
  });
}
