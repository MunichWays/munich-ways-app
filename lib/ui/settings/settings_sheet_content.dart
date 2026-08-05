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
                          _RoutingSettings(model: model, strings: strings),
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

class _RoutingSettings extends StatelessWidget {
  const _RoutingSettings({
    required this.model,
    required this.strings,
  });

  final MapScreenViewModel model;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final profileLabel = switch (model.bRouterProfile) {
      BRouterProfile.trekking => strings.bRouterTrekking,
      BRouterProfile.fastBike => strings.bRouterFastBike,
      BRouterProfile.shortest => strings.bRouterShortest,
    };
    final modeLabel = model.routingMode == RoutingMode.automatic
        ? strings.routingAutomatic
        : strings.routingBRouterEverywhere;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.only(left: 16, right: 8),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Row(
          children: [
            Expanded(child: Text(strings.routePlanning)),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip:
                  '${AppLocalizations.of(context).tr('Info')}: ${strings.routePlanning}',
              onPressed: () => _showRoutingInfo(context),
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
        subtitle: Text('$modeLabel · $profileLabel'),
        children: [
          const MenuGroupDivider(),
          _RadioMenuItem<RoutingMode>(
            title: strings.routingAutomatic,
            subtitle: strings.routingAutomaticDescription,
            value: RoutingMode.automatic,
            groupValue: model.routingMode,
            onChanged: model.setRoutingMode,
          ),
          const MenuGroupDivider(),
          _RadioMenuItem<RoutingMode>(
            title: strings.routingBRouterEverywhere,
            value: RoutingMode.bRouterEverywhere,
            groupValue: model.routingMode,
            onChanged: model.setRoutingMode,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip:
                  '${AppLocalizations.of(context).tr('Info')}: ${strings.routingBRouterEverywhere}',
              onPressed: () => _showBRouterInfo(context),
              icon: const Icon(Icons.info_outline),
            ),
          ),
          const MenuGroupDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                strings.bRouterProfile,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          _RadioMenuItem<BRouterProfile>(
            title: strings.bRouterTrekking,
            value: BRouterProfile.trekking,
            groupValue: model.bRouterProfile,
            onChanged: model.setBRouterProfile,
          ),
          _RadioMenuItem<BRouterProfile>(
            title: strings.bRouterFastBike,
            value: BRouterProfile.fastBike,
            groupValue: model.bRouterProfile,
            onChanged: model.setBRouterProfile,
          ),
          _RadioMenuItem<BRouterProfile>(
            title: strings.bRouterShortest,
            value: BRouterProfile.shortest,
            groupValue: model.bRouterProfile,
            onChanged: model.setBRouterProfile,
          ),
        ],
      ),
    );
  }

  void _showRoutingInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.routePlanning),
        content: SingleChildScrollView(
          child: Text(strings.routePlanningInfo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }

  void _showBRouterInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('BRouter'),
        content: Text(strings.bRouterGuidanceInfo),
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
  final T groupValue;
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
