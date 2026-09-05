import 'dart:async';

import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/place_search/place_search_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:url_launcher/url_launcher.dart';

enum _SavedPlaceAction { toggleFavorite, delete, rename }

enum _SavedRouteAction { toggleFavorite, rename, delete }

/// Scrollable search results, errors, and recent destinations.
class PlaceSearchBody extends StatefulWidget {
  const PlaceSearchBody({
    super.key,
    required this.model,
    this.showSavedRoutes = true,
    this.showFavorites = true,
    this.showRecentSearches = true,
    this.scrollController,
    this.onSelected,
  });

  final PlaceSearchScreenViewModel model;
  final bool showSavedRoutes;
  final bool showFavorites;
  final bool showRecentSearches;
  final ScrollController? scrollController;
  final ValueChanged<Object>? onSelected;

  void _completeSelection(BuildContext context, Object selection) {
    final callback = onSelected;
    if (callback != null) {
      callback(selection);
    } else {
      Navigator.pop(context, selection);
    }
  }

  @override
  State<PlaceSearchBody> createState() => _PlaceSearchBodyState();
}

class _PlaceSearchBodyState extends State<PlaceSearchBody> {
  PlaceSearchScreenViewModel get model => widget.model;

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
      children.addAll(_savedPlaceWidgets(context, model));
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
              widget._completeSelection(context, place);
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
      }
      children.addAll(_savedPlaceWidgets(context, model));
    }

    final results = ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
    final content = showAttribution
        ? Column(
            children: [
              Expanded(child: results),
              _buildAttribution(context),
            ],
          )
        : results;
    return content;
  }

  Widget _buildAttribution(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    final provider = model.resultsFromNominatim ? 'Nominatim' : 'Geoapify';
    final providerUrl = model.resultsFromNominatim
        ? 'https://nominatim.org/'
        : 'https://www.geoapify.com/';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Powered by', style: style),
          Semantics(
            link: true,
            label: provider,
            excludeSemantics: true,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tapTargetSize: MaterialTapTargetSize.padded,
                textStyle: style?.copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
              onPressed: () => launchUrl(
                Uri.parse(providerUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(provider),
            ),
          ),
          Text(
            context.l10n.isEnglish
                ? ' · © OpenStreetMap contributors · © City of Munich'
                : ' · © OpenStreetMap-Mitwirkende · © Stadt München',
            style: style,
          ),
        ],
      ),
    );
  }

  List<Widget> _savedPlaceWidgets(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    return [
      if (widget.showFavorites) ..._favoriteWidgets(context, model),
      if (widget.showRecentSearches) ..._recentSearchWidgets(context, model),
      ..._savedRouteWidgets(context, model),
    ];
  }

  Widget _savedSection(
    BuildContext context, {
    required String keyName,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      key: PageStorageKey<String>(keyName),
      initiallyExpanded: true,
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      minTileHeight: 48,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      children: children,
    );
  }

  List<Widget> _favoriteWidgets(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    final favorites = widget.showSavedRoutes
        ? model.favoriteItems
        : model.favoriteItems.whereType<Place>().toList();
    if (favorites.isEmpty) return [];
    return [
      _savedSection(
        context,
        keyName: 'favorites',
        title: context.l10n.isEnglish ? 'Favorites' : 'Favoriten',
        icon: Icons.star,
        iconColor: Colors.amber,
        children: [
          for (final favorite in favorites)
            _favoriteItem(context, model, favorite),
        ],
      ),
    ];
  }

  Widget _favoriteItem(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Object favorite,
  ) {
    final item = favorite is Place
        ? _savedPlaceTile(
            context,
            favorite,
            highlighted: true,
            compact: true,
            onConfirm: () => _selectPlace(context, model, favorite),
          )
        : _savedRouteTile(context, model, favorite as SavedRoute);
    return KeyedSubtree(
      key: ValueKey(favorite is Place
          ? 'place-${favorite.latLng.latitude}-${favorite.latLng.longitude}'
          : 'route-${(favorite as SavedRoute).name}'),
      child: item,
    );
  }

  Future<void> _renameFavorite(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place favorite,
  ) async {
    var name = favorite.displayName ?? '';
    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.l10n.isEnglish ? 'Rename favorite' : 'Favorit umbenennen',
        ),
        content: TextFormField(
          initialValue: name,
          autofocus: true,
          onChanged: (value) => name = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.tr('Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, name),
            child: Text(
              context.l10n.isEnglish ? 'Save' : 'Speichern',
            ),
          ),
        ],
      ),
    );
    final trimmedName = updatedName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) return;
    await model.renameFavorite(favorite, trimmedName);
  }

  List<Widget> _recentSearchWidgets(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    if (model.recentSearches.isEmpty) return [];
    return [
      _savedSection(
        context,
        keyName: 'recent-destinations',
        title: context.l10n.tr('Letzte Ziele'),
        icon: Icons.history,
        iconColor: AppColors.munichWaysBlue,
        children: [
          for (final recentSearch in model.recentSearches)
            _savedPlaceTile(
              context,
              recentSearch,
              highlighted: false,
              compact: true,
              onConfirm: () => _selectPlace(context, model, recentSearch),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: model.clearAllRecentSearches,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(context.l10n.tr('(Suchverlauf löschen)')),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _savedRouteWidgets(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    if (!widget.showSavedRoutes || model.savedRoutes.isEmpty) return [];
    return [
      _savedSection(
        context,
        keyName: 'saved-routes',
        title: context.l10n.isEnglish ? 'Routes' : 'Routen',
        icon: Icons.route,
        iconColor: AppColors.munichWaysOrange,
        children: [
          for (final route in model.savedRoutes)
            _savedRouteTile(context, model, route),
        ],
      ),
    ];
  }

  Widget _savedRouteTile(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    SavedRoute route,
  ) {
    final menuKey = GlobalKey<PopupMenuButtonState<_SavedRouteAction>>();
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      minTileHeight: 48,
      tileColor: route.isFavorite
          ? AppColors.favoriteHighlightFor(context)
          : Colors.transparent,
      contentPadding: const EdgeInsets.only(left: 4, right: 4),
      title: LayoutBuilder(
        builder: (context, constraints) {
          final textStyle = Theme.of(context).textTheme.bodyLarge;
          final textPainter = TextPainter(
            text: TextSpan(text: route.name, style: textStyle),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final nameIsTruncated = textPainter.didExceedMaxLines;
          return Row(
            children: [
              Expanded(
                child: Text(
                  route.name,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: textStyle,
                ),
              ),
              if (nameIsTruncated)
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    tooltip: context.l10n.isEnglish
                        ? 'Show full route name'
                        : 'Vollständigen Routennamen anzeigen',
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                              : route.isFavorite
                                  ? AppColors.favoriteHighlight
                                  : Colors.white,
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.primary
                              : AppColors.uiPrimary,
                      fixedSize: const Size.square(24),
                      shape: const CircleBorder(),
                    ),
                    onPressed: () => _showFullRouteName(context, route),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
            ],
          );
        },
      ),
      onTap: () => widget._completeSelection(context, route),
      onLongPress: () => menuKey.currentState?.showButtonMenu(),
      trailing: SizedBox.square(
        dimension: 48,
        child: PopupMenuButton<_SavedRouteAction>(
          key: menuKey,
          tooltip: context.l10n.isEnglish ? 'More options' : 'Mehr Optionen',
          padding: EdgeInsets.zero,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _SavedRouteAction.toggleFavorite,
              onTap: () => unawaited(
                _handleSavedRouteAction(
                    context, model, route, _SavedRouteAction.toggleFavorite),
              ),
              child: Row(
                children: [
                  Icon(route.isFavorite ? Icons.star : Icons.star_border),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      route.isFavorite
                          ? (context.l10n.isEnglish
                              ? 'Remove favorite'
                              : 'Favorit entfernen')
                          : (context.l10n.isEnglish
                              ? 'Add favorite'
                              : 'Als Favorit speichern'),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: _SavedRouteAction.rename,
              onTap: () => unawaited(
                _handleSavedRouteAction(
                    context, model, route, _SavedRouteAction.rename),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined),
                  const SizedBox(width: 12),
                  Flexible(
                    child:
                        Text(context.l10n.isEnglish ? 'Rename' : 'Umbenennen'),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: _SavedRouteAction.delete,
              onTap: () => unawaited(
                _handleSavedRouteAction(
                    context, model, route, _SavedRouteAction.delete),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(context.l10n.isEnglish ? 'Delete' : 'Löschen'),
                  ),
                ],
              ),
            ),
          ],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => menuKey.currentState?.showButtonMenu(),
            child: const Icon(Icons.more_vert, size: 20),
          ),
        ),
      ),
    );
  }

  Future<void> _renameSavedRoute(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    SavedRoute route,
  ) async {
    var name = route.name;
    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(context.l10n.isEnglish ? 'Rename route' : 'Route umbenennen'),
        content: TextFormField(
          initialValue: name,
          autofocus: true,
          onChanged: (value) => name = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.tr('Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, name),
            child: Text(context.l10n.isEnglish ? 'Save' : 'Speichern'),
          ),
        ],
      ),
    );
    final trimmedName = updatedName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) return;
    await model.renameSavedRoute(route, trimmedName);
  }

  Future<void> _handleSavedRouteAction(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    SavedRoute route,
    _SavedRouteAction action,
  ) async {
    switch (action) {
      case _SavedRouteAction.toggleFavorite:
        await _toggleRouteFavorite(context, model, route);
      case _SavedRouteAction.rename:
        await _renameSavedRoute(context, model, route);
      case _SavedRouteAction.delete:
        await _confirmDeleteSavedRoute(context, model, route);
    }
  }

  Future<void> _toggleRouteFavorite(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    SavedRoute route,
  ) async {
    if (!route.isFavorite && model.favoriteCount >= 3) {
      final replaced = await _chooseFavoriteToReplace(context, model);
      if (replaced == null) return;
      await model.replaceFavorite(replaced, route);
      return;
    }
    await model.toggleRouteFavorite(route);
  }

  Future<void> _confirmDeleteSavedRoute(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    SavedRoute route,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              context.l10n.isEnglish ? 'Delete saved route?' : 'Route löschen?',
            ),
            content: Text(route.name),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.tr('Abbrechen')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.isEnglish ? 'Delete' : 'Löschen'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await model.deleteSavedRoute(route);
  }

  Future<void> _renameRecentSearch(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place recentSearch,
  ) async {
    var name = recentSearch.displayName ?? '';
    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.l10n.isEnglish ? 'Rename destination' : 'Ziel umbenennen',
        ),
        content: TextFormField(
          initialValue: name,
          autofocus: true,
          onChanged: (value) => name = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.tr('Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, name),
            child: Text(context.l10n.isEnglish ? 'Save' : 'Speichern'),
          ),
        ],
      ),
    );
    final trimmedName = updatedName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) return;
    await model.renameRecentSearch(recentSearch, trimmedName);
  }

  Widget _savedPlaceTile(
    BuildContext context,
    Place place, {
    required bool highlighted,
    required bool compact,
    required VoidCallback onConfirm,
  }) {
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final actionWidth = compact ? 32.0 : 48.0;
    final menuKey = GlobalKey<PopupMenuButtonState<_SavedPlaceAction>>();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 0 : 1),
      child: Material(
        color: highlighted
            ? AppColors.favoriteHighlightFor(context)
            : Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final baseTrailingWidth = actionWidth;
            final initialTextWidth =
                constraints.maxWidth - 16 - baseTrailingWidth;
            final initialTextPainter = TextPainter(
              text: TextSpan(text: place.displayName!, style: textStyle),
              maxLines: 1,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(
                maxWidth: initialTextWidth > 0 ? initialTextWidth : 0,
              );
            final addressIsTruncated = initialTextPainter.didExceedMaxLines;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 8,
                vertical: compact ? 4 : 5,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onConfirm,
                      onLongPress: () => menuKey.currentState?.showButtonMenu(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: 48,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            place.displayName!,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: textStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (addressIsTruncated)
                    _compactAction(
                      compact: compact,
                      child: IconButton(
                        tooltip: context.l10n.isEnglish
                            ? 'Show full address'
                            : 'Vollständige Adresse anzeigen',
                        iconSize: compact ? 16 : 18,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                  : highlighted
                                      ? AppColors.favoriteHighlight
                                      : Colors.white,
                          foregroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).colorScheme.primary
                                  : AppColors.uiPrimary,
                          fixedSize: Size.square(compact ? 24 : 28),
                          shape: const CircleBorder(),
                        ),
                        onPressed: () => _showFullAddress(context, place),
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ),
                  _compactAction(
                    compact: compact,
                    child: PopupMenuButton<_SavedPlaceAction>(
                      key: menuKey,
                      tooltip: context.l10n.isEnglish
                          ? 'More options'
                          : 'Mehr Optionen',
                      padding:
                          compact ? EdgeInsets.zero : const EdgeInsets.all(8),
                      itemBuilder: (context) => _savedPlaceMenuItems(
                        context,
                        isFavorite: model.isFavorite(place),
                        onAction: (action) => _scheduleSavedPlaceAction(
                          model,
                          place,
                          action,
                        ),
                      ),
                      child: SizedBox.expand(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          excludeFromSemantics: true,
                          onTap: () => menuKey.currentState?.showButtonMenu(),
                          onLongPress: () =>
                              menuKey.currentState?.showButtonMenu(),
                          child: Center(
                            child: Icon(
                              Icons.more_vert,
                              size: compact ? 20 : 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _compactAction({
    required bool compact,
    required Widget child,
  }) {
    if (!compact) return child;
    return SizedBox.square(dimension: 48, child: child);
  }

  List<PopupMenuEntry<_SavedPlaceAction>> _savedPlaceMenuItems(
    BuildContext context, {
    required bool isFavorite,
    required ValueChanged<_SavedPlaceAction> onAction,
  }) {
    final english = context.l10n.isEnglish;
    return [
      PopupMenuItem(
        value: _SavedPlaceAction.toggleFavorite,
        onTap: () => onAction(_SavedPlaceAction.toggleFavorite),
        child: Row(
          children: [
            Icon(isFavorite ? Icons.star : Icons.star_border),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                isFavorite
                    ? (english ? 'Remove favorite' : 'Favorit entfernen')
                    : (english ? 'Add favorite' : 'Als Favorit speichern'),
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem(
        value: _SavedPlaceAction.delete,
        onTap: () => onAction(_SavedPlaceAction.delete),
        child: Row(
          children: [
            Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(english ? 'Delete' : 'Löschen')),
          ],
        ),
      ),
      PopupMenuItem(
        value: _SavedPlaceAction.rename,
        onTap: () => onAction(_SavedPlaceAction.rename),
        child: Row(
          children: [
            const Icon(Icons.edit_outlined),
            const SizedBox(width: 12),
            Flexible(child: Text(english ? 'Rename' : 'Umbenennen')),
          ],
        ),
      ),
    ];
  }

  Future<void> _handleSavedPlaceAction(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place place,
    _SavedPlaceAction action,
  ) async {
    switch (action) {
      case _SavedPlaceAction.delete:
        await _confirmDelete(context, model, place);
        break;
      case _SavedPlaceAction.rename:
        if (model.isFavorite(place)) {
          await _renameFavorite(context, model, place);
        } else {
          await _renameRecentSearch(context, model, place);
        }
        break;
      case _SavedPlaceAction.toggleFavorite:
        await _toggleSelectedFavorite(context, model, place);
        break;
    }
  }

  Future<void> _showFullAddress(BuildContext context, Place place) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.l10n.isEnglish ? 'Full address' : 'Vollständige Adresse',
        ),
        content: SelectableText(place.displayName ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.isEnglish ? 'Close' : 'Schließen'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFullRouteName(BuildContext context, SavedRoute route) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.l10n.isEnglish
              ? 'Full route name'
              : 'Vollständiger Routenname',
        ),
        content: SelectableText(route.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.isEnglish ? 'Close' : 'Schließen'),
          ),
        ],
      ),
    );
  }

  void _scheduleSavedPlaceAction(
    PlaceSearchScreenViewModel model,
    Place place,
    _SavedPlaceAction action,
  ) {
    if (!mounted) return;
    unawaited(_handleSavedPlaceAction(context, model, place, action));
  }

  Future<void> _toggleSelectedFavorite(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place place,
  ) async {
    if (!model.isFavorite(place) && model.favoriteCount >= 3) {
      final replaced = await _chooseFavoriteToReplace(context, model);
      if (replaced != null) await model.replaceFavorite(replaced, place);
      return;
    }
    if (!model.isFavorite(place) && model.favoritePlaces.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isEnglish
                ? 'A maximum of three favorites is possible.'
                : 'Es sind maximal drei Favoriten möglich.',
          ),
        ),
      );
      return;
    }
    await model.toggleFavorite(place);
  }

  Future<Object?> _chooseFavoriteToReplace(
    BuildContext context,
    PlaceSearchScreenViewModel model,
  ) {
    String name(Object favorite) => switch (favorite) {
          Place place => place.displayName ?? '',
          SavedRoute route => route.name,
          _ => '',
        };
    return showDialog<Object>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          context.l10n.isEnglish
              ? 'Replace a favorite?'
              : 'Favoriten ersetzen?',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              context.l10n.isEnglish
                  ? 'A maximum of three favorites is possible.'
                  : 'Es sind maximal drei Favoriten möglich.',
            ),
          ),
          for (final favorite in model.favoriteItems)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, favorite),
              child: Row(
                children: [
                  Icon(favorite is SavedRoute ? Icons.route : Icons.place),
                  const SizedBox(width: 12),
                  Expanded(child: Text(name(favorite))),
                ],
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.tr('Abbrechen')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place place,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              context.l10n.isEnglish ? 'Delete destination?' : 'Ziel löschen?',
            ),
            content: Text(place.displayName ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.tr('Abbrechen')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.isEnglish ? 'Delete' : 'Löschen'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await model.deleteSavedPlace(place);
  }

  void _selectPlace(
    BuildContext context,
    PlaceSearchScreenViewModel model,
    Place place,
  ) {
    model.addToRecentSearches(place);
    widget._completeSelection(context, place);
  }
}
