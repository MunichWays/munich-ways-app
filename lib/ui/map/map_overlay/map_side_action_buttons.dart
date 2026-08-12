import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/map/map_overlay/map_compass_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
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
        children: [
          ...zoomWidgets,
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
              LocationState.NOT_AVAILABLE =>
                const Icon(Icons.location_searching),
              LocationState.DISPLAY ||
              LocationState.FOLLOW =>
                const Icon(Icons.my_location),
              LocationState.FOLLOW_AND_ROTATE_MAP =>
                const Icon(MunichwaysIcons.compass),
            },
          ),
        ],
      ),
    );
  }
}
