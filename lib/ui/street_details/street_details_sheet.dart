import 'package:flutter/material.dart';
import 'package:munich_ways/api/mapillary/mapillary_service.dart';
import 'package:munich_ways/api/mapillary/mapillary_thumb_data_model.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/ImgIdParser.dart';
import 'package:munich_ways/model/links.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/street_details/mapillary_image.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';
import 'package:url_launcher/url_launcher_string.dart';

class StreetDetailsSheet extends StatefulWidget {
  const StreetDetailsSheet({
    super.key,
    required this.details,
  });

  final StreetDetails details;

  @override
  State<StreetDetailsSheet> createState() => _StreetDetailsSheetState();
}

class _StreetDetailsSheetState extends State<StreetDetailsSheet> {
  Future<MapillaryThumbDataModel>? _mapillaryThumbnail;

  StreetDetails get d => widget.details;

  @override
  void initState() {
    super.initState();
    final firstLink =
        d.mapillaryLinks?.where((link) => link.isNotEmpty).firstOrNull;
    final imageId = ImgIdParser().parse(null, firstLink, null);
    if (imageId != null && imageId.isNotEmpty) {
      _mapillaryThumbnail = getSinglePostData(imageId);
    }
  }

  bool _hasText(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    return trimmed.isNotEmpty && trimmed != '-';
  }

  bool _isVisibleRouteLink(Link link) {
    if (!_hasText(link.url)) return false;
    return link.title?.trim().toLowerCase() != '-n/a-alle-wege';
  }

  List<Widget> _namesAndRating(BuildContext context) {
    final bothNames = _hasText(d.osmName) && _hasText(d.munichwaysName);
    final ratingParts = [
      if (_hasText(d.farbe)) _colorLabel(d.farbe).toLowerCase(),
      if (_hasText(d.happyBikeLevel)) d.happyBikeLevel!,
      if (_hasText(d.osmClassBicycle)) d.osmClassBicycle!,
    ];
    return [
      if (bothNames) ListItem(label: 'OSM', value: d.osmName),
      if (bothNames) ListItem(label: 'MunichWays', value: d.munichwaysName),
      if (ratingParts.isNotEmpty)
        ListItem(
          label: 'Bewertung | Happy Bike Level | OSM class:bicycle',
          value: ratingParts.join(' = '),
        ),
    ];
  }

  List<Widget> _currentStateItems(BuildContext context) {
    return [
      if (_hasText(d.ist))
        ListItem(
          label: context.l10n.tr('Ist-Situation'),
          value: d.ist,
        ),
      if (_hasText(d.description))
        ListItem(
          label: context.l10n.tr('Beschreibung'),
          value: d.description,
        ),
      for (final link in d.routeLinks ?? const <Link>[])
        if (_isVisibleRouteLink(link)) _linkItem('Strecke', link),
      if (_hasText(d.mwRvRoute) && d.mwRvRoute != '-')
        ListItem(label: 'RadlVorrangNetz', value: d.mwRvRoute),
      if (_hasText(d.neuralgischerPunkt))
        ListItem(
          label: 'Neuralgischer Punkt',
          value: d.neuralgischerPunkt,
        ),
      if (_hasText(d.osmHighway))
        ListItem(
          label: 'Straßenart',
          value: _translateOsmValue('highway', d.osmHighway!),
        ),
      if (_hasText(d.osmSurface))
        ListItem(
          label: 'Oberfläche',
          value: _translateOsmValue('surface', d.osmSurface!),
        ),
      if (_hasText(d.osmSmoothness))
        ListItem(
          label: 'Ebenheit',
          value: _translateOsmValue('smoothness', d.osmSmoothness!),
        ),
      if (_hasText(d.osmBicycle))
        ListItem(
          label: 'Fahrradregelung',
          value: _translateOsmValue('bicycle', d.osmBicycle!),
        ),
      if (_hasText(d.osmAccess))
        ListItem(
          label: 'Zugang',
          value: _translateOsmValue('access', d.osmAccess!),
        ),
      if (_hasText(d.osmWidth)) ListItem(label: 'Breite', value: d.osmWidth),
      if (_hasText(d.osmLit))
        ListItem(
          label: 'Beleuchtung',
          value: _translateOsmValue('lit', d.osmLit!),
        ),
      for (final link in (d.mapillaryLinks ?? const <String>[]).skip(1))
        ListItem(
          label: 'Weiteres Mapillary-Bild',
          value: 'Auf Mapillary ansehen',
          isLink: true,
          onTap: () => _launchWebsite(link),
        ),
    ];
  }

