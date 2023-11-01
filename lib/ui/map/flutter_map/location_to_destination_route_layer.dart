import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:munich_ways/model/route.dart' as model;
import 'package:munich_ways/ui/theme.dart';

class CurrentPosToDestinationRouteLayer extends StatelessWidget {
  final model.Route? route;

  const CurrentPosToDestinationRouteLayer({Key? key, this.route})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return route != null
        ? PolylineLayer(polylines: [
            Polyline(
                points: route!.points,
                strokeWidth: 6.0,
                borderColor: AppColors.mapRouteBorderColor,
                borderStrokeWidth: 2.0,
                color: AppColors.mapRouteColor)
          ])
        : Container();
  }
}
