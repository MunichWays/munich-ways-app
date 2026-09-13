import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/map_overlay/map_route_comfort_summary.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

/// Presentation-only folding; route, speech and navigation state stay in the model.
class MapRouteStartPanel extends StatefulWidget {
  const MapRouteStartPanel(
      {super.key, required this.model, required this.builder});
  final MapScreenViewModel model;
  final Widget Function(bool collapsed, VoidCallback? toggle) builder;

  @override
  State<MapRouteStartPanel> createState() => _MapRouteStartPanelState();
}

class _MapRouteStartPanelState extends State<MapRouteStartPanel> {
  bool _collapsed = false;
  double _dragDistance = 0;
  Object? _destination;
  bool get _canCollapse {
    if (widget.model.navigationStarted) {
      return widget.model.destination != null;
    }
    return widget.model.routeStart == null &&
        widget.model.route.route != null &&
        widget.model.route.state == MapRouteState.SHOWN;
  }

  @override
  void initState() {
    super.initState();
    _destination = widget.model.destination;
  }

  @override
  void didUpdateWidget(covariant MapRouteStartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canCollapse || !identical(_destination, widget.model.destination)) {
      _collapsed = false;
    }
    _destination = widget.model.destination;
  }

  void _setCollapsed(bool value) {
    if (!_canCollapse || _collapsed == value) return;
    setState(() => _collapsed = value);
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = _canCollapse && _collapsed;
    return GestureDetector(
      onVerticalDragStart: _canCollapse ? (_) => _dragDistance = 0 : null,
      onVerticalDragUpdate:
          _canCollapse ? (details) => _dragDistance += details.delta.dy : null,
      onVerticalDragEnd: _canCollapse
          ? (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (_dragDistance > 20 || velocity > 300) _setCollapsed(true);
              if (_dragDistance < -20 || velocity < -300) _setCollapsed(false);
            }
          : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_canCollapse)
          Material(
            key: const ValueKey('route-panel-handle'),
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: const BottomSheetDragHandle(),
          ),
        if (!collapsed)
          MapRouteComfortSummary(model: widget.model, compact: true),
        widget.builder(
            collapsed, _canCollapse ? () => _setCollapsed(!collapsed) : null),
      ]),
    );
  }
}
