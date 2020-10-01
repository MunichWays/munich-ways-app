import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/model/kategorie.dart';
import 'package:munich_ways/model/links.dart';
import 'package:munich_ways/model/street_details.dart';

import '../test_utils.dart';

void main() {
  test('fromJson', () async {
    //GIVEN
    var jsonString =
        await TestUtils.readStringFromFile('test_resources/feature.json');
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
            description: "neuralgischer Punkt",
            netztyp: "1_RadlVorrang",
            munichwaysId: "RV03S.01.000-01.100",
            ist:
                "grober Schotterweg von ca. 100 Metern. fehlende Ost-West Verbindung",
            soll: "Fahrbahn erneuern",
            kategorie: Kategorie(
                title: "ebener Radweg",
                url:
                    'https://github.com/MunichWays/bike-infrastructure/wiki/ebener-Radweg'),
            farbe: "schwarz",
            links: [
              Link("RadlVorrangProfil",
                  "https://docs.google.com/document/d/14HlSPaYCMvT2v00sMvJYW4j0Hbq8jHdvr9bl2sZTlbk/edit?usp=sharing"),
              Link("Maßnahmenkatalog",
                  "https://docs.google.com/document/d/11cXxckedsvTK9OPncjArQdBjZ_gmi_mKEtMENqmjYkE/edit?usp=sharing"),
              Link("RIS Antrag SPD 19.09.2019",
                  "https://www.ris-muenchen.de/RII/RII/DOK/ANTRAG/5645187.pdf"),
            ],
            strecke: "RV3S - Fürstenrieder-Radlroute",
            quartal: "Q4_2020",
            bild:
                "<a href=\"https://www.mapillary.com/map/im/MoDbKpzUOr9tcd5Gx22gyE\" target=\"_blank\">\n<img src=\"https://www.munichways.com/img/Theresienwiese_175.jpg\" width=175></a>",
            ba: "BA02",
            gs: "LHM-Mitte",
            netztypId: 1,
            kategorieId: 9));
  });
}
