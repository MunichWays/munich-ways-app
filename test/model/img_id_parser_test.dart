import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/ImgIdParser.dart';

void main() {
  test('parse valid img id', () {
    //GIVEN
    String mapillaryImgId = "765852851681051";

    //WHEN
    String? imgId = ImgIdParser().parse(mapillaryImgId, null, null);

    //THEN
    expect(imgId, "765852851681051");
  });

  test('parse valid link', () {
    //GIVEN
    String link = "https://www.mapillary.com/app/?pKey=765852851681051";

    //WHEN
    String? imgId = ImgIdParser().parse(null, link, null);

    //THEN
    expect(imgId, "765852851681051");
  });

  test('parse link is null', () {
    //GIVEN
    String? link;

    //WHEN
    String? imgId = ImgIdParser().parse(null, link, null);

    //THEN
    expect(imgId, null);
  });

  test('parse invalid link', () {
    //GIVEN
    String link =
        '<a href="https://www.mapillary.com/app/?pKey=765852851681051"">test</a>';

    //WHEN
    String? imgId = ImgIdParser().parse(null, link, null);

    //THEN
    expect(imgId, null);
  });

  test('parse invalid link and valid strassenansicht', () {
    //GIVEN
    String? link;
    String strassenansicht =
        '<a href="https://www.mapillary.com/app/?pKey=765852851681051" target="_blank"> <img src="https://www.munichways.de/img/Offen_Odeonsplatz.jpg" width=175></a>';

    //WHEN
    String? imgId = ImgIdParser().parse(null, link, strassenansicht);

    //THEN
    expect(imgId, '765852851681051');
  });
}
