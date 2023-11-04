import 'package:flutter/material.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/icons/munichways_icons_icons.dart';
import 'package:munich_ways/ui/map/map_button_bar.dart';
import 'package:munich_ways/ui/map/search_location/search_location_screen.dart';
import 'package:munich_ways/ui/theme.dart';

import 'map_screen_model.dart';

class MapRoute {
  MapRouteState state = MapRouteState.NO_ROUTE;
  CycleRoute? route = null;

  MapRoute(this.route, this.state);
}

enum MapRouteState { NO_ROUTE, LOADING, ERROR, SHOWN, HIDDEN }

class RouteButtonBar extends StatelessWidget {
  final MapScreenViewModel model;

  const RouteButtonBar({
    Key? key,
    required this.model,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var mapRoute = model.route;

    var routeColor = switch (mapRoute.state) {
      MapRouteState.NO_ROUTE ||
      MapRouteState.HIDDEN ||
      MapRouteState.ERROR =>
        AppColors.disabledMapButton,
      MapRouteState.SHOWN || MapRouteState.LOADING => AppColors.mapAccentColor,
    };

    var routeText = switch (mapRoute.state) {
      MapRouteState.LOADING => "Lade Route ...",
      MapRouteState.SHOWN ||
      MapRouteState.HIDDEN =>
        "${(mapRoute.route!.distance / 1000).toStringAsFixed(2)} km | ${(mapRoute.route!.duration / 60).toStringAsFixed(0)} Min",
      MapRouteState.NO_ROUTE || MapRouteState.ERROR => ""
    };

    return MapButtonBar(children: [
      if (mapRoute.state != MapRouteState.NO_ROUTE &&
          mapRoute.state != MapRouteState.ERROR) ...[
        Material(
          child: InkWell(
              onTap: () {
                model.toggleRoute();
              },
              child: Tooltip(
                message: mapRoute.state == MapRouteState.SHOWN
                    ? "Route ausblenden"
                    : "Route einblenden",
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  child: Row(children: [
                    mapRoute.state == MapRouteState.LOADING
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : Icon(
                            mapRoute.state == MapRouteState.HIDDEN
                                ? MunichwaysIcons.route_hidden
                                : Icons.route_outlined,
                            color: routeColor,
                          ),
                    SizedBox(
                      width: 4,
                    ),
                    Text(
                      routeText,
                      style: TextStyle(color: routeColor),
                    )
                  ]),
                ),
              )),
        ),
        VerticalDivider(
          width: 0.5,
          thickness: 1,
          color: Colors.black26,
        ),
      ],
      Material(
        child: InkWell(
            onTap: () async {
              if (model.destination == null) {
                Place? place = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SearchLocationScreen()),
                ) as Place?;
                model.setDestination(place);
              } else {
                model.clearDestination();
              }
            },
            child: Tooltip(
              message:
                  model.destination != null ? "Ziel löschen" : "Ziel suchen",
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(children: [
                  Icon(
                    model.destination != null ? Icons.search_off : Icons.search,
                    color: model.destination != null
                        ? AppColors.mapAccentColor
                        : AppColors.disabledMapButton,
                  )
                ]),
              ),
            )),
      ),
    ]);
  }
}
