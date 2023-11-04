import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:munich_ways/ui/map/map_action_buttons/route_button_bar.dart';
import 'package:munich_ways/ui/theme.dart';

class CurrentPosToDestinationRouteLayer extends StatelessWidget {
  final MapRoute route;

  const CurrentPosToDestinationRouteLayer(this.route, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return route.state == MapRouteState.SHOWN
        ? PolylineLayer(polylines: [
            Polyline(
                points: route.route!.points,
                strokeWidth: 6.0,
                borderColor: AppColors.mapRouteBorderColor,
                borderStrokeWidth: 2.0,
                color: AppColors.mapRouteColor)
          ])
        : Container();
  }
}
