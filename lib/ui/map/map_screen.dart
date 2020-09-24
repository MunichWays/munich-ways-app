import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/side_drawer.dart';
import 'package:provider/provider.dart';

import 'map_app_bar.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const STACHUS = [48.14, 11.5652];

  GoogleMapController mapController;
  final LatLng _center = LatLng(STACHUS[0], STACHUS[1]);

  void initState() {}

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MapScreenViewModel>(
      create: (BuildContext context) {
        return MapScreenViewModel();
      },
      child: Consumer<MapScreenViewModel>(
        builder: (context, model, child) {
          return Scaffold(
            drawer: SideDrawer(),
            body: SafeArea(
              child: Stack(
                children: [
                  GoogleMap(
                    polylines: model.polylines,
                    myLocationButtonEnabled: true,
                    myLocationEnabled: false,
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      zoom: 14.0,
                    ),
                    mapType: MapType.normal,
                    mapToolbarEnabled: true,
                    zoomControlsEnabled: false,
                  ),
                  MapAppBar(
                    actions: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        tooltip: 'Legende',
                        onPressed: () {
                          //TODO display legende or infos about munichways map
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
    });
  }
}
