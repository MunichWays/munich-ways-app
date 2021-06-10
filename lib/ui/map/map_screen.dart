import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/flutter_map/clickable_polyline_layer_widget.dart';
import 'package:munich_ways/ui/map/flutter_map/destination_bearing_layer.dart';
import 'package:munich_ways/ui/map/flutter_map/destination_marker_layer_widget.dart';
import 'package:munich_ways/ui/map/flutter_map/location_layer_widget.dart';
import 'package:munich_ways/ui/map/flutter_map/osm_credits_widget.dart';
import 'package:munich_ways/ui/map/map_info_dialog.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/missing_radnetze_overlay.dart';
import 'package:munich_ways/ui/map/search_location/search_location_screen.dart';
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

  bool displayCurrentLocationOnResume = false;
  MapScreenViewModel mapViewModel;
  MapController mapController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mapController = MapController();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log.d("didChangeAppLifecycleState $state");
    if (displayCurrentLocationOnResume && state == AppLifecycleState.resumed) {
      displayCurrentLocationOnResume = false;
      mapViewModel.onPressLocationBtn(permissionCheck: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _askToEnableLocationService() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Standort aktivieren'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Zur Anzeige des aktuellen Standorts muss die Standortbestimmung aktiviert sein.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Standorteinstellungen'),
              onPressed: () {
                Geolocator.openLocationSettings();
                displayCurrentLocationOnResume = true;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
            TextButton(
              child: Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
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
        model.showEnableLocationServiceDialog.listen((_) {
          _askToEnableLocationService();
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
        model.currentLocationStream.listen((LatLng location) {
          log.d("onUpdateLocation");
          mapController.move(location, mapController.zoom);
        });
        model.destinationStream.listen((Place place) {
          mapController.move(place.latLng, mapController.zoom);
        });
        mapController.onReady.then((_) => model.onMapReady());
        return model;
      },
      child: Consumer<MapScreenViewModel>(
        builder: (context, model, child) {
          return Scaffold(
            key: scaffoldKey,
            drawer: SideDrawer(),
            body: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                      center: _stachus,
                      zoom: 15,
                      maxZoom: 18,
                      minZoom: 10,
                      onPositionChanged:
                          (MapPosition position, bool hasGesture) {
                        model.onMapPositionChanged(position, hasGesture);
                      }),
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
                                  isDotted: polyline.isGesamtnetz,
                                  color: AppColors.getPolylineColor(
                                      polyline.details.farbe),
                                  onTap: () {
                                    model.onTap(polyline.details);
                                  }),
                            )
                            .toList(),
                      ),
                    ),
                    DestinationBearingLayerWidget(
                      visible: model.destination != null,
                      bearing: model.bearing,
                      onTap: () {
                        if (model.destination != null) {
                          mapController.move(
                              model.destination.latLng, mapController.zoom);
                        }
                      },
                    ),
                    DestinationMarkerLayerWidget(
                      destination: model.destination,
                    ),
                    LocationLayerWidget(
                      enabled:
                          model.locationState != LocationState.NOT_AVAILABLE,
                      moveMapAlong: model.locationState == LocationState.FOLLOW,
                    ),
                    OSMCreditsWidget(),
                  ],
                ),
                SafeArea(
                  child: Stack(
                    children: [
                      Visibility(
                        visible: model.loading,
                        child: Center(
                          child: RawMaterialButton(
                              elevation: 2.0,
                              fillColor: Colors.white,
                              padding: EdgeInsets.all(15.0),
                              shape: CircleBorder(),
                              constraints:
                                  BoxConstraints.expand(width: 56, height: 56),
                              onPressed: () {},
                              child: SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              )),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SearchLocationActionButton(model: model),
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
                                shape: CircleBorder(),
                              ),
                              SizedBox(
                                height: 16,
                              ),
                              LocationActionButton(
                                onPressed: () async {
                                  model.onPressLocationBtn();
                                },
                                locationState: model.locationState,
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

class SearchLocationActionButton extends StatelessWidget {
  final MapScreenViewModel model;

  const SearchLocationActionButton({
    Key key,
    @required this.model,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      elevation: 2.0,
      fillColor: Colors.white,
      constraints: BoxConstraints.expand(width: 56, height: 56),
      child: Icon(
        model.destination != null ? Icons.search_off : Icons.search,
        color: model.destination != null ? Colors.blueAccent : Colors.black45,
      ),
      shape: CircleBorder(),
      onPressed: () async {
        if (model.destination == null) {
          Place place = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SearchLocationScreen()),
          ) as Place;
          model.setDestination(place);
        } else {
          model.clearDestination();
        }
      },
    );
  }
}

class LocationActionButton extends StatelessWidget {
  final Function onPressed;
  final LocationState locationState;

  const LocationActionButton({
    Key key,
    @required this.onPressed,
    @required this.locationState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      onPressed: this.onPressed,
      elevation: 2.0,
      fillColor: Colors.white,
      constraints: BoxConstraints.expand(width: 56, height: 56),
      child: _buildIcon(),
      padding: EdgeInsets.all(15.0),
      shape: CircleBorder(),
    );
  }

  Icon _buildIcon() {
    log.d(this.locationState);
    switch (this.locationState) {
      case LocationState.NOT_AVAILABLE:
        return Icon(
          Icons.location_searching,
          color: Colors.black26,
        );
      case LocationState.DISPLAY:
        return Icon(
          Icons.my_location,
          color: Colors.black54,
        );
      case LocationState.FOLLOW:
        return Icon(
          Icons.my_location,
          color: Colors.blueAccent,
        );
      default:
        return Icon(
          Icons.location_searching,
          color: Colors.black26,
        );
    }
  }
}
