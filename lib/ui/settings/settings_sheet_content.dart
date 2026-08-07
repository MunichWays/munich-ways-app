import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_locale_controller.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/ui/map/map_overlay/bikenet_selection_sheet.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/widgets/menu_list.dart';
import 'package:provider/provider.dart';

/// Settings list for the map bottom sheet (no scaffold / drawer).
class SettingsSheetContent extends StatefulWidget {
  const SettingsSheetContent({
    super.key,
    required this.model,
    required this.onReloadRadnetz,
  });

  final MapScreenViewModel model;
  final Future<void> Function() onReloadRadnetz;

  @override
  State<SettingsSheetContent> createState() => _SettingsSheetContentState();
}

class _SettingsSheetContentState extends State<SettingsSheetContent> {
  @override
  Widget build(BuildContext context) {
    final model = widget.model;

    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final strings = context.l10n;
        final localeController = context.watch<AppLocaleController>();
        return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 32,
              children: [
                MenuGroup(
                  children: [
                    MenuGroupItem(
                      label: strings.bRouterShortest,
                      trailingElement: Switch.adaptive(
                        value: model.shortestRouteEnabled,
                        onChanged: model.setShortestRouteEnabled,
                      ),
                    ),
                    const MenuGroupDivider(),
                    MenuGroupItem(
                      label: strings.showZoomButtons,
                      trailingElement: Switch.adaptive(
                        value: model.showZoomButtons,
                        onChanged: model.setShowZoomButtons,
                      ),
                    ),
                    const MenuGroupDivider(),
                    MenuGroupItem(
                      label: strings.positionMapButtons,
                      trailingElement: DropdownButtonHideUnderline(
                        child: DropdownButton<MapSidePanelEdge>(
                          value: model.sidePanelEdge,
                          alignment: AlignmentDirectional.centerEnd,
                          isDense: true,
                          items: [
                            DropdownMenuItem(
                              value: MapSidePanelEdge.left,
                              child: Text(strings.left),
                            ),
                            DropdownMenuItem(
                              value: MapSidePanelEdge.right,
                              child: Text(strings.right),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) model.setSidePanelEdge(v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                MenuGroup(
                  children: [
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        title: Text(strings.moreSettings),
                        children: [
                          const MenuGroupDivider(),
                          _RouteRecommendationSettings(
                            model: model,
                            strings: strings,
                          ),
                          const MenuGroupDivider(),
                          MenuGroupItem(
                            label: strings.language,
                            trailingElement: DropdownButtonHideUnderline(
                              child: DropdownButton<AppLanguage>(
                                value: localeController.language,
                                alignment: AlignmentDirectional.centerEnd,
                                isDense: true,
                                items: [
                                  DropdownMenuItem(
                                    value: AppLanguage.system,
                                    child: _LanguageSymbol(
                                      symbol: '🌐',
                                      semanticsLabel: strings.systemLanguage,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: AppLanguage.german,
                                    child: _LanguageSymbol(
                                      symbol: '🇩🇪',
                                      semanticsLabel: strings.german,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: AppLanguage.english,
                                    child: _LanguageSymbol(
                                      symbol: '🇬🇧',
                                      semanticsLabel: strings.english,
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    localeController.setLanguage(value);
                                  }
                                },
                              ),
                            ),
                          ),
                          const MenuGroupDivider(),
                          MenuGroupItem(
                            label: context.l10n.tr('Fahrradnetz auswählen'),
                            trailingElement: Icon(
                              model.isRadlvorrangnetzVisible &&
                                      model.isGesamtnetzVisible
                                  ? Icons.layers
                                  : Icons.layers_clear,
                            ),
                            onTap: () => showModalBottomSheet<void>(
                              context: context,
                              useSafeArea: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) =>
                                  BikenetSelectionSheet(model: model),
                            ),
                          ),
                          const MenuGroupDivider(),
                          MenuGroupItem(
                            label: strings.reloadNetwork,
                            trailingElement: const Icon(Icons.refresh),
                            onTap: () async {
                              Navigator.of(context).pop();
                              await widget.onReloadRadnetz();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ));
      },
    );
  }
}

class _RouteRecommendationSettings extends StatelessWidget {
  const _RouteRecommendationSettings({
    required this.model,
    required this.strings,
  });

  final MapScreenViewModel model;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Row(
          children: [
            Expanded(child: Text(strings.routeRecommendation)),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '${strings.tr('Info')}: ${strings.routeRecommendation}',
              onPressed: () => _showOverviewInfo(context),
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
        subtitle: model.routeRecommendation == null
            ? null
            : Text(_label(model.routeRecommendation!)),
        children: [
          const MenuGroupDivider(),
          for (final recommendation in RouteRecommendation.values) ...[
            _RadioMenuItem<RouteRecommendation>(
              title: _label(recommendation),
              value: recommendation,
              groupValue: model.routeRecommendation,
              onChanged: model.setRouteRecommendation,
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '${strings.tr('Info')}: ${_label(recommendation)}',
                onPressed: () => _showInfo(context, recommendation),
                icon: const Icon(Icons.info_outline),
              ),
            ),
            if (recommendation != RouteRecommendation.values.last)
              const MenuGroupDivider(),
          ],
        ],
      ),
    );
  }

  String _label(RouteRecommendation recommendation) => switch (recommendation) {
        RouteRecommendation.standard => strings.standardRoute,
        RouteRecommendation.trekking => strings.bRouterTrekking,
        RouteRecommendation.roadBike => strings.bRouterFastBike,
        RouteRecommendation.shortest => strings.bRouterShortest,
        RouteRecommendation.aloneAfterDark => strings.aloneAfterDark,
        RouteRecommendation.hotWeather => strings.hotWeather,
        RouteRecommendation.snowAndMud => strings.snowAndMud,
      };

  void _showOverviewInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.routeRecommendation),
        content: SingleChildScrollView(child: Text(strings.routePlanningInfo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, RouteRecommendation recommendation) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_label(recommendation)),
        content: Text(strings.routeRecommendationInfo(recommendation)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }
}

class _RadioMenuItem<T> extends StatelessWidget {
  const _RadioMenuItem({
    required this.title,
    this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final T value;
  final T? groupValue;
  final ValueChanged<T> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: RadioListTile<T>(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        secondary: trailing,
        value: value,
        // Keep compatibility with the older Flutter SDK used by CI.
        // ignore: deprecated_member_use
        groupValue: groupValue,
        // ignore: deprecated_member_use
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class _LanguageSymbol extends StatelessWidget {
  const _LanguageSymbol({
    required this.symbol,
    required this.semanticsLabel,
  });

  final String symbol;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Text(symbol, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
