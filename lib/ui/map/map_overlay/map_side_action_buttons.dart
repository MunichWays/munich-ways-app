import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/ui/icons/munichways_icons_icons.dart';
import 'package:munich_ways/ui/map/map_action_buttons/route_button_bar.dart';
import 'package:munich_ways/ui/map/map_overlay/map_compass_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_button.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/sheets/bikenet_selection_sheet.dart';
import 'package:munich_ways/ui/theme.dart';

/// Right-hand map controls: zoom, route visibility, layers, location, compass.
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

    return Positioned(
      right: 12,
      bottom: sideColumnBottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          if (_showRouteToggle(model)) ...[
            const SizedBox(height: _buttonSpacing),
            MapOverlayButton(
              tooltip: model.route.state == MapRouteState.SHOWN
                  ? 'Route ausblenden'
                  : 'Route einblenden',
              isActive: model.route.state == MapRouteState.SHOWN ||
                  model.route.state == MapRouteState.LOADING,
              onPressed: model.route.state == MapRouteState.LOADING
                  ? null
                  : () => model.toggleRoute(),
              child: model.route.state == MapRouteState.LOADING
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.mapAccentColor,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      model.route.state == MapRouteState.HIDDEN
                          ? MunichwaysIcons.route_hidden
                          : Icons.route_outlined,
                    ),
            ),
          ],
          const SizedBox(height: _buttonSpacing),
          MapOverlayButton(
            tooltip: 'Fahrradnetz',
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) => BikenetSelectionSheet(model: model),
              );
            },
            child: Icon(
              model.isGesamtnetzVisible ? Icons.layers : Icons.layers_clear,
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

  bool _showRouteToggle(MapScreenViewModel model) {
    final s = model.route.state;
    return s != MapRouteState.NO_ROUTE && s != MapRouteState.ERROR;
  }

  Widget _locationIcon(LocationState state) {
    switch (state) {
      case LocationState.NOT_AVAILABLE:
        return const Icon(Icons.location_searching, color: Colors.white38);
      case LocationState.DISPLAY:
        return const Icon(Icons.my_location);
      case LocationState.FOLLOW:
      case LocationState.FOLLOW_AND_ROTATE_MAP:
        return Icon(
          state == LocationState.FOLLOW_AND_ROTATE_MAP
              ? MunichwaysIcons.compass
              : Icons.my_location,
        );
    }
  }
}
