import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_locale_controller.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/widgets/menu_list.dart';
import 'package:provider/provider.dart';

/// Settings list for the map bottom sheet (no scaffold / drawer).
class SettingsSheetContent extends StatefulWidget {
  const SettingsSheetContent({super.key, required this.model});

  final MapScreenViewModel model;

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
                      label: '🌐',
                      labelSemantics: strings.language,
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
                MenuGroup(
                  children: [
                    MenuGroupItem(
                      label: strings.reloadNetwork,
                      trailingElement: const Icon(Icons.refresh),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final message = strings.reloadingMap;
                        Navigator.of(context).pop();
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        final updated = await model.reloadRadnetz();
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                updated
                                    ? strings.mapUpdated
                                    : strings.mapUpdateFailed,
                              ),
                            ),
                          );
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
