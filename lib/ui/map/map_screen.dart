import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/flutter_map/osm_credits_widget.dart';
import 'package:munich_ways/ui/map/flutter_map/vector_basemap_constants.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_overlay/map_bottom_action_buttons.dart';
import 'package:munich_ways/ui/map/map_overlay/map_navigation_header_bar.dart';
import 'package:munich_ways/ui/map/map_overlay/map_side_action_buttons.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/maplibre_destination_offscreen_overlay.dart';
import 'package:munich_ways/ui/map/network_geojson.dart';
import 'package:munich_ways/ui/map/sheets/street_details_sheet.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:provider/provider.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  static const latlong2.LatLng _stachus = latlong2.LatLng(48.14, 11.5652);

  static const _kNetworkSourceId = 'munichways_radlnetz';
  static const _kNetworkLayerVisibleGesamtId =
      'munichways_radlnetz_lines_gesamt';
  static const _kNetworkLayerVisibleRadlId = 'munichways_radlnetz_lines_radl';
  static const _kNetworkLayerHitId = 'munichways_radlnetz_hit';

  /// Cycling route as GeoJSON (not [Line] annotation). Layer order: route, then
  /// Radl-Netz lines (gesamt, radl, hit), then highway-name symbol layers — all
  /// anchored with [kOpenFreeMapLibertyStreetNameBelowLayerId] so the route never
  /// depends on network layer ids being present.
  static const _kRouteSourceId = 'munichways_route';
  static const _kRouteLayerId = 'munichways_route_line';

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

  /// Line / GeoJSON feature id → street details (network taps + legacy line taps).
  final Map<String, StreetDetails> _streetDetailsByLineId = {};
  bool _networkGeoJsonReady = false;
  bool _routeGeoJsonReady = false;
  bool _featureTapHandlerAttached = false;
  Circle? _destinationCircle;

  /// Map camera bearing (clockwise from north); [MapCompassControl] listens for
  /// visibility and [CompassButton] rotation. Updated in [MapLibreMap.onCameraMove].
  final ValueNotifier<double> _mapBearingDegrees = ValueNotifier<double>(0.0);

  /// Bumped on [MapLibreMap.onCameraIdle] so [MapCompassControl] can finish hide.
  final ValueNotifier<int> _compassIdleTick = ValueNotifier<int>(0);

  bool _lineTapHandlerAttached = false;

  /// When these match the last sync, the corresponding map layers are skipped.
  int? _lastSyncedNetworkFingerprint;
  int? _lastRouteFingerprint;

  /// Whether to embed [MapLibreMap]; false briefly on iOS only (see [initState]).
  late bool _mountMapView;

  StreetDetails? _streetDetailsForNetworkFeatureId(dynamic rawId) {
    if (rawId == null) return null;
    final id = rawId.toString();
    if (id.isEmpty) return null;
    return _streetDetailsByLineId[id];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // iOS only: creating MapLibre in the first layout pass can hit Mapbox GL (native map engine) during an unstable
    // UIKit/Metal window phase and abort on cold start; a short defer avoids that. Android is fine.
    if (Platform.isIOS) {
      _mountMapView = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _mountMapView = true);
        });
      });
    } else {
      _mountMapView = true;
    }
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
    _mapBearingDegrees.dispose();
    _compassIdleTick.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _syncCompassBearingFromMap() async {
    final controller = _mapController;
    if (controller == null || !mounted) return;
    final pos = await controller.queryCameraPosition();
    if (!mounted || pos == null) return;
    final bearing = pos.bearing;
    if ((bearing - _mapBearingDegrees.value).abs() < 0.5) return;
    _mapBearingDegrees.value = bearing;
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
                Geolocator.openAppSettings();
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
              body: Stack(
                children: [
                  if (!_mountMapView)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white,
                        child: Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ),
                      ),
                    ),
                  if (_mountMapView)
                    MapLibreMap(
                      styleString: kOpenFreeMapLibertyStyleAsset,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_stachus.latitude, _stachus.longitude),
                        zoom: 15,
                      ),
                      // Native MapLibre compass (default on) duplicates [MapCompassControl].
                      compassEnabled: false,
                      trackCameraPosition: true,
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
                            final details =
                                _streetDetailsForNetworkFeatureId(line.id);
                            if (details != null) {
                              mapViewModel.onTap(details);
                            }
                          });
                        }
                        if (!_featureTapHandlerAttached) {
                          _featureTapHandlerAttached = true;
                          controller.onFeatureTapped.add(
                            (point, latLng, id, layerId, annotation) {
                              if (layerId != _kNetworkLayerHitId) {
                                return;
                              }
                              final details =
                                  _streetDetailsForNetworkFeatureId(id);
                              if (details != null) {
                                mapViewModel.onTap(details);
                              }
                            },
                          );
                        }
                      },
                      onStyleLoadedCallback: () {
                        if (!mounted) return;
                        final c = _mapController;
                        Future<void> afterStyle() async {
                          if (c != null) {
                            // Remove overlay layers before re-adding after style load.
                            if (_networkGeoJsonReady) {
                              await _removeNetworkGeoJsonLayers(c);
                            }
                            if (_routeGeoJsonReady) {
                              await _removeRouteGeoJsonLayers(c);
                            }
                          }
                          _networkGeoJsonReady = false;
                          _routeGeoJsonReady = false;
                          if (!mounted) return;
                          // Style rebuild clears native annotations; drop stale handles.
                          _destinationCircle = null;
                          _streetDetailsByLineId.clear();
                          _lastSyncedNetworkFingerprint = null;
                          _lastRouteFingerprint = null;
                          setState(() {
                            _styleLoaded = true;
                          });
                          _scheduleOverlaySync(model);
                        }

                        unawaited(afterStyle());
                      },
                      onMapLongClick: (screenPoint, latLng) {
                        model.setDestination(Place(
                            null,
                            latlong2.LatLng(
                                latLng.latitude, latLng.longitude)));
                      },
                      onCameraMove: (CameraPosition position) {
                        _mapBearingDegrees.value = position.bearing;
                        model.onMapCenterChanged(latlong2.LatLng(
                          position.target.latitude,
                          position.target.longitude,
                        ));
                      },
                      onCameraTrackingDismissed: () {
                        model.onUserStoppedFollowingLocation();
                      },
                      onCameraIdle: () {
                        _compassIdleTick.value++;
                      },
                    ),
                  if (model.destination != null &&
                      _styleLoaded &&
                      _mapController != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: MapLibreDestinationOffScreenOverlay(
                          controller: _mapController,
                          destination: model.destination!,
                        ),
                      ),
                    ),
                  SafeArea(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const OSMCreditsWidget(),
                        Positioned(
                          top: 0,
                          left: 16,
                          right: 16,
                          child: MapNavigationHeaderBar(model: model),
                        ),
                        MapSideActionButtons(
                          model: model,
                          mapController: _mapController,
                          mapBearingDegrees: _mapBearingDegrees,
                          compassIdleTick: _compassIdleTick,
                          onNorthUp: () async {
                            model.onCompassNorthUpPressed();
                            final c = _mapController;
                            if (c != null) {
                              await c.animateCamera(CameraUpdate.bearingTo(0));
                              await _syncCompassBearingFromMap();
                            }
                          },
                          queryMapBearingDegrees: () async {
                            final c = _mapController;
                            if (c == null) return null;
                            final pos = await c.queryCameraPosition();
                            return pos?.bearing;
                          },
                          onPressLocation: () {
                            model.onPressLocationBtn();
                          },
                        ),
                        MapBottomActionButtons(model: model),
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

  /// Identifies the current radl / gesamtnetz overlay set (not route/destination).
  int _networkFingerprint(MapScreenViewModel model) {
    final pl = model.polylines.toList()
      ..sort((a, b) => (a.details?.munichwaysId ?? '')
          .compareTo(b.details?.munichwaysId ?? ''));
    var h = Object.hash(
      model.loading,
      model.isRadlvorrangnetzVisible,
      model.isGesamtnetzVisible,
      pl.length,
    );
    for (final p in pl) {
      h = Object.hash(
          h, p.details?.munichwaysId, p.details?.cartoDbId, p.points?.length);
    }
    return h;
  }

  int _routeFingerprint(MapScreenViewModel model) {
    final r = model.route.route;
    final pts = r?.points;
    double? lat1, lng1, lat2, lng2;
    if (pts != null && pts.isNotEmpty) {
      lat1 = pts.first.latitude;
      lng1 = pts.first.longitude;
      lat2 = pts.last.latitude;
      lng2 = pts.last.longitude;
    }
    return Object.hash(
      model.route.state,
      pts?.length,
      lat1,
      lng1,
      lat2,
      lng2,
      model.destination?.latLng.latitude,
      model.destination?.latLng.longitude,
    );
  }

  Future<void> _syncOverlays(MapScreenViewModel model) async {
    final controller = _mapController;
    if (!_styleLoaded || controller == null) return;

    if (_overlaySyncRunning) {
      _overlaySyncQueued = true;
      return;
    }

    final routeFp = _routeFingerprint(model);
    final netFp = _networkFingerprint(model);
    final routeChanged = _lastRouteFingerprint != routeFp;
    final networkChanged = _lastSyncedNetworkFingerprint != netFp;
    if (!routeChanged && !networkChanged) {
      return;
    }

    _overlaySyncRunning = true;
    try {
      // Route is added first, then Radl-Netz (same anchor below highway names) so
      // ratings paint above the route. Destination uses [MapLibreMapController.addCircle]
      // and stays above these GeoJSON line layers.
      await _ensureRouteGeoJsonLayer(controller);
      if (networkChanged) {
        await _syncNetworkLayers(model, controller);
        _lastSyncedNetworkFingerprint = netFp;
      }
      if (routeChanged) {
        await _syncRouteAndDestinationLayers(model, controller);
        _lastRouteFingerprint = routeFp;
      }
    } finally {
      _overlaySyncRunning = false;
      if (_overlaySyncQueued) {
        _overlaySyncQueued = false;
        _scheduleOverlaySync(model);
      }
    }
  }

  Future<void> _syncRouteAndDestinationLayers(
      MapScreenViewModel model, MapLibreMapController controller) async {
    if (_destinationCircle != null) {
      await controller.removeCircle(_destinationCircle!);
      _destinationCircle = null;
    }

    if (model.route.state == MapRouteState.SHOWN && model.route.route != null) {
      await controller.setGeoJsonSource(_kRouteSourceId, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': model.route.route!.points
                  .map((p) => [p.longitude, p.latitude])
                  .toList(),
            },
          },
        ],
      });
    } else {
      await controller.setGeoJsonSource(_kRouteSourceId, {
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      });
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
  }

  Future<void> _removeRouteGeoJsonLayers(
      MapLibreMapController controller) async {
    if (!_routeGeoJsonReady) return;
    try {
      await controller.removeLayer(_kRouteLayerId);
      await controller.removeSource(_kRouteSourceId);
    } catch (_) {
      // Style may have already dropped layers.
    }
  }

  Future<void> _ensureRouteGeoJsonLayer(
      MapLibreMapController controller) async {
    if (_routeGeoJsonReady) return;
    await controller.addGeoJsonSource(_kRouteSourceId, {
      'type': 'FeatureCollection',
      'features': <dynamic>[],
    });
    await controller.addLineLayer(
      _kRouteSourceId,
      _kRouteLayerId,
      LineLayerProperties(
        lineColor: _hexColor(AppColors.mapRouteColor),
        lineWidth: 10.0,
      ),
      belowLayerId: kOpenFreeMapLibertyStreetNameBelowLayerId,
      enableInteraction: false,
    );
    _routeGeoJsonReady = true;
  }

  Future<void> _removeNetworkGeoJsonLayers(
      MapLibreMapController controller) async {
    if (!_networkGeoJsonReady) return;
    try {
      await controller.removeLayer(_kNetworkLayerHitId);
      await controller.removeLayer(_kNetworkLayerVisibleRadlId);
      await controller.removeLayer(_kNetworkLayerVisibleGesamtId);
      await controller.removeSource(_kNetworkSourceId);
    } catch (_) {
      // Style may have already dropped layers.
    }
  }

  Future<void> _ensureNetworkGeoJsonLayers(
      MapLibreMapController controller) async {
    if (_networkGeoJsonReady) return;
    // Route must exist before Radl-Netz layers: all use the same below-highway
    // anchor so insertion order is route → gesamt → radl → hit (ratings on top).
    await _ensureRouteGeoJsonLayer(controller);
    await controller.addGeoJsonSource(_kNetworkSourceId, {
      'type': 'FeatureCollection',
      'features': <dynamic>[],
    });
    // Gesamtnetz (secondary): dashed. Radlvorrang-Netz: solid, drawn on top.
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerVisibleGesamtId,
      const LineLayerProperties(
        lineColor: [Expressions.get, 'lineColor'],
        lineWidth: 3.0,
        lineOpacity: 1.0,
        lineCap: 'round',
        lineJoin: 'round',
        lineDasharray: [1.25, 2],
      ),
      filter: [
        Expressions.equal,
        [Expressions.get, 'gesamtnetz'],
        true
      ],
      belowLayerId: kOpenFreeMapLibertyStreetNameBelowLayerId,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerVisibleRadlId,
      const LineLayerProperties(
        lineColor: [Expressions.get, 'lineColor'],
        lineWidth: 3.0,
        lineOpacity: 1.0,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        Expressions.equal,
        [Expressions.get, 'gesamtnetz'],
        false
      ],
      belowLayerId: kOpenFreeMapLibertyStreetNameBelowLayerId,
      enableInteraction: false,
    );
    // lineOpacity must stay > 0: some MapLibre builds skip hit-testing for fully
    // transparent lines, so taps never reach feature#onTap.
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerHitId,
      const LineLayerProperties(
        lineColor: '#000000',
        lineWidth: 20.0,
        lineOpacity: 0.01,
      ),
      belowLayerId: kOpenFreeMapLibertyStreetNameBelowLayerId,
      enableInteraction: true,
    );
    _networkGeoJsonReady = true;
  }

  Future<void> _syncNetworkLayers(
      MapScreenViewModel model, MapLibreMapController controller) async {
    final visiblePolylines = model.polylines.toList();
    final result = buildNetworkGeoJson(
      visiblePolylines,
      (farbe) => _hexColor(AppColors.getPolylineColor(farbe)),
    );

    _streetDetailsByLineId
      ..clear()
      ..addAll(result.detailsByFeatureId);

    await _ensureNetworkGeoJsonLayers(controller);
    await controller.setGeoJsonSource(
        _kNetworkSourceId, result.featureCollection);
  }
}
