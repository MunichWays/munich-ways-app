import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/flutter_map/clickable_polyline_layer_widget.dart';
import 'package:munich_ways/flutter_map/osm_credits_widget.dart';
import 'package:munich_ways/ui/map/map_info_dialog.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/missing_radnetze_overlay.dart';
import 'package:munich_ways/ui/map/sheets/bikenet_selection_sheet.dart';
import 'package:munich_ways/ui/map/sheets/street_details_sheet.dart';
import 'package:munich_ways/ui/side_drawer.dart';
import 'package:munich_ways/ui/theme.dart';
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
    if (displayCurrentLocationOnResume && state == AppLifecycleState.resumed) {
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
  bool firstBuild = false;

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
        model.showStreetDetails.listen((details) {
          double statusBarHeight = MediaQuery.of(context).padding.top;
          return scaffoldKey.currentState.showBottomSheet(
            (context) => StreetDetailsSheet(
              details: details,
              statusBarHeight: statusBarHeight,
            ),
            backgroundColor: Colors.transparent,
          );
        });
        return model;
      },
      child: Consumer<MapScreenViewModel>(
        builder: (context, model, child) {
          if (firstBuild) {
            firstBuild = !firstBuild;
            model.refreshRadlnetze();
          }
          return Scaffold(
            key: scaffoldKey,
            drawer: SideDrawer(),
            body: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    center: LatLng(_stachus.latitude, _stachus.longitude),
                    zoom: 14,
                  ),
                  children: [
                    TileLayerWidget(
                      options: TileLayerOptions(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c'],
                      ),
                    ),
                    ClickablePolylineLayerWidget(
                      options: ClickablePolylineLayerOptions(
                        polylineCulling: true,
                        polylines: model.polylines
                            .map(
                              (polyline) => ClickablePolyline(
                                  points: polyline.points
                                      .map((latlng) => LatLng(
                                          latlng.latitude, latlng.longitude))
                                      .toList(),
                                  strokeWidth: 3.0,
                                  isDotted: false,
                                  color: AppColors.getPolylineColor(
                                      polyline.details.farbe),
                                  onTap: () {
                                    model.onTap(polyline.details);
                                  }),
                            )
                            .toList(),
                      ),
                    ),
                    OSMCreditsWidget(),
                  ],
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
                                onPressed: () async {
                                  if (!model.loading) {
                                    model.refreshRadlnetze();
                                  }
                                },
                                elevation: 2.0,
                                fillColor: Colors.white,
                                padding: EdgeInsets.all(15.0),
                                shape: CircleBorder(),
                                constraints: BoxConstraints.expand(
                                    width: 56, height: 56),
                                child: model.loading
                                    ? SizedBox(
                                        width: 20.0,
                                        height: 20.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : Icon(
                                        Icons.refresh,
                                        color: Colors.black54,
                                      ),
                              ),
                              SizedBox(
                                height: 16,
                              ),
                              RawMaterialButton(
                                onPressed: () {
                                  showModalBottomSheet<void>(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (BuildContext context) {
                                      return BikenetSelectionSheet(
                                        model: model,
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
                                  model.currentLocationVisible
                                      ? Icons.my_location
                                      : Icons.location_searching,
                                  color: model.currentLocationVisible
                                      ? Colors.black54
                                      : Colors.black26,
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
                              showDialog(
                                  context: context,
                                  builder: (_) => MapInfoDialog());
                            },
                          ),
                        ],
                      ),
                      Visibility(
                        visible: model.displayMissingPolylinesMsg,
                        child: MissingRadnetzeCard(
                          loading: model.loading,
                          onPressed: () {
                            model.refreshRadlnetze();
                          },
                        ),
                      )
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
