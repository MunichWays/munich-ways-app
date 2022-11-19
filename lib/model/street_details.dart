import 'package:equatable/equatable.dart';
import 'package:munich_ways/model/ImgIdParser.dart';
import 'package:munich_ways/model/bezirk.dart';
import 'package:munich_ways/model/kategorie.dart';
import 'package:munich_ways/model/links.dart';

/// Details for a street taken from the properties of a geojson feature
class StreetDetails extends Equatable {
  final int? cartoDbId;
  final String? name;
  final String? description;
  final String? netztyp;
  final int? netztypId;
  final String? munichwaysId;
  final String? ist;
  final String? soll;
  final Kategorie? kategorie;
  final int? kategorieId;
  final String? farbe;
  final List<Link>? links;
  final String? strecke;
  final Link? streckenLink;
  final String? streetview;
  final Bezirk? bezirk;
  final String? statusUmsetzung;
  final int? statusId;
  final String? happyBikeLevel;
  final DateTime? lastUpdated;
  final String? alternative;
  final String? rsvStrecke;
  final int? planNetztypId;
  final String? massnahmenKategorie;
  final num? prioGesamt;
  final String? neuralgischerPunkt;
  final bool? vielKfz;
  final String? mapillaryImgId;
  final bool isMunichWaysRadlVorrangNetz;

  StreetDetails(
      {this.cartoDbId,
      this.name,
      this.description,
      this.netztyp,
      this.netztypId,
      this.munichwaysId,
      this.ist,
      this.soll,
      this.kategorie,
      this.kategorieId,
      this.farbe,
      this.links,
      this.strecke,
      this.streckenLink,
      this.streetview,
      this.statusUmsetzung,
      this.statusId,
      this.happyBikeLevel,
      this.lastUpdated,
      this.alternative,
      this.rsvStrecke,
      this.planNetztypId,
      this.massnahmenKategorie,
      this.prioGesamt,
      this.neuralgischerPunkt,
      this.vielKfz,
      this.bezirk,
      this.mapillaryImgId,
      this.isMunichWaysRadlVorrangNetz = false});

  factory StreetDetails.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> properties = json['properties'];

    return StreetDetails(
        cartoDbId: properties['cartodb_id'] as int?,
        name: properties['name'],
        description: properties['beschreibung'],
        netztyp: properties['netztyp'],
        munichwaysId: properties['munichways_id'],
        ist: properties['ist_situation'],
        soll: properties['soll_massnahmen'],
        kategorie: properties['massnahmen_kategorie_link'] != null
            ? Kategorie.fromString(properties['massnahmen_kategorie_link'])
            : null,
        farbe: properties['farbe'],
        links: LinksParser.parse(properties['links']),
        strecke: properties['strecke'],
        streckenLink: properties['strecken_link'] != null
            ? LinksParser.parseSingleLink(properties['strecken_link'])
            : null,
        streetview: properties['strassenansicht_klick_mich'],
        netztypId: properties['netztyp_id'] as int?,
        kategorieId: properties['kategorie_id'] as int?,
        statusUmsetzung: properties['status_umsetzung'],
        statusId: properties['status_id'] as int?,
        happyBikeLevel: properties['happy_bike_level'],
        lastUpdated: DateTime.tryParse(properties['last_updated']),
        rsvStrecke: properties['rsv_strecke'],
        alternative: properties['alternative'],
        planNetztypId: properties['plan_netztyp_id'] as int?,
        mapillaryImgId: ImgIdParser().parse(
            properties['mapillary_img_id'],
            properties['mapillary_link'],
            properties['strassenansicht_klick_mich']),
        massnahmenKategorie: properties['massnahmen_kategorie'],
        prioGesamt: properties['prio_gesamt'] != null
            ? double.tryParse(
                (properties['prio_gesamt'] as String).replaceAll(',', '.'))
            : null,
        neuralgischerPunkt: properties['neuralgischer_punkt'],
        vielKfz: properties['viel_kfz'] != null
            ? 'ja' == (properties['viel_kfz'] as String).toLowerCase()
            : null,
        bezirk: Bezirk.fromProps(
            name: properties['bezirk_name'],
            nummer: properties['bezirk_nummer'],
            region: properties['bezirk_region'],
            link: properties['bezirk_link']),
        isMunichWaysRadlVorrangNetz:
            !['-', null, ''].contains(properties['mw_rv_strecke']));
  }

  @override
  String toString() {
    return 'StreetDetails{cartoDbId: $cartoDbId, name: $name, description: $description, netztyp: $netztyp, netztypId: $netztypId, munichwaysId: $munichwaysId, ist: $ist, soll: $soll, kategorie: $kategorie, kategorieId: $kategorieId, farbe: $farbe, links: $links, strecke: $strecke, streckenLink: $streckenLink, streetview: $streetview, bezirk: $bezirk, statusUmsetzung: $statusUmsetzung, statusId: $statusId, happyBikeLevel: $happyBikeLevel, lastUpdated: $lastUpdated, alternative: $alternative, rsvStrecke: $rsvStrecke, planNetztypId: $planNetztypId, massnahmenKategorie: $massnahmenKategorie, prioGesamt: $prioGesamt, neuralgischerPunkt: $neuralgischerPunkt, vielKfz: $vielKfz, mapillaryImgId: $mapillaryImgId, mwRvStrecke: $isMunichWaysRadlVorrangNetz}';
  }

  @override
  List<Object?> get props => [
        this.cartoDbId,
        this.name,
        this.description,
        this.netztyp,
        this.netztypId,
        this.munichwaysId,
        this.ist,
        this.soll,
        this.kategorie,
        this.kategorieId,
        this.farbe,
        this.links,
        this.strecke,
        this.streckenLink,
        this.streetview,
        this.statusUmsetzung,
        this.statusId,
        this.happyBikeLevel,
        this.lastUpdated,
        this.alternative,
        this.rsvStrecke,
        this.planNetztypId,
        this.mapillaryImgId,
        this.massnahmenKategorie,
        this.prioGesamt,
        this.neuralgischerPunkt,
        this.vielKfz,
        this.bezirk,
        this.isMunichWaysRadlVorrangNetz
      ];
}
