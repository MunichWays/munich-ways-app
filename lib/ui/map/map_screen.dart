import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/flutter_map/osm_credits_widget.dart';
import 'package:munich_ways/ui/map/flutter_map/vector_basemap_constants.dart';
import 'package:munich_ways/ui/map/map_action_buttons/compass_button.dart';
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

import 'map_app_bar.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  static const latlong2.LatLng _stachus = latlong2.LatLng(48.14, 11.5652);

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey();

  bool displayCurrentLocationOnResume = false;
  late MapScreenViewModel mapViewModel;

  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _mapReadyNotified = false;
  bool _overlaySyncScheduled = false;
  bool _overlaySyncRunning = false;
  bool _overlaySyncQueued = false;

  List<Line> _networkLines = const [];
  List<Line> _networkHitLines = const [];
  final Map<String, StreetDetails> _streetDetailsByLineId = {};
  Line? _routeLine;
  Circle? _destinationCircle;
  double rotationInDegrees = 0;
  bool _lineTapHandlerAttached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
        final model = MapScreenViewModel();
        mapViewModel = model;

        model.errorMsgs.listen((errorMsg) {
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
          final statusBarHeight = MediaQuery.of(context).padding.top;
          scaffoldKey.currentState!.showBottomSheet(
            (context) => StreetDetailsSheet(
              details: details,
              statusBarHeight: statusBarHeight,
            ),
            backgroundColor: Colors.transparent,
          );
        });
        model.currentLocationBtnClickedStream
            .listen((latlong2.LatLng location) {
          final controller = _mapController;
          if (controller == null) return;
          final currentZoom = controller.cameraPosition?.zoom ?? 15;
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(location.latitude, location.longitude),
              max(currentZoom, 17),
            ),
          );
        });
        model.destinationStream.listen((Place place) {
          final controller = _mapController;
          if (controller == null) return;
          final currentZoom = controller.cameraPosition?.zoom ?? 15;
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(place.latLng.latitude, place.latLng.longitude),
              currentZoom,
            ),
          );
        });
        model.routeStream.listen((MapRoute route) {
          final controller = _mapController;
          if (controller == null || route.route == null) return;
          final bounds = _boundsFor(route.route!.points);
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds,
              left: 24, top: 24, right: 24, bottom: 24));
        });
        return model;
      },
      child: Consumer<MapScreenViewModel>(
        builder: (context, model, child) {
          if (_styleLoaded && !_mapReadyNotified) {
            _mapReadyNotified = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                model.onMapReady();
              }
            });
          }
          _scheduleOverlaySync(model);

          return ScaffoldMessenger(
            key: scaffoldMessengerKey,
            child: Scaffold(
              key: scaffoldKey,
              drawer: SideDrawer(),
              body: Stack(
                children: [
                  MapLibreMap(
                    styleString: kOpenFreeMapLibertyStyleAsset,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_stachus.latitude, _stachus.longitude),
                      zoom: 15,
                    ),
                    minMaxZoomPreference: const MinMaxZoomPreference(10, 22),
                    attributionButtonMargins: const Point(-200, -200),
                    myLocationEnabled:
                        model.locationState != LocationState.NOT_AVAILABLE,
                    myLocationTrackingMode:
                        _trackingModeFor(model.locationState),
                    myLocationRenderMode: model.locationState ==
                            LocationState.FOLLOW_AND_ROTATE_MAP
                        ? MyLocationRenderMode.compass
                        : MyLocationRenderMode.normal,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (!_lineTapHandlerAttached) {
                        _lineTapHandlerAttached = true;
                        controller.onLineTapped.add((line) {
                          final details = _streetDetailsByLineId[line.id];
                          if (details != null) {
                            mapViewModel.onTap(details);
                          }
                        });
                      }
                    },
                    onStyleLoadedCallback: () {
                      if (!mounted) return;
                      setState(() {
                        _styleLoaded = true;
                      });
                      _scheduleOverlaySync(model);
                    },
                    onMapLongClick: (screenPoint, latLng) {
                      model.setDestination(Place(null,
                          latlong2.LatLng(latLng.latitude, latLng.longitude)));
                    },
                    onCameraMove: (cameraPosition) {
                      if ((cameraPosition.bearing - rotationInDegrees).abs() >=
                          1) {
                        setState(() {
                          rotationInDegrees = cameraPosition.bearing;
                        });
                      }
                    },
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
                                top: 8.0, left: 8.0, right: 8.0, bottom: 16.0),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              verticalDirection: VerticalDirection.down,
                              spacing: 8,
                              runSpacing: 8,
                              runAlignment: WrapAlignment.end,
                              clipBehavior: Clip.none,
                              children: [
                                ShowGesamtnetzButton(model: model),
                                RouteButtonBar(model: model),
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
                                rotationInDegrees: rotationInDegrees,
                                onPressed: () {
                                  _mapController?.animateCamera(
                                      CameraUpdate.bearingTo(0));
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

  MyLocationTrackingMode _trackingModeFor(LocationState state) {
    switch (state) {
      case LocationState.FOLLOW:
        return MyLocationTrackingMode.tracking;
      case LocationState.FOLLOW_AND_ROTATE_MAP:
        return MyLocationTrackingMode.trackingCompass;
      case LocationState.NOT_AVAILABLE:
      case LocationState.DISPLAY:
        return MyLocationTrackingMode.none;
    }
  }

  LatLngBounds _boundsFor(List<latlong2.LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points.skip(1)) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  String _hexColor(Color c) {
    final r =
        (c.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g =
        (c.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b =
        (c.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  void _scheduleOverlaySync(MapScreenViewModel model) {
    if (!_styleLoaded || _mapController == null || _overlaySyncScheduled)
      return;
    _overlaySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlaySyncScheduled = false;
      _syncOverlays(model);
    });
  }

  Future<void> _syncOverlays(MapScreenViewModel model) async {
    final controller = _mapController;
    if (!_styleLoaded || controller == null) return;

    if (_overlaySyncRunning) {
      _overlaySyncQueued = true;
      return;
    }
    _overlaySyncRunning = true;
    try {
      if (_networkLines.isNotEmpty) {
        await controller.removeLines(_networkLines);
        _networkLines = const [];
        _streetDetailsByLineId.clear();
      }
      if (_networkHitLines.isNotEmpty) {
        await controller.removeLines(_networkHitLines);
        _networkHitLines = const [];
      }
      if (_routeLine != null) {
        await controller.removeLine(_routeLine!);
        _routeLine = null;
      }
      if (_destinationCircle != null) {
        await controller.removeCircle(_destinationCircle!);
        _destinationCircle = null;
      }

      final visiblePolylines = model.polylines.toList();
      final netzLines = visiblePolylines
          .map((polyline) => LineOptions(
                geometry: polyline.points!
                    .map((p) => LatLng(p.latitude, p.longitude))
                    .toList(),
                lineWidth: 3.0,
                lineColor: _hexColor(
                    AppColors.getPolylineColor(polyline.details!.farbe)),
              ))
          .toList();
      if (netzLines.isNotEmpty) {
        _networkLines = await controller.addLines(netzLines);
        // A wider, near-invisible line layer restores the old tap tolerance.
        // We add this only for currently visible lines, so visibility toggles remain respected.
        final hitLines = visiblePolylines
            .map((polyline) => LineOptions(
                  geometry: polyline.points!
                      .map((p) => LatLng(p.latitude, p.longitude))
                      .toList(),
                  lineWidth: 20.0, // this is the tap tolerance for the lines
                  lineOpacity: 0.0,
                  lineColor: '#000000',
                ))
            .toList();
        _networkHitLines = await controller.addLines(hitLines);

        for (var i = 0; i < _networkLines.length; i++) {
          final details = visiblePolylines[i].details;
          if (details != null) {
            _streetDetailsByLineId[_networkLines[i].id] = details;
          }
        }
        for (var i = 0; i < _networkHitLines.length; i++) {
          final details = visiblePolylines[i].details;
          if (details != null) {
            _streetDetailsByLineId[_networkHitLines[i].id] = details;
          }
        }
      }

      if (model.route.state == MapRouteState.SHOWN &&
          model.route.route != null) {
        _routeLine = await controller.addLine(LineOptions(
          geometry: model.route.route!.points
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
          lineWidth: 6.0,
          lineColor: _hexColor(AppColors.mapRouteColor),
        ));
      }

      if (model.destination != null) {
        _destinationCircle = await controller.addCircle(CircleOptions(
          geometry: LatLng(
            model.destination!.latLng.latitude,
            model.destination!.latLng.longitude,
          ),
          circleRadius: 8,
          circleColor: '#f44336',
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ));
      }
    } finally {
      _overlaySyncRunning = false;
      if (_overlaySyncQueued) {
        _overlaySyncQueued = false;
        _scheduleOverlaySync(model);
      }
    }
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
