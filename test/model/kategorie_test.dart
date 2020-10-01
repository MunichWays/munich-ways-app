import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/kategorie.dart';

void main() {
  test('fromString valid a-element', () {
    //GIVEN
    String kategorieString =
        '<a href="https://github.com/MunichWays/bike-infrastructure/wiki/ebener-Radweg" target="_blank"> ebener Radweg</a>';

    //WHEN
    Kategorie kategorie = Kategorie.fromString(kategorieString);

    //THEN
    expect(
        kategorie,
        Kategorie(
            title: "ebener Radweg",
            url:
                "https://github.com/MunichWays/bike-infrastructure/wiki/ebener-Radweg"));
  });

  test('fromString plain text', () {
    //GIVEN
    String kategorieString = 'Lücke schließen';

    //WHEN
    Kategorie kategorie = Kategorie.fromString(kategorieString);

    //THEN
    expect(kategorie, Kategorie(title: "Lücke schließen", url: null));
  });

  test('fromString null', () {
    //GIVEN
    String kategorieString = null;

    //WHEN
    Kategorie kategorie = Kategorie.fromString(kategorieString);

    //THEN
    expect(kategorie, isNull);
  });
}
