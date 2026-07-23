import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/widgets/menu_list.dart';

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
                      label: 'Zoom-Buttons anzeigen',
                      trailingElement: Switch.adaptive(
                        value: model.showZoomButtons,
                        onChanged: model.setShowZoomButtons,
                      ),
                    ),
                    const MenuGroupDivider(),
                    MenuGroupItem(
                      label: 'Karten-Buttons positionieren',
                      trailingElement: DropdownButtonHideUnderline(
                        child: DropdownButton<MapSidePanelEdge>(
                          value: model.sidePanelEdge,
                          alignment: AlignmentDirectional.centerEnd,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(
                              value: MapSidePanelEdge.left,
                              child: Text('Links'),
                            ),
                            DropdownMenuItem(
                              value: MapSidePanelEdge.right,
                              child: Text('Rechts'),
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
                      label: 'Radnetz neu laden',
                      trailingElement: const Icon(Icons.refresh),
                      onTap: () {
                        model.reloadRadnetz();
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