  List<Widget> _planningItems(BuildContext context) {
    return [
      if (_hasText(d.soll))
        ListItem(
          label: context.l10n.tr('Soll-Maßnahmen'),
          value: d.soll,
        ),
      for (final link in d.measureCategoryLinks ?? const <Link>[])
        if (_hasText(link.url)) _linkItem('Maßnahmenkategorie', link),
      if (_hasText(d.statusUmsetzung))
        ListItem(
          label: 'Umsetzungsstatus',
          value: d.statusUmsetzung,
        ),
      if (_hasText(d.netTypePlan))
        ListItem(label: 'Netztyp Planung', value: d.netTypePlan),
      if (_hasText(d.netTypeTarget))
        ListItem(label: 'Netztyp Ziel', value: d.netTypeTarget),
      for (final link in d.districtLinks ?? const <Link>[])
        if (_hasText(link.url)) _linkItem('Bezirk', link),
    ];
  }

  List<Widget> _technicalItems() {
    final validOsmId = _hasText(d.osmId) && RegExp(r'^\d+$').hasMatch(d.osmId!);
    return [
      if (_hasText(d.munichwaysId))
        ListItem(label: 'MunichWays-ID', value: d.munichwaysId),
      if (_hasText(d.osmId)) ListItem(label: 'OSM-ID', value: d.osmId),
      if (validOsmId)
        ListItem(
          label: 'OpenStreetMap',
          value: 'Auf OpenStreetMap ansehen',
          isLink: true,
          onTap: () => _launchWebsite(
            'https://www.openstreetmap.org/way/${d.osmId}',
          ),
        ),
    ];
  }

