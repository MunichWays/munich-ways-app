import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/map/map_overlay/map_compass_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/map_overlay/bikenet_selection_sheet.dart';
import 'package:munich_ways/ui/icons/munichways_icons_icons.dart';

/// Side map controls: zoom and compass.
class MapSideActionButtons extends StatelessWidget {
  const MapSideActionButtons({
    super.key,
    required this.model,
    required this.mapController,
    required this.mapBearingDegrees,
    required this.compassIdleTick,
    required this.onNorthUp,
    required this.queryMapBearingDegrees,
    required this.onPressLocation,
    this.bottomActionRowPadding = kMapBottomActionRowCollapsedPadding,
    this.additionalBottomOffset = 0,
    this.onShowMaps,
  });

  final MapScreenViewModel model;
  final MapLibreMapController? mapController;
  final ValueNotifier<double> mapBearingDegrees;
  final ValueNotifier<int> compassIdleTick;
  final Future<void> Function() onNorthUp;
  final Future<double?> Function() queryMapBearingDegrees;
  final VoidCallback onPressLocation;
  final double bottomActionRowPadding;
  final double additionalBottomOffset;
  final VoidCallback? onShowMaps;

  static const double _buttonSpacing = 10;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.paddingOf(context);
    final bottomBarBottom = mq.bottom + bottomActionRowPadding;
    final sideColumnBottom = bottomBarBottom +
        kMapGapSideColumnAboveBottomBar +
        additionalBottomOffset;

    final zoomWidgets = <Widget>[
      if (model.showZoomButtons) ...[
        MapOverlayButton(
          tooltip: context.l10n.tr('Vergrößern'),
          size: 40,
          tapTargetSize: 56,
          onPressed: () {
            final c = mapController;
            if (c == null) return;
            c.animateCamera(CameraUpdate.zoomIn());
          },
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: _buttonSpacing),
        MapOverlayButton(
          tooltip: context.l10n.tr('Verkleinern'),
          size: 40,
          tapTargetSize: 56,
          onPressed: () {
            final c = mapController;
            if (c == null) return;
            c.animateCamera(CameraUpdate.zoomOut());
          },
          child: const Icon(Icons.remove),
        ),
        const SizedBox(height: _buttonSpacing),
      ],
    ];

    final showMap = model.showMapButton && model.canChangeMapBackground;
    final zoomAndMapWidgets = <Widget>[
      ...zoomWidgets,
      if (showMap) ...[
        MapOverlayButton(
          tooltip: context.l10n.isEnglish ? 'Choose map' : 'Karte auswählen',
          size: 40,
          tapTargetSize: 56,
          onPressed: onShowMaps ?? () => showMapLayersSheet(context, model),
          child: const Icon(Icons.layers_outlined),
        ),
        const SizedBox(height: _buttonSpacing),
      ],
    ];
    // Keep the controls accessible in short windows without shrinking
    // touch targets or hiding the user's zoom buttons.
    final compact = showMap &&
        model.showZoomButtons &&
        MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                sideColumnBottom <
            312;
    final followingWidgets = <Widget>[
      MapCompassOverlayButton(
        mapBearingDegrees: mapBearingDegrees,
        mapIdleTick: compassIdleTick,
        locationState: model.locationState,
        onNorthUp: onNorthUp,
        queryMapBearingDegrees: queryMapBearingDegrees,
        alwaysVisible: true,
      ),
      const SizedBox(height: _buttonSpacing),
      MapOverlayButton(
        tooltip: context.l10n.tr('Standort'),
        size: 40,
        tapTargetSize: 56,
        isActive: model.locationState == LocationState.FOLLOW ||
            model.locationState == LocationState.FOLLOW_AND_ROTATE_MAP,
        emphasizeActive: true,
        onPressed: onPressLocation,
        child: switch (model.locationState) {
          LocationState.NOT_AVAILABLE => const Icon(Icons.location_searching),
          LocationState.DISPLAY ||
          LocationState.FOLLOW =>
            const Icon(Icons.my_location),
          LocationState.FOLLOW_AND_ROTATE_MAP =>
            const Icon(MunichwaysIcons.compass),
        },
      ),
    ];

    return Positioned(
      left: model.sidePanelEdge == MapSidePanelEdge.left
          ? kMapHorizontalHolderClearance
          : null,
      right: model.sidePanelEdge == MapSidePanelEdge.right
          ? kMapHorizontalHolderClearance
          : null,
      bottom: sideColumnBottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: model.sidePanelEdge == MapSidePanelEdge.left
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          if (compact)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: zoomAndMapWidgets.sublist(
                      0, zoomAndMapWidgets.length - 1),
                ),
                const SizedBox(width: _buttonSpacing),
                Column(
                    mainAxisSize: MainAxisSize.min, children: followingWidgets),
              ],
            )
          else ...[
            ...zoomAndMapWidgets,
            ...followingWidgets,
          ],
        ],
      ),
    );
  }
}
