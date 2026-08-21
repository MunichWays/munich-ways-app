import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/poi_details.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:munich_ways/ui/widgets/list_item.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PoiDetailsSheet extends StatelessWidget {
  const PoiDetailsSheet({
    super.key,
    required this.details,
    this.onRouteHere,
  });

  final PoiDetails details;
  final VoidCallback? onRouteHere;

  static const _tagOrder = [
    'name',
    'amenity',
    'drinking_water',
    'access',
    'opening_hours',
    'fee',
    'wheelchair',
    'bottle',
    'dog',
    'seasonal',
    'indoor',
    'covered',
    'operator',
    'description',
    'note',
    'website',
    'source:website',
    'check_date',
    'source',
    'osm_id',
  ];

  static const _germanLabels = {
    'name': 'Name',
    'amenity': 'Einrichtungsart',
    'drinking_water': 'Trinkwasser',
    'access': 'Zugang',
    'opening_hours': 'Öffnungszeiten',
    'fee': 'Gebühr',
    'wheelchair': 'Rollstuhlgerecht',
    'bottle': 'Flaschenbefüllung',
    'dog': 'Für Hunde geeignet',
    'seasonal': 'Saisonal',
    'indoor': 'Innenbereich',
    'covered': 'Überdacht',
    'operator': 'Betreiber',
    'description': 'Beschreibung',
    'note': 'Hinweis',
    'website': 'Webseite',
    'source:website': 'Quell-Webseite',
    'check_date': 'Zuletzt geprüft',
    'source': 'Quelle',
    'osm_id': 'OSM-ID',
  };

  static const _englishLabels = {
    'name': 'Name',
    'amenity': 'Feature type',
    'drinking_water': 'Drinking water',
    'access': 'Access',
    'opening_hours': 'Opening hours',
    'fee': 'Fee',
    'wheelchair': 'Wheelchair access',
    'bottle': 'Bottle filling',
    'dog': 'Suitable for dogs',
    'seasonal': 'Seasonal',
    'indoor': 'Indoor',
    'covered': 'Covered',
    'operator': 'Operator',
    'description': 'Description',
    'note': 'Note',
    'website': 'Website',
    'source:website': 'Source website',
    'check_date': 'Last checked',
    'source': 'Source',
    'osm_id': 'OSM ID',
  };

  List<MapEntry<String, String>> _orderedTags() {
    final entries = details.tags.entries
        .where((entry) => entry.key != 'osm_type' && entry.key != 'osm_url')
        .toList();
    entries.sort((a, b) {
      final aIndex = _tagOrder.indexOf(a.key);
      final bIndex = _tagOrder.indexOf(b.key);
      if (aIndex >= 0 && bIndex >= 0) return aIndex.compareTo(bIndex);
      if (aIndex >= 0) return -1;
      if (bIndex >= 0) return 1;
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final english = context.l10n.isEnglish;
    final labels = english ? _englishLabels : _germanLabels;
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.water_drop,
                        color: AppColors.mapRouteColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          details.title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRouteHere != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FilledButton.icon(
                      style: AppButtonStyles.primary(context),
                      onPressed: onRouteHere,
                      icon: const Icon(Icons.navigation_outlined),
                      label: Text(
                        english ? 'Route here' : 'Route hierhin',
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: bottomSheetBottomScrollPadding(context),
                    ),
                    children: [
                      for (final tag in _orderedTags())
                        ListItem(
                          label: labels[tag.key] ?? tag.key,
                          value: tag.value,
                          isLink: PoiDetails.isWebUrl(tag.value),
                          onTap: PoiDetails.isWebUrl(tag.value)
                              ? () => launchUrlString(tag.value)
                              : null,
                        ),
                      if (details.osmUrl case final osmUrl?)
                        ListItem(
                          label: 'OpenStreetMap',
                          value: english
                              ? 'View on OpenStreetMap'
                              : 'Auf OpenStreetMap ansehen',
                          isLink: true,
                          onTap: () => launchUrlString(osmUrl),
                        ),
                      ListItem(
                        label:
                            english ? 'Edit OSM yourself' : 'OSM selbst ändern',
                        value: 'EveryDoor',
                        isLink: true,
                        onTap: () => launchUrlString('https://every-door.app/'),
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
}