  Widget _mapillaryPreview() {
    return FutureBuilder<MapillaryThumbDataModel>(
      future: _mapillaryThumbnail,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final data = snapshot.data!;
          return MapillaryImage(
            mapillaryImgId: data.imageId,
            mapillaryThumbUrl: data.thumbUrl,
          );
        }
        if (snapshot.hasError) {
          return ListItem(
            label: 'Mapillary',
            value: 'Auf Mapillary ansehen',
            isLink: true,
            onTap: () => _launchWebsite(d.mapillaryLinks!.first),
          );
        }
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  ListItem _linkItem(String label, Link link) {
    return ListItem(
      label: label,
      value: _hasText(link.title) ? link.title : 'Link öffnen',
      isLink: true,
      onTap: () => _launchWebsite(link.url),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
    required IconData icon,
    bool initiallyExpanded = false,
  }) {
    return Builder(
      builder: (sectionContext) {
        final colors = Theme.of(sectionContext).colorScheme;
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ExpansionTile(
              leading: Icon(icon),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              textColor: colors.onPrimaryContainer,
              collapsedTextColor: colors.onPrimaryContainer,
              iconColor: colors.primary,
              collapsedIconColor: colors.primary,
              backgroundColor: colors.primaryContainer.withValues(alpha: 0.28),
              collapsedBackgroundColor:
                  colors.primaryContainer.withValues(alpha: 0.55),
              shape: shape,
              collapsedShape: shape,
              initiallyExpanded: initiallyExpanded,
              onExpansionChanged: (expanded) {
                if (!expanded) return;
                Future<void>.delayed(const Duration(milliseconds: 250), () {
                  if (!sectionContext.mounted) return;
                  Scrollable.ensureVisible(
                    sectionContext,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    alignment: 0.05,
                  );
                });
              },
              children: children,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentState = _currentStateItems(context);
    final planning = _planningItems(context);
    final additionalLinks = [
      for (final link in d.links ?? const <Link>[])
        if (_hasText(link.url)) _linkItem('Weiterer Link', link),
    ];
    final technical = _technicalItems();

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(top: bottomSheetTopPadding(context)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: bottomSheetMaxHeight(context)),
          child: Container(
            decoration: bottomSheetDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(farbe: d.farbe, name: d.name),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: bottomSheetBottomScrollPadding(context),
                    ),
                    children: [
                      if (_mapillaryThumbnail != null) _mapillaryPreview(),
                      ..._namesAndRating(context),
                      if (currentState.isNotEmpty)
                        _section(
                          title: 'Ist-Zustand',
                          icon: Icons.directions_bike_outlined,
                          children: currentState,
                          initiallyExpanded: true,
                        ),
                      if (planning.isNotEmpty)
                        _section(
                          title: 'Forderungen und Netzplanung',
                          icon: Icons.route_outlined,
                          children: planning,
                        ),
                      if (additionalLinks.isNotEmpty)
                        _section(
                          title: 'Weitere Links',
                          icon: Icons.link_outlined,
                          children: additionalLinks,
                        ),
                      if (technical.isNotEmpty)
                        _section(
                          title: 'Technische Angaben',
                          icon: Icons.data_object_outlined,
                          children: technical,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchWebsite(String? url) async {
    if (!_hasText(url)) return;
    final encodedUrl = Uri.encodeFull(url!);
    if (await canLaunchUrlString(encodedUrl)) {
      await launchUrlString(encodedUrl);
    } else {
      log.e('Could not launch $encodedUrl');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({this.farbe, this.name});

  final String? farbe;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Container(
              width: 12,
              height: 12,
              decoration: ShapeDecoration(
                color: AppColors.getPolylineColor(farbe),
                shape: const CircleBorder(),
              ),
            ),
          ),
          Expanded(
            child: Text(
              name ?? context.l10n.tr('Unbekannte Straße'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.l10n.close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

String _colorLabel(String? color) {
  switch (color) {
    case 'grün':
      return 'Grün';
    case 'gelb':
      return 'Gelb';
    case 'rot':
      return 'Rot';
    case 'schwarz':
      return 'Schwarz';
    default:
      return color ?? '';
  }
}

String _translateOsmValue(String key, String value) {
  const translations = {
    'highway': {
      'cycleway': 'Radweg',
      'path': 'Pfad/Weg',
      'residential': 'Wohnstraße',
      'living_street': 'Verkehrsberuhigter Bereich',
      'service': 'Erschließungsweg',
      'primary': 'Hauptstraße',
      'secondary': 'Sekundärstraße',
      'tertiary': 'Verbindungsstraße',
      'unclassified': 'Nebenstraße',
      'track': 'Wirtschaftsweg',
      'pedestrian': 'Fußgängerzone',
      'footway': 'Fußweg',
    },
    'surface': {
      'asphalt': 'Asphalt',
      'concrete': 'Beton',
      'concrete:plates': 'Betonplatten',
      'paving_stones': 'Pflastersteine',
      'sett': 'Natursteinpflaster',
      'cobblestone': 'Kopfsteinpflaster',
      'compacted': 'Verdichtete Oberfläche',
      'fine_gravel': 'Feiner Schotter',
      'gravel': 'Schotter',
      'ground': 'Naturboden',
      'dirt': 'Erde',
      'unpaved': 'Unbefestigt',
    },
    'smoothness': {
      'excellent': 'ausgezeichnet',
      'good': 'gut',
      'intermediate': 'mittel',
      'bad': 'schlecht',
      'very_bad': 'sehr schlecht',
      'horrible': 'äußerst schlecht',
      'very_horrible': 'kaum befahrbar',
      'impassable': 'unpassierbar',
    },
    'bicycle': {
      'yes': 'erlaubt',
      'designated': 'ausgewiesen',
      'permissive': 'geduldet',
      'no': 'nicht erlaubt',
      'dismount': 'Absteigen',
      'use_sidepath': 'Radweg benutzen',
    },
    'access': {
      'yes': 'öffentlich zugänglich',
      'permissive': 'geduldet',
      'private': 'privat',
      'no': 'kein Zugang',
      'destination': 'nur Anlieger/Zielverkehr',
    },
    'lit': {
      'yes': 'ja',
      'no': 'nein',
      'automatic': 'automatisch',
      'limited': 'teilweise',
    },
  };
  return translations[key]?[value] ?? value;
}
