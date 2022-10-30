import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
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
  GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey();

  bool displayCurrentLocationOnResume = false;
  late MapScreenViewModel mapViewModel;
  MapController? mapController;

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
          scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
          scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
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
          scaffoldKey.currentState!.showBottomSheet(
            (context) => StreetDetailsSheet(
              details: details,
              statusBarHeight: statusBarHeight,
            ),
            backgroundColor: Colors.transparent,
          );
        });
        model.currentLocationStream.listen((LatLng location) {
          log.d("onUpdateLocation");
          mapController!.move(location, mapController!.zoom);
        });
        model.destinationStream.listen((Place place) {
          mapController!.move(place.latLng, mapController!.zoom);
        });
        return model;
      },
      child: Consumer<MapScreenViewModel>(
        builder: (context, model, child) {
          return ScaffoldMessenger(
            key: scaffoldMessengerKey,
            child: Scaffold(
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
                        },
                        onMapReady: () {
                          model.onMapReady();
                        }),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: "de.munichways.app",
                        subdomains: ['a', 'b', 'c'],
                      ),
                      Container(
                        color: Colors.black26,
                      ),
                      ClickablePolylineLayer(
                        polylineCulling: true,
                        polylines: model.polylines
                            .map(
                              (polyline) => ClickablePolyline(
                                  points: polyline.points!
                                      .map((latlng) => LatLng(
                                          latlng.latitude, latlng.longitude))
                                      .toList(),
                                  strokeWidth: 3.0,
                                  isDotted: polyline.isGesamtnetz,
                                  color: AppColors.getPolylineColor(
                                      polyline.details!.farbe),
                                  onTap: () {
                                    model.onTap(polyline.details);
                                  }),
                            )
                            .toList(),
                      ),
                      DestinationBearingLayerWidget(
                        visible: model.destination != null,
                        bearing: model.bearing,
                        onTap: () {
                          if (model.destination != null) {
                            mapController!.move(
                                model.destination!.latLng, mapController!.zoom);
                          }
                        },
                      ),
                      DestinationMarkerLayerWidget(
                        destination: model.destination,
                      ),
                      LocationLayerWidget(
                        enabled:
                            model.locationState != LocationState.NOT_AVAILABLE,
                        moveMapAlong:
                            model.locationState == LocationState.FOLLOW,
                      ),
                    ],
                  ),
                  SafeArea(
                    child: Stack(
                      children: [
                        OSMCreditsWidget(),
                        Visibility(
                          visible: model.loading,
                          child: Center(
                            child: RawMaterialButton(
                                elevation: 2.0,
                                fillColor: Colors.white,
                                padding: EdgeInsets.all(15.0),
                                shape: CircleBorder(),
                                constraints: BoxConstraints.expand(
                                    width: 56, height: 56),
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
                            padding: const EdgeInsets.only(
                                top: 72.0, left: 8.0, right: 8.0, bottom: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SearchLocationActionButton(model: model),
                                Space(),
                                SizedBox(
                                  height: 40,
                                  child: FittedBox(
                                    child: FloatingActionButton.extended(
                                      heroTag: null,
                                      onPressed: () {
                                        model.toggleGesamtnetzVisible();
                                      },
                                      backgroundColor: Colors.white,
                                      foregroundColor: model.isGesamtnetzVisible
                                          ? AppColors.mapAccentColor
                                          : Colors.black45,
                                      icon: Icon(
                                        model.isGesamtnetzVisible
                                            ? Icons.layers
                                            : Icons.layers_clear,
                                      ),
                                      label: Text("Alle"),
                                      tooltip: "Alle Strecken ausblenden",
                                    ),
                                  ),
                                ),
                                Space(),
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
            ),
          );
        },
      ),
    );
  }
}

class Space extends StatelessWidget {
  const Space({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      width: 8,
    );
  }
}

class SearchLocationActionButton extends StatelessWidget {
  final MapScreenViewModel model;

  const SearchLocationActionButton({
    Key? key,
    required this.model,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: null,
      backgroundColor: Colors.white,
      child: Icon(
        model.destination != null ? Icons.search_off : Icons.search,
        color: model.destination != null
            ? AppColors.mapAccentColor
            : Colors.black45,
      ),
      onPressed: () async {
        if (model.destination == null) {
          Place? place = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SearchLocationScreen()),
          ) as Place?;
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
    Key? key,
    required this.onPressed,
    required this.locationState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: null,
      backgroundColor: Colors.white,
      onPressed: this.onPressed as void Function()?,
      child: _buildIcon(),
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
          color: AppColors.mapAccentColor,
        );
      default:
        return Icon(
          Icons.location_searching,
          color: Colors.black26,
        );
    }
  }
}
