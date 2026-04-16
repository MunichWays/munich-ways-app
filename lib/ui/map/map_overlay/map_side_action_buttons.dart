import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/ui/icons/munichways_icons_icons.dart';
import 'package:munich_ways/ui/map/map_overlay/map_compass_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/sheets/bikenet_selection_sheet.dart';

/// Right-hand map controls: zoom, layers, location, compass.
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
  });

  final MapScreenViewModel model;
  final MapLibreMapController? mapController;
  final ValueNotifier<double> mapBearingDegrees;
  final ValueNotifier<int> compassIdleTick;
  final Future<void> Function() onNorthUp;
  final Future<double?> Function() queryMapBearingDegrees;
  final VoidCallback onPressLocation;

  static const double _buttonSpacing = 10;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.paddingOf(context);
    final bottomBarBottom =
        mq.bottom + kMapBottomActionRowPaddingAboveSafeBottom;
    final sideColumnBottom = bottomBarBottom +
        kMapOverlayControlSize +
        kMapGapSideColumnAboveBottomBar;

    final zoomWidgets = <Widget>[
      if (model.showZoomButtons) ...[
        MapOverlayButton(
          tooltip: 'Vergrößern',
          onPressed: () {
            final c = mapController;
            if (c == null) return;
            c.animateCamera(CameraUpdate.zoomIn());
          },
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: _buttonSpacing),
        MapOverlayButton(
          tooltip: 'Verkleinern',
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
      left: model.sidePanelEdge == MapSidePanelEdge.left ? 12 : null,
      right: model.sidePanelEdge == MapSidePanelEdge.right ? 12 : null,
      bottom: sideColumnBottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...zoomWidgets,
          MapOverlayButton(
            tooltip: 'Fahrradnetz',
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => BikenetSelectionSheet(model: model),
              );
            },
            child: Icon(
              model.isRadlvorrangnetzVisible && model.isGesamtnetzVisible
                  ? Icons.layers
                  : Icons.layers_clear,
            ),
          ),
          const SizedBox(height: _buttonSpacing),
          MapOverlayButton(
            tooltip: 'Aktueller Standort',
            isActive: model.locationState == LocationState.FOLLOW ||
                model.locationState == LocationState.FOLLOW_AND_ROTATE_MAP,
            onPressed: onPressLocation,
            child: _locationIcon(model.locationState),
          ),
          const SizedBox(height: _buttonSpacing),
          MapCompassOverlayButton(
            mapBearingDegrees: mapBearingDegrees,
            mapIdleTick: compassIdleTick,
            locationState: model.locationState,
            onNorthUp: onNorthUp,
            queryMapBearingDegrees: queryMapBearingDegrees,
          ),
        ],
      ),
    );
  }

  Widget _locationIcon(LocationState state) {
    switch (state) {
      case LocationState.NOT_AVAILABLE:
        return const Icon(Icons.location_searching, color: Colors.white38);
      case LocationState.DISPLAY:
        return const Icon(Icons.my_location);
      case LocationState.FOLLOW:
        return const Icon(Icons.my_location);
      case LocationState.FOLLOW_AND_ROTATE_MAP:
        return Icon(MunichwaysIcons.compass);
    }
  }
}
