import 'package:equatable/equatable.dart';
import 'package:munich_ways/ui/map/kategorie.dart';

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
  final String links;
  final String strecke;
  final String quartal;
  final String bild;
  final String ba;
  final String gs;

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
      this.quartal,
      this.bild,
      this.ba,
      this.gs});

  factory StreetDetails.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> properties = json['properties'];
    return StreetDetails(
      cartoDbId: properties['cartodb_id'] as int,
      name: properties['name'],
      description: properties['description'],
      netztyp: properties['netztyp'],
      munichwaysId: properties['munichways_id'],
      ist: properties['ist'],
      soll: properties['soll'],
      kategorie: Kategorie.fromString(properties['kategorie']),
      farbe: properties['farbe'],
      links: properties['links'],
      strecke: properties['strecke'],
      quartal: properties['quartal'],
      bild: properties['bild'],
      ba: properties['ba'],
      gs: properties['gs'],
      netztypId: properties['netztyp_id'] as int,
      kategorieId: properties['kategorie_id'] as int,
    );
  }

  @override
  String toString() {
    return 'StreetDetails{cartoDbId: $cartoDbId, name: $name, description: $description, netztyp: $netztyp, netztypId: $netztypId, munichwaysId: $munichwaysId, ist: $ist, soll: $soll, kategorie: $kategorie, kategorieId: $kategorieId, farbe: $farbe, links: $links, strecke: $strecke, quartal: $quartal, bild: $bild, ba: $ba, gs: $gs}';
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
        this.quartal,
        this.bild,
        this.ba,
        this.gs
      ];
}
