import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/links.dart';

void main() {
  test('LinksParser parse', () {
    //GIVEN
    String linksString =
        '<p><a href=\"https://docs.google.com/document/d/14HlSPaYCMvT2v00sMvJYW4j0Hbq8jHdvr9bl2sZTlbk/edit?usp=sharing\" target=\"_blank\">  RadlVorrangProfil</a></p>\n<p>_____ </p><br> </br>\n<p><a href=\"https://docs.google.com/document/d/11cXxckedsvTK9OPncjArQdBjZ_gmi_mKEtMENqmjYkE/edit?usp=sharing\" target=\"_blank\">  Maßnahmenkatalog </a> </p>\n<p><a href=\"https://www.ris-muenchen.de/RII/RII/DOK/ANTRAG/5645187.pdf\" target=\"_blank\">  RIS Antrag SPD 19.09.2019 </a> </p>\n<p>_____ </p><br> </br>';

    //WHEN
    List<Link> links = LinksParser.parse(linksString);

    //THEN
    expect(links, [
      Link("RadlVorrangProfil",
          "https://docs.google.com/document/d/14HlSPaYCMvT2v00sMvJYW4j0Hbq8jHdvr9bl2sZTlbk/edit?usp=sharing"),
      Link("Maßnahmenkatalog",
          "https://docs.google.com/document/d/11cXxckedsvTK9OPncjArQdBjZ_gmi_mKEtMENqmjYkE/edit?usp=sharing"),
      Link("RIS Antrag SPD 19.09.2019",
          "https://www.ris-muenchen.de/RII/RII/DOK/ANTRAG/5645187.pdf"),
    ]);
  });

  test('LinksParser parse null', () {
    //GIVEN
    String? linksString;

    //WHEN
    List<Link> links = LinksParser.parse(linksString);

    //THEN
    expect(links, isEmpty);
  });

  test('LinksParser parse no html', () {
    //GIVEN
    String linksString = 'some text which is not html and contains no a tag';

    //WHEN
    List<Link> links = LinksParser.parse(linksString);

    //THEN
    expect(links, isEmpty);
  });
}
