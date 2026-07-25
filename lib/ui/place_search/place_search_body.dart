import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/place_search/place_search_result.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Scrollable search results, errors, and recent destinations.
class PlaceSearchBody extends StatelessWidget {
  const PlaceSearchBody({
    super.key,
    required this.model,
  });

  final PlaceSearchScreenViewModel model;

  @override
  Widget build(BuildContext context) {
    if (model.loading) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    final children = <Widget>[];
    var showAttribution = false;
    var mapSelectionAdded = false;

    if (model.errorMsg != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            model.errorMsg!,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
      children.addAll(_recentSearchWidgets(context, model));
    } else if (model.places.isNotEmpty) {
      if (model.correctedQuery case final correctedQuery?) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(context.l10n.isEnglish
                ? 'Corrected to “$correctedQuery”'
                : 'Korrigiert zu „$correctedQuery“'),
          ),
        );
      }
      for (var i = 0; i < model.places.length; i++) {
        if (i > 0) {
          children.add(const Divider(height: 1));
        }
        final place = model.places[i];
        children.add(
          ListTile(
            dense: true,
            leading: Icon(
              Icons.location_on_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              place.displayName!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.black45,
              semanticLabel: context.l10n.selectDestination(place.displayName!),
            ),
            onTap: () {
              model.addToRecentSearches(place);
              Navigator.pop(context, place);
            },
          ),
        );
      }
      showAttribution = true;
    } else {
      if (!model.isFirstSearch) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              context.l10n.tr(
                'Keine Ergebnisse vorhanden.\nBitte überprüfe den Suchbegriff.',
              ),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        );
        children.add(const Divider(height: 1));
        children.add(_mapSelectionWidget(context));
        mapSelectionAdded = true;
      }
      children.addAll(_recentSearchWidgets(context, model));
    }

    if (!mapSelectionAdded) {
      if (children.isNotEmpty) {
        children.add(const Divider(height: 1));
      }
      children.add(_mapSelectionWidget(context));
    }

    final results = ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: children,
    );
    if (!showAttribution) return results;

    return Column(
      children: [
        Expanded(child: results),
        _buildAttribution(context),
      ],
    );
  }

  static const _attributionStyle = TextStyle(
    color: Colors.black45,
    fontSize: 10,
    height: 1.2,
  );

  Widget _buildAttribution(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      color: Theme.of(context).colorScheme.surface,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Powered by ', style: _attributionStyle),
          InkWell(
            onTap: () => launchUrl(
              Uri.parse('https://www.geoapify.com/'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              'Geoapify',
              style: _attributionStyle.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: Colors.black45,
              ),
            ),
          ),
          Text(
            context.l10n.isEnglish
                ? ' · © OpenStreetMap contributors · © City of Munich'
                : ' · © OpenStreetMap-Mitwirkende · © Stadt München',
            style: _attributionStyle,
          ),
        ],
      ),
    );
  }

  Widget _mapSelectionWidget(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: Icon(
        Icons.add_location_alt_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        context.l10n.tr('Auf Karte auswählen'),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      onTap: () => Navigator.pop(
        context,
        PlaceSearchSheetResult.selectOnMap,
      ),
    );
  }

  List<Widget> _recentSearchWidgets(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    if (model.recentSearches.isEmpty) {
      return [];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
        child: Text(
          context.l10n.tr('Letzte Ziele'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      for (final recentSearch in model.recentSearches) ...[
        const Divider(height: 1),
        ListTile(
          dense: true,
          leading: const Icon(Icons.history, color: Colors.black45),
          title: Text(
            recentSearch.displayName!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: Colors.black45,
            semanticLabel:
                context.l10n.selectDestination(recentSearch.displayName!),
          ),
          onTap: () {
            model.addToRecentSearches(recentSearch);
            Navigator.pop(context, recentSearch);
          },
        ),
      ],
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: model.clearAllRecentSearches,
          icon: const Icon(Icons.delete_outline),
          label: Text(context.l10n.tr('(Suchverlauf löschen)')),
        ),
      ),
    ];
  }
}
