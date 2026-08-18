import 'dart:io' show Platform;

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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
      if (_hasText(d.farbe)) context.l10n.tr(d.farbe!),
      if (_hasText(d.happyBikeLevel)) context.l10n.tr(d.happyBikeLevel!),
      if (_hasText(d.osmClassBicycle)) d.osmClassBicycle!,
    ];
    return [
      if (bothNames) ListItem(label: 'OSM', value: d.osmName),
      if (bothNames) ListItem(label: 'MunichWays', value: d.munichwaysName),
      if (ratingParts.isNotEmpty)
        ListItem(
          label: context.l10n.tr(
            'Bewertung | Happy Bike Level | OSM class:bicycle',
          ),
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
        if (_isVisibleRouteLink(link))
          _linkItem(context.l10n.tr('Strecke'), link),
      if (_hasText(d.mwRvRoute) && d.mwRvRoute != '-')
        ListItem(
          label: context.l10n.tr('RadlVorrangNetz'),
          value: d.mwRvRoute,
        ),
      if (_hasText(d.neuralgischerPunkt))
        ListItem(
          label: context.l10n.tr('Neuralgischer Punkt'),
          value: d.neuralgischerPunkt,
        ),
      if (_hasText(d.osmHighway))
        ListItem(
          label: context.l10n.tr('Straßenart'),
          value: d.osmHighway,
        ),
      if (_hasText(d.osmSurface))
        ListItem(
          label: context.l10n.tr('Oberfläche'),
          value: d.osmSurface,
        ),
      if (_hasText(d.osmSmoothness))
        ListItem(
          label: context.l10n.tr('Ebenheit'),
          value: d.osmSmoothness,
        ),
      if (_hasText(d.osmBicycle))
        ListItem(
          label: context.l10n.tr('Fahrradregelung'),
          value: d.osmBicycle,
        ),
      if (_hasText(d.osmAccess))
        ListItem(
          label: context.l10n.tr('Zugang'),
          value: d.osmAccess,
        ),
      if (_hasText(d.osmWidth))
        ListItem(
          label: context.l10n.tr('Breite'),
          value: _formatWidth(context, d.osmWidth!),
        ),
      if (_hasText(d.osmLit))
        ListItem(
          label: context.l10n.tr('Beleuchtung'),
          value: d.osmLit,
        ),
      for (final link in (d.mapillaryLinks ?? const <String>[]).skip(1))
        ListItem(
          label: context.l10n.tr('Weiteres Mapillary-Bild'),
          value: context.l10n.tr('Auf Mapillary ansehen'),
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
        if (_hasText(link.url))
          _linkItem(context.l10n.tr('Maßnahmen-Kategorie'), link),
      if (_hasText(d.statusUmsetzung))
        ListItem(
          label: context.l10n.tr('Status-Umsetzung'),
          value: d.statusUmsetzung,
        ),
      if (_hasText(d.netTypePlan))
        ListItem(
          label: context.l10n.tr('Netztyp Planung'),
          value: d.netTypePlan,
        ),
      if (_hasText(d.netTypeTarget))
        ListItem(
          label: context.l10n.tr('Netztyp Ziel'),
          value: d.netTypeTarget,
        ),
      for (final link in d.districtLinks ?? const <Link>[])
        if (_hasText(link.url)) _linkItem(context.l10n.tr('Bezirk'), link),
    ];
  }

  List<Widget> _technicalItems(BuildContext context) {
    final validOsmId = _hasText(d.osmId) && RegExp(r'^\d+$').hasMatch(d.osmId!);
    return [
      if (_hasText(d.munichwaysId))
        ListItem(label: 'MunichWays-ID', value: d.munichwaysId),
      if (_hasText(d.osmId)) ListItem(label: 'OSM-ID', value: d.osmId),
      if (validOsmId)
        ListItem(
          label: 'OpenStreetMap',
          value: context.l10n.tr('Auf OpenStreetMap ansehen'),
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
            value: context.l10n.tr('Auf Mapillary ansehen'),
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
      value: _hasText(link.title) ? link.title : context.l10n.tr('Link öffnen'),
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
        if (_hasText(link.url))
          _linkItem(context.l10n.tr('Weiterer Link'), link),
    ];
    final technical = _technicalItems(context);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(top: bottomSheetTopPadding(context)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: bottomSheetMaxHeight(context)),
          child: Container(
            decoration: bottomSheetDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BottomSheetDragHandle(),
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
                          title: context.l10n.tr('Ist-Zustand'),
                          icon: Icons.directions_bike_outlined,
                          children: currentState,
                          initiallyExpanded: true,
                        ),
                      if (planning.isNotEmpty)
                        _section(
                          title: context.l10n.tr('Forderungen und Netzplanung'),
                          icon: Icons.route_outlined,
                          children: planning,
                        ),
                      if (additionalLinks.isNotEmpty)
                        _section(
                          title: context.l10n.tr('Weitere Links'),
                          icon: Icons.link_outlined,
                          children: additionalLinks,
                        ),
                      if (technical.isNotEmpty)
                        _section(
                          title: context.l10n.tr('Technische Angaben'),
                          icon: Icons.data_object_outlined,
                          children: technical,
                        ),
                      ListItem(
                        label: context.l10n.tr('Feedback'),
                        value: context.l10n.tr('Feedback per E-Mail senden'),
                        isLink: true,
                        onTap: () => _sendFeedback(context),
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

  String _formatWidth(BuildContext context, String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(trimmed)) return trimmed;
    return '$trimmed ${context.l10n.isEnglish ? 'meters' : 'Meter'}';
  }

  Future<void> _sendFeedback(BuildContext context) async {
    var versionLabel = 'unbekannt';
    try {
      final info = await PackageInfo.fromPlatform();
      versionLabel =
          '${info.version} (${info.buildNumber}) ${Platform.isIOS ? 'iOS' : 'Android'}';
    } catch (error, stackTrace) {
      log.w(
        'Reading app version for feedback failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!context.mounted) return;

    final headerName = _hasText(d.name) ? d.name! : 'Streckenabschnitt';
    final subject = 'Feedback MunichWays App: $headerName';
    final bothNames = _hasText(d.osmName) && _hasText(d.munichwaysName);
    final ratingParts = [
      if (_hasText(d.farbe)) 'Farbe: ${d.farbe}',
      if (_hasText(d.happyBikeLevel)) 'Happy Bike Level: ${d.happyBikeLevel}',
      if (_hasText(d.osmClassBicycle))
        'OSM class:bicycle: ${d.osmClassBicycle}',
    ];
    final osmTags = [
      if (_hasText(d.osmHighway)) 'OSM highway: ${d.osmHighway}',
      if (_hasText(d.osmSurface)) 'OSM surface: ${d.osmSurface}',
      if (_hasText(d.osmSmoothness)) 'OSM smoothness: ${d.osmSmoothness}',
      if (_hasText(d.osmBicycle)) 'OSM bicycle: ${d.osmBicycle}',
      if (_hasText(d.osmAccess)) 'OSM access: ${d.osmAccess}',
      if (_hasText(d.osmWidth)) 'OSM width: ${d.osmWidth}',
      if (_hasText(d.osmLit)) 'OSM lit: ${d.osmLit}',
    ];
    final lines = <String>[
      '',
      '',
      '--------------------------------',
      '- Appversion: $versionLabel',
      '--------------------------------',
      context.l10n.isEnglish ? 'Related route section:' : 'Bezogene Strecke:',
      '- Name: $headerName',
      if (bothNames) '- OSM-Name: ${d.osmName}',
      if (bothNames) '- MunichWays-Name: ${d.munichwaysName}',
      if (ratingParts.isNotEmpty) '- ${ratingParts.join(' = ')}',
      if (_hasText(d.ist)) '- Ist-Situation: ${d.ist}',
      if (_hasText(d.description)) '- Beschreibung: ${d.description}',
      if (_hasText(d.mwRvRoute)) '- RadlVorrangNetz: ${d.mwRvRoute}',
      if (_hasText(d.neuralgischerPunkt))
        '- Neuralgischer Punkt: ${d.neuralgischerPunkt}',
      if (osmTags.isNotEmpty) '- ${osmTags.join(', ')}',
      if (_hasText(d.soll)) '- Soll-Maßnahmen: ${d.soll}',
      if (_hasText(d.osmId)) '- OSM-ID: ${d.osmId}',
      if (_hasText(d.munichwaysId)) '- MunichWays-ID: ${d.munichwaysId}',
      '--------------------------------',
    ];
    final uri = Uri.parse(
      'mailto:mail@munichways.de'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(lines.join('\n'))}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.tr('Keine E-Mail-App gefunden'),
          ),
        ),
      );
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
                color: AppColors.getPolylineColor(
                  farbe,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
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
