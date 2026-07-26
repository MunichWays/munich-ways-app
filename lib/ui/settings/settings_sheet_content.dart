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
                        builder: (context) => BikenetSelectionSheet(
                          model: model,
                        ),
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
                    MenuGroupItem(
                      label: '🌐 ${strings.language}',
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
                  ],
                ),
                _RoutingSettings(
                  model: model,
                  strings: strings,
                ),
                MenuGroup(
                  children: [
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsHeading(
          label: strings.routePlanning,
          onInfo: () => showDialog<void>(
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
          ),
        ),
        const SizedBox(height: 8),
        MenuGroup(
          children: [
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
            ),
          ],
        ),
        const SizedBox(height: 24),
        MenuGroup(
          children: [
            _BRouterProfileDropdown(
              model: model,
              strings: strings,
            ),
          ],
        ),
      ],
    );
  }
}

class _BRouterProfileDropdown extends StatelessWidget {
  const _BRouterProfileDropdown({
    required this.model,
    required this.strings,
  });

  final MapScreenViewModel model;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.bRouterProfile,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            DropdownButtonHideUnderline(
              child: DropdownButton<BRouterProfile>(
                value: model.bRouterProfile,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: BRouterProfile.trekking,
                    child: Text(strings.bRouterTrekking),
                  ),
                  DropdownMenuItem(
                    value: BRouterProfile.fastBike,
                    child: Text(strings.bRouterFastBike),
                  ),
                  DropdownMenuItem(
                    value: BRouterProfile.shortest,
                    child: Text(strings.bRouterShortest),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) model.setBRouterProfile(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading({
    required this.label,
    required this.onInfo,
  });

  final String label;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '${AppLocalizations.of(context).tr('Info')}: $label',
          onPressed: onInfo,
          icon: const Icon(Icons.info_outline),
        ),
      ],
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
  });

  final String title;
  final String? subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: RadioListTile<T>(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
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
