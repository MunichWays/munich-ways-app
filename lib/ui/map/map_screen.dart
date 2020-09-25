import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/side_drawer.dart';
import 'package:provider/provider.dart';

import 'map_app_bar.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final LatLng _stachus = LatLng(48.14, 11.5652);
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log.d("didChangeAppLifecycleState $state");
    if(displayCurrentLocationOnResume && state == AppLifecycleState.resumed) {
      displayCurrentLocationOnResume = false;
      mapViewModel.displayCurrentLocation(permissionCheck: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _askForLocationPermission() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Standortberechtigung'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Zur Anzeige des aktuellen Standorts benötigt die App die Berechtigung "Standort".'),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text('Appeinstellungen'),
              onPressed: () {
                AppSettings.openAppSettings();
                displayCurrentLocationOnResume = true;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  bool displayCurrentLocationOnResume = false;
  MapScreenViewModel mapViewModel;



  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MapScreenViewModel>(
      create: (BuildContext context) {
        MapScreenViewModel model = MapScreenViewModel();
        mapViewModel = model;
        model.errorMsgs.listen((errorMsg) async {
          scaffoldKey.currentState.hideCurrentSnackBar();
          scaffoldKey.currentState.showSnackBar(SnackBar(
            content: Text(errorMsg),
            duration: Duration(seconds: 2),
          ));
        });
        model.showLocationPermissionDialog.listen((_) {
          _askForLocationPermission();
        });
        return model;
      },
      child: Consumer<MapScreenViewModel>(
        builder: (context, model, child) {
          return Scaffold(
            key: scaffoldKey,
            drawer: SideDrawer(),
            body: Stack(
              children: [
                GoogleMap(
                  polylines: model.polylines,
                  myLocationButtonEnabled: false,
                  myLocationEnabled: model.currentLocationVisible,
                  onMapCreated: (controller) {
                    model.onMapCreated(controller);
                  },
                  initialCameraPosition: CameraPosition(
                    target: _stachus,
                    zoom: 14.0,
                  ),
                  mapType: MapType.normal,
                  mapToolbarEnabled: true,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  padding: EdgeInsets.only(top: 88),
                ),
                SafeArea(
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RawMaterialButton(
                                onPressed: () {
                                  showModalBottomSheet<void>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return StatefulBuilder(
                                        builder: (context,
                                            StateSetter setModalState) {
                                          return Container(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: <Widget>[
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          16.0, 8, 16, 0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
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
                                                            Navigator.pop(
                                                                context),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                CheckboxListTile(
                                                  title: Text("Radvorrangnetz"),
                                                  value: model
                                                      .isRadlvorrangnetzVisible,
                                                  onChanged: (bool value) {
                                                    model
                                                        .toggleRadvorrangnetzVisible();
                                                    setModalState(() {});
                                                  },
                                                ),
                                                CheckboxListTile(
                                                  title: Text("Gesamtnetz"),
                                                  value:
                                                      model.isGesamtnetzVisible,
                                                  onChanged: (bool value) {
                                                    model
                                                        .toggleGesamtnetzVisible();
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
                                constraints: BoxConstraints.expand(
                                    width: 56, height: 56),
                                child: Icon(
                                  Icons.layers,
                                  color: Colors.black54,
                                ),
                                padding: EdgeInsets.all(15.0),
                                shape: CircleBorder(),
                              ),
                              SizedBox(
                                height: 16,
                              ),
                              RawMaterialButton(
                                onPressed: () async {
                                  model.displayCurrentLocation();
                                },
                                elevation: 2.0,
                                fillColor: Colors.white,
                                constraints: BoxConstraints.expand(
                                    width: 56, height: 56),
                                child: Icon(
                                  model.currentLocationVisible ? Icons.my_location : Icons.location_searching,
                                  color: model.currentLocationVisible ? Colors.black54 : Colors.black26,
                                ),
                                padding: EdgeInsets.all(15.0),
                                shape: CircleBorder(),
                              ),
                            ],
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
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
