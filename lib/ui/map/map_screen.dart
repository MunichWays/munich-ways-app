import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/flutter_map/clickable_polyline_layer_widget.dart';
import 'package:munich_ways/ui/map/flutter_map/destination_marker_layer_widget.dart';
import 'package:munich_ways/ui/map/flutter_map/location_layer_widget.dart';
import 'package:munich_ways/ui/map/flutter_map/location_to_destination_route_layer.dart';
import 'package:munich_ways/ui/map/flutter_map/map_cache_store.dart';
import 'package:munich_ways/ui/map/flutter_map/osm_credits_widget.dart';
import 'package:munich_ways/ui/map/map_action_buttons/location_button.dart';
import 'package:munich_ways/ui/map/map_action_buttons/route_button_bar.dart';
import 'package:munich_ways/ui/map/map_action_buttons/show_gesamtnetz_button.dart';
import 'package:munich_ways/ui/map/map_info_dialog.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/missing_radnetze_overlay.dart';
import 'package:munich_ways/ui/map/sheets/street_details_sheet.dart';
import 'package:munich_ways/ui/side_drawer.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math.dart' as vector_math;

import 'flutter_map/destination_offscreen_widget.dart';
import 'map_app_bar.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final LatLng _stachus = LatLng(48.14, 11.5652);
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();
  GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey();

  final Future<CacheStore> _mapCacheStoreFuture =
      MapCacheStore().getMapCacheStore();

  bool displayCurrentLocationOnResume = false;
  late MapScreenViewModel mapViewModel;
  MapController? mapController;
  double? rotationInDegrees = null;

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
        model.currentLocationBtnClickedStream.listen((LatLng location) {
          mapController!.move(location, max(mapController!.camera.zoom, 17));
        });
        model.destinationStream.listen((Place place) {
          mapController!.move(place.latLng, mapController!.camera.zoom);
        });
        model.routeStream.listen((MapRoute route) {
          EdgeInsets mapInsets = MapInsets.of(context);
          mapController!.fitCamera(CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(route.route!.points),
              padding: EdgeInsets.fromLTRB(
                  mapInsets.left + 16,
                  mapInsets.top + 16,
                  mapInsets.right + 16,
                  mapInsets.bottom + 16)));
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
                  FutureBuilder<CacheStore>(
                      future: _mapCacheStoreFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final cacheStore = snapshot.data!;
                          return FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              interactionOptions: InteractionOptions(
                                  flags: InteractiveFlag.all,
                                  enableMultiFingerGestureRace: true),
                              initialCenter: _stachus,
                              initialZoom: 15,
                              maxZoom: 18,
                              minZoom: 10,
                              onPositionChanged:
                                  (MapPosition position, bool hasGesture) {
                                model.onMapPositionChanged(
                                    position, hasGesture);
                              },
                              onMapEvent: (evt) {
                                if (evt is MapEventLongPress) {
                                  model.setDestination(
                                      Place(null, evt.tapPosition));
                                } else if (evt is MapEventRotate) {
                                  setState(() {
                                    rotationInDegrees =
                                        mapController?.camera.rotation ?? 0;
                                  });
                                }
                              },
                              onMapReady: () {
                                model.onMapReady();
                                setState(() {
                                  rotationInDegrees =
                                      mapController?.camera.rotation ?? 0;
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: "de.munichways.app",
                                tileProvider: CachedTileProvider(
                                    store: cacheStore,
                                    maxStale: Duration(days: 30)),
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
                                                  latlng.latitude,
                                                  latlng.longitude))
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
                              CurrentPosToDestinationRouteLayer(model.route),
                              DestinationMarkerLayerWidget(
                                destination: model.destination,
                              ),
                              LocationLayerWidget(
                                enabled: model.locationState !=
                                    LocationState.NOT_AVAILABLE,
                                moveMapAlong:
                                    model.locationState == LocationState.FOLLOW,
                              ),
                              if (model.destination != null)
                                DestinationOffScreenWidget(
                                    destination: model.destination!),
                            ],
                          );
                        } else if (snapshot.hasError) {
                          return Center(child: Text(snapshot.error.toString()));
                        } else {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                      }),
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
                                top: 8.0, left: 8.0, right: 8.0, bottom: 16.0),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              verticalDirection: VerticalDirection.down,
                              spacing: 8,
                              runSpacing: 8,
                              runAlignment: WrapAlignment.end,
                              clipBehavior: Clip.none,
                              children: [
                                RouteButtonBar(model: model),
                                ShowGesamtnetzButton(model: model),
                                LocationButton(
                                  locationState: model.locationState,
                                  onPressed: () async {
                                    model.onPressLocationBtn();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
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
                              Space(),
                              CompassButton(
                                rotationInDegrees: rotationInDegrees ?? 0,
                                onPressed: () {
                                  setState(() {
                                    mapController?.rotate(0);
                                  });
                                },
                              ),
                            ],
                          ),
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

class CompassButton extends StatelessWidget {
  final double rotationInDegrees;
  final VoidCallback? onPressed;

  const CompassButton(
      {Key? key, required this.rotationInDegrees, required this.onPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isVisible = rotationInDegrees % 360 == 0;
    return AnimatedOpacity(
      opacity: isVisible ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: FloatingActionButton.small(
        heroTag: null,
        backgroundColor: Colors.white,
        child: Transform.rotate(
            angle: vector_math.radians(rotationInDegrees % 360),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image(image: AssetImage('images/compass.png')),
            )),
        onPressed: onPressed,
      ),
    );
  }
}
