import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/bezirk.dart';
import 'package:munich_ways/model/links.dart';

void main() {
  test('fromProps valid link', () {
    //GIVEN
    String link =
        '<a href="https://www.munichways.com/bezirksausschuesse/#toggle-id-2" target="_blank">BA 02 Ludwigsvorstadt-Isarvorstadt</a>';

    //WHEN
    Bezirk bezirk = Bezirk.fromProps(
        name: "Ludwigsvorstadt-Isarvorstadt",
        nummer: "BA02",
        link: link,
        region: "LK-M");

    //THEN
    expect(
        bezirk,
        Bezirk(
            name: "Ludwigsvorstadt-Isarvorstadt",
            nummer: "BA02",
            link: Link("BA 02 Ludwigsvorstadt-Isarvorstadt",
                "https://www.munichways.com/bezirksausschuesse/#toggle-id-2"),
            region: "LK-M"));
  });

  test('fromProps invalid link', () {
    //GIVEN
    String link = 'Pullach';

    //WHEN
    Bezirk bezirk = Bezirk.fromProps(
        name: "Ludwigsvorstadt-Isarvorstadt",
        nummer: "BA02",
        link: link,
        region: "LK-M");

    //THEN
    expect(
        bezirk,
        Bezirk(
            name: "Ludwigsvorstadt-Isarvorstadt",
            nummer: "BA02",
            link: Link("BA02 Ludwigsvorstadt-Isarvorstadt",
                "https://www.munichways.com/bezirksausschuesse/"),
            region: "LK-M"));
  });

  test('fromProps link is null', () {
    //GIVEN
    String link = null;

    //WHEN
    Bezirk bezirk = Bezirk.fromProps(
        name: "Ludwigsvorstadt-Isarvorstadt",
        nummer: "BA02",
        link: link,
        region: "LK-M");

    //THEN
    expect(
        bezirk,
        Bezirk(
            name: "Ludwigsvorstadt-Isarvorstadt",
            nummer: "BA02",
            link: Link("BA02 Ludwigsvorstadt-Isarvorstadt",
                "https://www.munichways.com/bezirksausschuesse/"),
            region: "LK-M"));
  });
}
