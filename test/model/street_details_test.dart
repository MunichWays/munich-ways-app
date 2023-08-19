import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/bezirk.dart';
import 'package:munich_ways/model/kategorie.dart';
import 'package:munich_ways/model/links.dart';
import 'package:munich_ways/model/street_details.dart';

import '../test_utils.dart';

void main() {
  test('fromJson masterliste', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/feature_masterliste_V03.json');
    var json = jsonDecode(jsonString);

    //WHEN
    StreetDetails details = StreetDetails.fromJson(json);

    //THEN
    expect(
        details,
        StreetDetails(
            cartoDbId: 1161,
            streetview:
                "<a href=\"https://www.mapillary.com/app/?pKey=233947365199559\" target=\"_blank\">\n<img src=\"https://www.munichways.com/img/Theresienwiese_175.jpg\" width=175></a>",
            name:
                "Theresienwiese-Lücke-Beethovenstr.-Mattias-Pschorr-Str./Mozartstr.",
            strecke: "RV3S - Fürstenrieder-Radlroute",
            ist:
                "grober Schotterweg von ca. 100 Metern. fehlende Ost-West Verbindung",
            happyBikeLevel: "sehr stressig",
            soll: "Fahrbahn erneuern",
            massnahmenKategorie: "ebener Radweg",
            description:
                "neuralgischer Punkt - Neue Radverkehrsroute Sendlinger-Tor-Platz zum Harras",
            munichwaysId: "RV03S.01.000-01.100",
            statusUmsetzung: "beantragt",
            bezirk: Bezirk(
                region: "LHM-Mitte",
                nummer: "BA02",
                name: "Ludwigsvorstadt-Isarvorstadt",
                link: Link(
                    title: "BA02 Ludwigsvorstadt-Isarvorstadt",
                    url: "https://www.munichways.com/bezirksausschuesse/")),
            links: [
              Link(
                  title: "RadlVorrang-Profil",
                  url:
                      "https://docs.google.com/document/d/14HlSPaYCMvT2v00sMvJYW4j0Hbq8jHdvr9bl2sZTlbk/edit?usp=sharing"),
              Link(
                  title: "Maßnahmenkatalog",
                  url:
                      "https://docs.google.com/document/d/11cXxckedsvTK9OPncjArQdBjZ_gmi_mKEtMENqmjYkE/edit?usp=sharing"),
              Link(
                  title: "RIS Antrag SPD 12.09.2019",
                  url:
                      "https://www.ris-muenchen.de/RII/RII/DOK/ANTRAG/5645187.pdf"),
              Link(
                  title: "RIS Beschluss zur Prüfung 09.12.2020",
                  url:
                      "https://www.ris-muenchen.de/RII/RII/DOK/SITZUNGSVORLAGE/6348847.pdf")
            ],
            netztyp: "1_RadlVorrang-Strecke",
            planNetztypId: 1,
            farbe: "schwarz",
            rsvStrecke: "-",
            alternative: "-",
            vielKfz: false,
            mapillaryImgId: "233947365199559",
            kategorie: Kategorie(
                title: "ebener Radweg",
                url:
                    'https://github.com/MunichWays/bike-infrastructure/wiki/ebener-Radweg'),
            prioGesamt: 0.93,
            neuralgischerPunkt: "Neuralgischer Punkt",
            netztypId: 1,
            kategorieId: 9,
            statusId: 3,
            lastUpdated: DateTime.utc(2021, 1, 11, 20, 28, 37)));
  });

  test('fromJson app', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/feature_app_V03.json');
    var json = jsonDecode(jsonString);

    //WHEN
    StreetDetails details = StreetDetails.fromJson(json);

    //THEN
    expect(
        details,
        StreetDetails(
            cartoDbId: 1161,
            name:
                "Theresienwiese-Lücke-Beethovenstr.-Mattias-Pschorr-Str./Mozartstr.",
            strecke: "RV3S - Fürstenrieder-Radlroute",
            ist:
                "grober Schotterweg von ca. 100 Metern. fehlende Ost-West Verbindung",
            happyBikeLevel: "sehr stressig",
            soll: "Fahrbahn erneuern",
            description:
                "neuralgischer Punkt - Neue Radverkehrsroute Sendlinger-Tor-Platz zum Harras",
            munichwaysId: "RV03S.01.000-01.100",
            statusUmsetzung: "beantragt",
            bezirk: Bezirk(
                region: null,
                nummer: "BA02",
                name: "Ludwigsvorstadt-Isarvorstadt",
                link: Link(
                    title: "BA02 Ludwigsvorstadt-Isarvorstadt",
                    url: "https://www.munichways.de/bezirksausschuesse/")),
            links: [
              Link(
                  title: "RadlVorrang-Profil",
                  url:
                      "https://docs.google.com/document/d/14HlSPaYCMvT2v00sMvJYW4j0Hbq8jHdvr9bl2sZTlbk/edit?usp=sharing"),
              Link(
                  title: "RIS Antrag SPD 12.09.2019",
                  url:
                      "https://www.ris-muenchen.de/RII/RII/DOK/ANTRAG/5645187.pdf"),
              Link(
                  title: "RIS Beschluss zur Prüfung 09.12.2020",
                  url:
                      "https://www.ris-muenchen.de/RII/RII/DOK/SITZUNGSVORLAGE/6348847.pdf"),
              Link(
                  title: "SZ 12.01.2021 Leuchtendes Prestigeprojekt",
                  url:
                      "https://www.sueddeutsche.de/muenchen/muenchen-theresienwiese-radweg-debatte-1.5171682")
            ],
            farbe: "schwarz",
            mapillaryImgId: "233947365199559",
            kategorie: Kategorie(
                title: "ebener Radweg",
                url:
                    'https://github.com/MunichWays/bike-infrastructure/wiki/ebener-Radweg'),
            netztypId: 1,
            lastUpdated: DateTime.utc(2021, 1, 24, 21, 04, 38)));
  });

  test('fromJson app V04', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/feature_app_V04.json');
    var json = jsonDecode(jsonString);

    //WHEN
    StreetDetails details = StreetDetails.fromJson(json);

    //THEN
    expect(
        details,
        StreetDetails(
            cartoDbId: 1161,
            name:
                "Theresienwiese-Lücke-Beethovenstr.-Mattias-Pschorr-Str./Mozartstr.",
            strecke: "RV3S - Fürstenrieder-Radlroute",
            ist:
                "grober Schotterweg von ca. 100 Metern. fehlende Ost-West Verbindung",
            happyBikeLevel: "sehr stressig",
            soll: "Fahrbahn erneuern",
            description:
                "neuralgischer Punkt - Neue Radverkehrsroute Sendlinger-Tor-Platz zum Harras",
            munichwaysId: "LHM-Mitte.BA02.1161",
            statusUmsetzung: "beantragt",
            bezirk: Bezirk(
                region: null,
                nummer: "BA02",
                name: "Ludwigsvorstadt-Isarvorstadt",
                link: Link(
                    title: "BA02 Ludwigsvorstadt-Isarvorstadt",
                    url: "https://www.munichways.de/bezirksausschuesse/")),
            links: [
              Link(
                  title: "RadlVorrang-Profil",
                  url:
                      "https://docs.google.com/document/d/14HlSPaYCMvT2v00sMvJYW4j0Hbq8jHdvr9bl2sZTlbk/edit?usp=sharing"),
              Link(
                  title: "RIS Antrag SPD 12.09.2019",
                  url:
                      "https://www.ris-muenchen.de/RII/RII/DOK/ANTRAG/5645187.pdf"),
              Link(
                  title: "RIS Beschluss zur Prüfung 09.12.2020",
                  url:
                      "https://www.ris-muenchen.de/RII/RII/DOK/SITZUNGSVORLAGE/6348847.pdf"),
              Link(
                  title: "SZ 12.01.2021 Leuchtendes Prestigeprojekt",
                  url:
                      "https://www.sueddeutsche.de/muenchen/muenchen-theresienwiese-radweg-debatte-1.5171682")
            ],
            farbe: "schwarz",
            mapillaryImgId: "233947365199559",
            kategorie: Kategorie(
                title: "ebener Radweg",
                url:
                    'https://github.com/MunichWays/bike-infrastructure/wiki/ebener-Radweg'),
            netztypId: 1,
            lastUpdated: DateTime.utc(2021, 04, 11, 17, 29, 08),
            isMunichWaysRadlVorrangNetz: true));
  });

  test('fromJson app V07', () async {
    //GIVEN
    var jsonString = await TestUtils.readStringFromFile(
        'test_resources/feature_app_V07.json');
    var json = jsonDecode(jsonString);

    //WHEN
    StreetDetails details = StreetDetails.fromJson(json);

    //THEN
    expect(
        details,
        StreetDetails(
            cartoDbId: 1161,
            name:
                "Theresienwiese-Lücke-Beethovenstr.-Mattias-Pschorr-Str./Mozartstr.",
            strecke: "RV3S - Fürstenrieder-Radlroute",
            streckenLink: Link(
                title: "Pasing-Freiham-FFB",
                url: "https://www.munichways.de/unsere-radlvorrang-strecken/"),
            ist:
                "grober Schotterweg von ca. 100 Metern. fehlende Ost-West Verbindung",
            happyBikeLevel: "sehr stressig",
            soll: "Fahrbahn erneuern",
            description:
                "neuralgischer Punkt - Neue Radverkehrsroute Sendlinger-Tor-Platz zum Harras",
            munichwaysId: "LHM-Mitte.BA02.1161",
            statusUmsetzung: "beantragt",
            bezirk: Bezirk(
                region: null,
                nummer: "BA02",
                name: "Ludwigsvorstadt-Isarvorstadt",
                link: Link(
                    title: "BA02 Ludwigsvorstadt-Isarvorstadt",
                    url: "https://www.munichways.de/bezirksausschuesse/")),
            links: [
              Link(
                  title: "RadlVorrang-Profil",
                  url:
                      "https://docs.google.com/document/d/14HlSPaYCMvT2v00sMvJYW4j0Hbq8jHdvr9bl2sZTlbk/edit?usp=sharing"),
              Link(
                  title: "RIS Antrag SPD 12.09.2019",
                  url:
                      "https://www.ris-muenchen.de/RII/RII/DOK/ANTRAG/5645187.pdf"),
              Link(
                  title: "RIS Beschluss zur Prüfung 09.12.2020",
                  url:
                      "https://www.ris-muenchen.de/RII/RII/DOK/SITZUNGSVORLAGE/6348847.pdf"),
              Link(
                  title: "SZ 12.01.2021 Leuchtendes Prestigeprojekt",
                  url:
                      "https://www.sueddeutsche.de/muenchen/muenchen-theresienwiese-radweg-debatte-1.5171682")
            ],
            farbe: "schwarz",
            mapillaryImgId: "233947365199559",
            kategorie: Kategorie(
                title: "ebener Radweg",
                url:
                    'https://github.com/MunichWays/bike-infrastructure/wiki/ebener-Radweg'),
            netztypId: 1,
            lastUpdated: DateTime.utc(2021, 04, 11, 17, 29, 08),
            isMunichWaysRadlVorrangNetz: true));
  });
}
