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
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: RawMaterialButton(
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (BuildContext context) {
                              return StatefulBuilder(
                                builder: (context, StateSetter setModalState) {
                                  return Container(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16.0, 8, 16, 0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Fahrradnetz auswählen",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headline6,
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.close),
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                              ),
                                            ],
                                          ),
                                        ),
                                        CheckboxListTile(
                                          title: Text("Radvorrangnetz"),
                                          value: model.isRadlvorrangnetzVisible,
                                          onChanged: (bool value) {
                                            model.toggleRadvorrangnetzVisible();
                                            setModalState(() {});
                                          },
                                        ),
                                        CheckboxListTile(
                                          title: Text("Gesamtnetz"),
                                          value: model.isGesamtnetzVisible,
                                          onChanged: (bool value) {
                                            model.toggleGesamtnetzVisible();
                                            setModalState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                        elevation: 2.0,
                        fillColor: Colors.white,
                        constraints:
                            BoxConstraints.expand(width: 56, height: 56),
                        child: Icon(
                          Icons.layers,
                          color: Colors.black54,
                        ),
                        padding: EdgeInsets.all(15.0),
                        shape: CircleBorder(),
                      ),
                    ),
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
