import 'package:equatable/equatable.dart';
import 'package:munich_ways/model/kategorie.dart';
import 'package:munich_ways/model/links.dart';

/// Details for a street taken from the properties of a geojson feature
class StreetDetails extends Equatable {
  final int cartoDbId;
  final String name;
  final String description;
  final String netztyp;
  final int netztypId;
  final String munichwaysId;
  final String ist;
  final String soll;
  final Kategorie kategorie;
  final int kategorieId;
  final String farbe;
  final List<Link> links;
  final String strecke;
  final String streetview;
  final String bezirkLink;
  final String bezirkRegion;
  final String bezirkName;
  final String bezirkNummer;
  final String statusUmsetzung;
  final int statusId;
  final String happyBikeLevel;
  final DateTime lastUpdated;
  final String alternative;
  final String rsvStrecke;
  final int planNetztypId;
  final String mapillaryLink;
  final String massnahmenKategorie;
  final num prioGesamt;
  final String neuralgischerPunkt;
  final bool vielKfz;

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
      this.streetview,
      this.bezirkLink,
      this.bezirkRegion,
      this.statusUmsetzung,
      this.statusId,
      this.happyBikeLevel,
      this.lastUpdated,
      this.alternative,
      this.rsvStrecke,
      this.bezirkName,
      this.planNetztypId,
      this.mapillaryLink,
      this.massnahmenKategorie,
      this.prioGesamt,
      this.neuralgischerPunkt,
      this.vielKfz,
      this.bezirkNummer});

  factory StreetDetails.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> properties = json['properties'];

    return StreetDetails(
        cartoDbId: properties['cartodb_id'] as int,
        name: properties['name'],
        description: properties['beschreibung'],
        netztyp: properties['netztyp'],
        munichwaysId: properties['munichways_id'],
        ist: properties['ist_situation'],
        soll: properties['soll_massnahmen'],
        kategorie:
            Kategorie.fromString(properties['massnahmen_kategorie_link']),
        farbe: properties['farbe'],
        links: LinksParser.parse(properties['links']),
        strecke: properties['strecke'],
        streetview: properties['strassenansicht_klick_mich'],
        bezirkLink: properties['bezirk_link'],
        bezirkRegion: properties['bezirk_region'],
        netztypId: properties['netztyp_id'] as int,
        kategorieId: properties['kategorie_id'] as int,
        statusUmsetzung: properties['status_umsetzung'],
        statusId: properties['status_id'] as int,
        happyBikeLevel: properties['happy_bike_level'],
        lastUpdated: DateTime.tryParse(properties['last_updated']),
        rsvStrecke: properties['rsv_strecke'],
        alternative: properties['alternative'],
        planNetztypId: properties['plan_netztyp_id'] as int,
        mapillaryLink: properties['mapillary_link'],
        massnahmenKategorie: properties['massnahmen_kategorie'],
        bezirkName: properties['bezirk_name'],
        prioGesamt: double.tryParse(
            (properties['prio_gesamt'] as String).replaceAll(',', '.')),
        neuralgischerPunkt: properties['neuralgischer_punkt'],
        vielKfz: 'ja' == (properties['viel_kfz'] as String).toLowerCase(),
        bezirkNummer: properties['bezirk_nummer']);
  }

  @override
  String toString() {
    return 'StreetDetails{cartoDbId: $cartoDbId, name: $name, description: $description, netztyp: $netztyp, netztypId: $netztypId, munichwaysId: $munichwaysId, ist: $ist, soll: $soll, kategorie: $kategorie, kategorieId: $kategorieId, farbe: $farbe, links: $links, strecke: $strecke, bild: $streetview, bezirkLink: $bezirkLink, bezirkRegion: $bezirkRegion, bezirkName: $bezirkName, statusUmsetzung: $statusUmsetzung, statusId: $statusId, happyBikeLevel: $happyBikeLevel, lastUpdated: $lastUpdated, alternative: $alternative, rsvStrecke: $rsvStrecke, planNetztypId: $planNetztypId, mapillaryLink: $mapillaryLink, massnahmenKategorie: $massnahmenKategorie, prioGesamt: $prioGesamt, neuralgischerPunkt: $neuralgischerPunkt, vielKfz: $vielKfz}';
  }

  @override
  List<Object> get props => [
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
        this.streetview,
        this.bezirkLink,
        this.bezirkRegion,
        this.statusUmsetzung,
        this.statusId,
        this.happyBikeLevel,
        this.lastUpdated,
        this.alternative,
        this.rsvStrecke,
        this.bezirkName,
        this.planNetztypId,
        this.mapillaryLink,
        this.massnahmenKategorie,
        this.prioGesamt,
        this.neuralgischerPunkt,
        this.vielKfz,
      ];
}
