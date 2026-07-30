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
  final String? osmId;
  final String? osmName;
  final String? munichwaysName;
  final String? osmClassBicycle;
  final String? osmSmoothness;
  final String? osmSurface;
  final String? osmBicycle;
  final String? osmHighway;
  final String? osmLit;
  final String? osmWidth;
  final String? osmAccess;
  final String? netTypePlan;
  final String? netTypeTarget;
  final String? mwRvRoute;
  final List<Link>? routeLinks;
  final List<Link>? measureCategoryLinks;
  final List<Link>? districtLinks;
  final List<String>? mapillaryLinks;
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
      this.osmId,
      this.osmName,
      this.munichwaysName,
      this.osmClassBicycle,
      this.osmSmoothness,
      this.osmSurface,
      this.osmBicycle,
      this.osmHighway,
      this.osmLit,
      this.osmWidth,
      this.osmAccess,
      this.netTypePlan,
      this.netTypeTarget,
      this.mwRvRoute,
      this.routeLinks,
      this.measureCategoryLinks,
      this.districtLinks,
      this.mapillaryLinks,
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
        osmId: properties['osm_id']?.toString(),
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
          properties['mapillary_img_id']?.toString(),
          properties['mapillary_link'],
          properties['strassenansicht_klick_mich'],
        ),
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

  factory StreetDetails.fromHappyBikeLevelJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>;
    return StreetDetails(
      munichwaysId: properties['munichways_id']?.toString(),
      osmId: properties['osm_id']?.toString(),
      farbe: _germanColor(properties['color']),
      isMunichWaysRadlVorrangNetz:
          !['-', null, ''].contains(properties['munichways_mw_rv_route']),
    );
  }

  factory StreetDetails.fromV20Json(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>;
    final osmName = properties['osm_name']?.toString();
    final munichwaysName = properties['munichways_name']?.toString();
    final classBicycle = properties['osm_class_bicycle']?.toString();
    return StreetDetails(
      name: _firstNotEmpty(osmName, munichwaysName),
      osmName: osmName,
      munichwaysName: munichwaysName,
      description: properties['munichways_description'],
      munichwaysId: properties['munichways_id']?.toString(),
      osmId: properties['osm_id']?.toString(),
      osmClassBicycle: classBicycle,
      happyBikeLevel: _happyBikeLevel(classBicycle),
      osmSmoothness: properties['osm_smoothness']?.toString(),
      osmSurface: properties['osm_surface']?.toString(),
      osmBicycle: properties['osm_bicycle']?.toString(),
      osmHighway: properties['osm_highway']?.toString(),
      osmLit: properties['osm_lit']?.toString(),
      osmWidth: properties['osm_width']?.toString(),
      osmAccess: properties['osm_access']?.toString(),
      ist: properties['munichways_current'],
      soll: properties['munichways_target'],
      farbe: _colorForClassBicycle(classBicycle) ??
          _germanColor(properties['color']),
      statusUmsetzung: properties['munichways_status_implementation'],
      neuralgischerPunkt: properties['munichways_neuralgic_point'],
      netTypePlan: properties['munichways_net_type_plan']?.toString(),
      netTypeTarget: properties['munichways_net_type_target']?.toString(),
      mwRvRoute: properties['munichways_mw_rv_route']?.toString(),
      routeLinks: _parseLinks(properties['munichways_route_link']),
      measureCategoryLinks:
          _parseLinks(properties['munichways_measure_category_link']),
      districtLinks: _parseLinks(properties['munichways_district_link']),
      links: _parseLinks(properties['munichways_links']),
      mapillaryLinks:
          _parseMapillaryLinks(properties['munichways_mapillary_link']),
      isMunichWaysRadlVorrangNetz:
          !['-', null, ''].contains(properties['munichways_mw_rv_route']),
    );
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
        this.osmId,
        this.osmName,
        this.munichwaysName,
        this.osmClassBicycle,
        this.osmSmoothness,
        this.osmSurface,
        this.osmBicycle,
        this.osmHighway,
        this.osmLit,
        this.osmWidth,
        this.osmAccess,
        this.netTypePlan,
        this.netTypeTarget,
        this.mwRvRoute,
        this.routeLinks,
        this.measureCategoryLinks,
        this.districtLinks,
        this.mapillaryLinks,
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

/// Stable key shared by the lightweight map geometry and the full V20 details.
///
/// One MunichWays entry can be mapped to several differently rated OSM ways,
/// therefore the OSM way id must take precedence whenever it is available.
String? streetDetailsFeatureId(StreetDetails? details) {
  final osmId = details?.osmId;
  if (osmId != null && osmId.isNotEmpty) return 'osm_$osmId';
  final munichwaysId = details?.munichwaysId;
  if (munichwaysId != null && munichwaysId.isNotEmpty) return munichwaysId;
  return null;
}

String? _germanColor(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'green':
      return 'grün';
    case 'yellow':
      return 'gelb';
    case 'red':
      return 'rot';
    case 'black':
      return 'schwarz';
    case 'blue':
      return 'blau';
    default:
      return value?.toString();
  }
}

String? _firstNotEmpty(String? first, String? second) {
  if (first != null && first.trim().isNotEmpty) return first;
  if (second != null && second.trim().isNotEmpty) return second;
  return null;
}

String? _happyBikeLevel(String? classBicycle) {
  switch (classBicycle) {
    case '3':
      return 'hervorragend';
    case '2':
      return 'gemütlich';
    case '1':
      return 'durchschnittlich';
    case '0':
      return 'keine Aussage';
    case '-1':
      return 'stressig';
    case '-2':
      return 'sehr stressig';
    case '-3':
      return 'Unter allen Umständen vermeiden';
    default:
      return null;
  }
}

String? _colorForClassBicycle(String? classBicycle) {
  switch (classBicycle) {
    case '3':
    case '2':
      return 'grün';
    case '1':
      return 'gelb';
    case '0':
      return null;
    case '-1':
      return 'rot';
    case '-2':
    case '-3':
      return 'schwarz';
    default:
      return null;
  }
}

List<Link> _parseLinks(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return const [];
  final htmlLinks = LinksParser.parse(text);
  if (htmlLinks.isNotEmpty) return htmlLinks;
  return text
      .split(',')
      .map((part) => part.trim())
      .where((part) => Uri.tryParse(part)?.hasScheme == true)
      .map((url) => Link(title: url, url: url))
      .toList();
}

List<String> _parseMapillaryLinks(dynamic value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return const [];
  return text
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.startsWith('https://www.mapillary.com/'))
      .toSet()
      .toList();
}
