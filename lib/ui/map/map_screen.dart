import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/map_attribution.dart';
import 'package:munich_ways/ui/map/vector_basemap_constants.dart';
import 'package:munich_ways/ui/map/map_overlay_line_style.dart';
import 'package:munich_ways/screenshots/store_screenshot_config.dart';
import 'package:munich_ways/screenshots/store_screenshot_controls.dart';
import 'package:munich_ways/screenshots/store_screenshot_map_ready_semantics.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_overlay/map_bottom_action_buttons.dart';
import 'package:munich_ways/ui/map/map_overlay/map_navigation_header_bar.dart';
import 'package:munich_ways/ui/map/map_overlay/map_side_action_buttons.dart';
import 'package:munich_ways/ui/map/map_location_dialogs.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/street_details_modal_listener.dart';
import 'package:munich_ways/ui/map/map_destination_offscreen_overlay.dart';
import 'package:munich_ways/ui/map/network_geojson.dart';
import 'package:munich_ways/ui/map/route_position_snapper.dart';
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
  /// Radl-Netz lines (gesamt, radl, hit), then basemap labels (water, streets, …)
  /// — all anchored with [kOpenFreeMapBasemapOverlayBelowLayerId] so the route never
  /// depends on network layer ids being present.
  static const _kRouteSourceId = 'munichways_route';
  static const _kRouteLayerId = 'munichways_route_line';

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey();
  final GlobalKey _mapLibreViewKey = GlobalKey(debugLabel: 'maplibre_map');

  bool displayCurrentLocationOnResume = false;
  late MapScreenViewModel mapViewModel;

  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _initialContentReady = false;
  bool _initialRatingsAwaitingMapIdle = false;
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
  Circle? _locationCircle;
  StreamSubscription<Position>? _locationSubscription;
  Position? _latestPosition;
  Position? _pendingPosition;
  bool _locationRenderRunning = false;
  double? _smoothedMovementBearing;

  /// Map camera bearing (clockwise from north); [MapCompassControl] listens for
  /// visibility and [CompassButton] rotation. Updated in [MapLibreMap.onCameraMove].
  final ValueNotifier<double> _mapBearingDegrees = ValueNotifier<double>(0.0);

  /// Bumped on [MapLibreMap.onCameraIdle] so [MapCompassControl] can finish hide.
  final ValueNotifier<int> _compassIdleTick = ValueNotifier<int>(0);

  bool _lineTapHandlerAttached = false;

  /// When these match the last sync, the corresponding map layers are skipped.
  int? _lastSyncedNetworkFingerprint;
  int? _lastRouteFingerprint;

  bool _storeScreenshotNetworkSynced = false;
  bool _storeScreenshotIdleCameraDone = false;
  bool _storeScreenshotIdleCameraScheduled = false;
  bool _storeScreenshotRouteVisualReady = false;

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
    if (state != AppLifecycleState.resumed) return;

    if (displayCurrentLocationOnResume) {
      displayCurrentLocationOnResume = false;
      unawaited(_primeLocationOnStart(mapViewModel, permissionCheck: false));
    } else if (Platform.isAndroid) {
      unawaited(_refreshLocationOnResume(mapViewModel));
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MapScreenViewModel>(
      create: (BuildContext _) {
        final model = MapScreenViewModel();
        mapViewModel = model;

        model.errorMsgs.listen((errorMsg) {
          scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
          scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
            content: Text(errorMsg),
            duration: Duration(seconds: 2),
          ));
          // `announce` also works with the older Flutter SDK used by the 3.0 CI job.
          // ignore: deprecated_member_use
          SemanticsService.announce(errorMsg, TextDirection.ltr);
        });
        model.showLocationPermissionDialog.listen((_) {
          if (!mounted) return;
          MapLocationDialogs.showPermissionRequestDialog(
            this.context,
            markRecheckLocationOnResume: () {
              displayCurrentLocationOnResume = true;
            },
          );
        });
        model.showEnableLocationServiceDialog.listen((_) {
          if (!mounted) return;
          MapLocationDialogs.showEnableLocationServiceDialog(
            this.context,
            markRecheckLocationOnResume: () {
              displayCurrentLocationOnResume = true;
            },
          );
        });
        model.currentLocationBtnClickedStream
            .listen((latlong2.LatLng location) {
          final controller = _mapController;
          if (controller == null) return;
          if (!_isValidCoordinate(location.latitude, location.longitude))
            return;
          final currentZoom = _safeZoom(controller.cameraPosition?.zoom);
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
          if (!_isValidCoordinate(
              place.latLng.latitude, place.latLng.longitude)) {
            return;
          }
          final currentZoom = _safeZoom(controller.cameraPosition?.zoom);
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
          final validPoints = route.route!.points
              .where((p) => _isValidCoordinate(p.latitude, p.longitude))
              .toList();
          if (validPoints.isEmpty) return;

          if (validPoints.length == 1) {
            final currentZoom = _safeZoom(controller.cameraPosition?.zoom);
            controller.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(validPoints.first.latitude, validPoints.first.longitude),
                currentZoom,
              ),
            );
            return;
          }

          final bounds = _boundsFor(validPoints);
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
              if (!mounted) return;
              model.onMapReady();
              if (!kStoreScreenshots) {
                unawaited(_primeLocationOnStart(model));
              }
            });
          }
          _scheduleOverlaySync(model);

          if (kStoreScreenshots &&
              _storeScreenshotNetworkSynced &&
              !_storeScreenshotIdleCameraDone &&
              !_storeScreenshotIdleCameraScheduled &&
              _mapController != null &&
              _mountMapView) {
            _storeScreenshotIdleCameraScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_applyStoreScreenshotIdleCamera());
            });
          }

          final storeIdleReady = kStoreScreenshots &&
              _styleLoaded &&
              !model.loading &&
              model.storeScreenshotLocationPrimeComplete &&
              _storeScreenshotNetworkSynced &&
              _storeScreenshotIdleCameraDone &&
              model.destination == null &&
              model.route.state == MapRouteState.NO_ROUTE;

          final storeRouteReady = kStoreScreenshots &&
              model.route.state == MapRouteState.SHOWN &&
              model.route.route != null &&
              model.route.route!.points.isNotEmpty &&
              _storeScreenshotRouteVisualReady;

          return ScaffoldMessenger(
            key: scaffoldMessengerKey,
            child: Scaffold(
              key: scaffoldKey,
              body: Stack(
                children: [
                  const StreetDetailsModalListener(),
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
                    Listener(
                      onPointerDown: (_) {
                        if (model.locationState == LocationState.FOLLOW ||
                            model.locationState ==
                                LocationState.FOLLOW_AND_ROTATE_MAP) {
                          model.onUserStoppedFollowingLocation();
                        }
                      },
                      child: RepaintBoundary(
                        key: _mapLibreViewKey,
                        child: MapLibreMap(
                          styleString: kOpenFreeMapLibertyStyleAsset,
                          initialCameraPosition: CameraPosition(
                            target:
                                LatLng(_stachus.latitude, _stachus.longitude),
                            zoom: 15,
                          ),
                          // Native MapLibre compass (default on) duplicates [MapCompassControl].
                          compassEnabled: false,
                          trackCameraPosition: true,
                          minMaxZoomPreference:
                              const MinMaxZoomPreference(10, 22),
                          attributionButtonMargins: const Point(-200, -200),
                          myLocationEnabled: false,
                          myLocationTrackingMode:
                              _trackingModeFor(model.locationState),
                          myLocationRenderMode:
                              _renderModeFor(model.locationState),
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
                              _locationCircle = null;
                              _streetDetailsByLineId.clear();
                              _lastSyncedNetworkFingerprint = null;
                              _lastRouteFingerprint = null;
                              setState(() {
                                _styleLoaded = true;
                                if (kStoreScreenshots) {
                                  _storeScreenshotNetworkSynced = false;
                                  _storeScreenshotIdleCameraDone = false;
                                  _storeScreenshotIdleCameraScheduled = false;
                                  _storeScreenshotRouteVisualReady = false;
                                }
                              });
                              _scheduleOverlaySync(model);
                              final position = _latestPosition;
                              if (position != null) {
                                _pendingPosition = position;
                                unawaited(_drainLocationUpdates(model));
                              }
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
                          onCameraIdle: () {
                            _compassIdleTick.value++;
                          },
                          onMapIdle: () {
                            if (!_initialRatingsAwaitingMapIdle ||
                                _initialContentReady ||
                                !mounted) {
                              return;
                            }
                            setState(() {
                              _initialRatingsAwaitingMapIdle = false;
                              _initialContentReady = true;
                            });
                          },
                        ),
                      ),
                    ),
                  if (model.navigationStarted &&
                      model.locationState ==
                          LocationState.FOLLOW_AND_ROTATE_MAP)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.navigation,
                                color: Color(0xff1976d2),
                                size: 25,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: MapNavigationHeaderBar(
                            model: model,
                            onRefreshRoute: () =>
                                _refreshRouteAndResumeNavigation(model),
                            onStartNavigation: () => _startNavigation(model),
                          ),
                        ),
                        if (model.destination != null)
                          const SizedBox(height: 4),
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (model.destination != null &&
                                  _styleLoaded &&
                                  _mapController != null)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: MapDestinationOffScreenOverlay(
                                      mapLayerKey: _mapLibreViewKey,
                                      controller: _mapController,
                                      destination: model.destination!,
                                    ),
                                  ),
                                ),
                              const MapAttribution(),
                              MapSideActionButtons(
                                model: model,
                                mapController: _mapController,
                                mapBearingDegrees: _mapBearingDegrees,
                                compassIdleTick: _compassIdleTick,
                                onNorthUp: () async {
                                  model.onCompassNorthUpPressed();
                                  final c = _mapController;
                                  if (c != null) {
                                    await c.animateCamera(
                                        CameraUpdate.bearingTo(0));
                                    await _syncCompassBearingFromMap();
                                  }
                                },
                                queryMapBearingDegrees: () async {
                                  final c = _mapController;
                                  if (c == null) return null;
                                  final pos = await c.queryCameraPosition();
                                  return pos?.bearing;
                                },
                                onPressLocation: () async {
                                  await model.onPressLocationBtn();
                                  if (!mounted) return;
                                  await _applyNativeLocationTracking(model);
                                  _updateLocationStream(model);
                                },
                              ),
                              MapBottomActionButtons(model: model),
                              if (kStoreScreenshots) ...[
                                StoreScreenshotMapReadySemantics(
                                  storeIdleReady: storeIdleReady,
                                  storeRouteReady: storeRouteReady,
                                ),
                                StoreScreenshotControls(model: model),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_initialContentReady)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: IgnorePointer(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                              child: Material(
                                color: Colors.white,
                                elevation: 4,
                                shadowColor: Colors.black38,
                                borderRadius: BorderRadius.circular(14),
                                child: Semantics(
                                  label: 'Karte und Bewertungen werden geladen',
                                  liveRegion: true,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                          ),
                                        ),
                                        SizedBox(width: 14),
                                        Flexible(
                                          child: Text(
                                            'Karte und Bewertungen werden geladen …',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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

  Future<void> _applyStoreScreenshotIdleCamera() async {
    if (!mounted || !kStoreScreenshots || _storeScreenshotIdleCameraDone) {
      return;
    }
    final c = _mapController;
    if (c == null) return;
    try {
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_stachus.latitude, _stachus.longitude),
            zoom: 14,
            bearing: 0,
          ),
        ),
      );
    } catch (_) {
      // Map may not be ready; idle semantics will not flip and the test can time out.
    }
    if (!mounted) return;
    setState(() {
      _storeScreenshotIdleCameraDone = true;
    });
  }

  MyLocationTrackingMode _trackingModeFor(LocationState state) {
    return MyLocationTrackingMode.none;
  }

  MyLocationRenderMode _renderModeFor(LocationState state) {
    return MyLocationRenderMode.normal;
  }

  /// On Android the widget-property update for tracking mode may race with the
  /// platform channel; calling the controller directly guarantees it is applied.
  Future<void> _applyNativeLocationTracking(MapScreenViewModel model) async {
    await _mapController?.updateMyLocationTrackingMode(
      _trackingModeFor(model.locationState),
    );
  }

  LocationSettings _locationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 250),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  void _updateLocationStream(MapScreenViewModel model) {
    if (model.locationState == LocationState.NOT_AVAILABLE) {
      _locationSubscription?.cancel();
      _locationSubscription = null;
      return;
    }
    if (_locationSubscription != null) return;

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen(
      (position) {
        _latestPosition = position;
        _pendingPosition = position;
        unawaited(_drainLocationUpdates(model));
      },
      onError: (Object error, StackTrace stackTrace) {
        log.w('location stream error', error: error, stackTrace: stackTrace);
      },
    );
  }

  Future<void> _drainLocationUpdates(MapScreenViewModel model) async {
    if (_locationRenderRunning) return;
    _locationRenderRunning = true;
    try {
      while (_pendingPosition != null) {
        final position = _pendingPosition!;
        _pendingPosition = null;
        await _renderLocation(model, position);
      }
    } finally {
      _locationRenderRunning = false;
    }
  }

  Future<void> _renderLocation(
    MapScreenViewModel model,
    Position position,
  ) async {
    final controller = _mapController;
    if (!mounted || !_styleLoaded || controller == null) return;
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        !position.accuracy.isFinite ||
        position.accuracy > 50) {
      return;
    }

    final rawPosition = latlong2.LatLng(position.latitude, position.longitude);
    var displayedPosition = rawPosition;
    final routePoints = model.route.route?.points;
    if (model.navigationStarted &&
        routePoints != null &&
        routePoints.length >= 2) {
      final snapDistance = (position.accuracy * 1.5).clamp(15.0, 30.0);
      displayedPosition = RoutePositionSnapper.snap(
        rawPosition,
        routePoints,
        maxDistanceMeters: snapDistance,
      );
    }

    final mapPosition = LatLng(
      displayedPosition.latitude,
      displayedPosition.longitude,
    );
    final showDirectionPuck = model.navigationStarted &&
        model.locationState == LocationState.FOLLOW_AND_ROTATE_MAP;
    try {
      final circle = _locationCircle;
      if (circle == null) {
        _locationCircle = await controller.addCircle(CircleOptions(
          geometry: mapPosition,
          circleRadius: showDirectionPuck ? 0 : 5,
          circleColor: '#1976d2',
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ));
      } else {
        await controller.updateCircle(
          circle,
          CircleOptions(
            geometry: mapPosition,
            circleRadius: showDirectionPuck ? 0 : 5,
          ),
        );
      }

      final state = model.locationState;
      if (state != LocationState.FOLLOW &&
          state != LocationState.FOLLOW_AND_ROTATE_MAP) {
        _smoothedMovementBearing = null;
        return;
      }
      if (state == LocationState.FOLLOW) {
        _smoothedMovementBearing = null;
      }

      var bearing = state == LocationState.FOLLOW_AND_ROTATE_MAP
          ? _mapBearingDegrees.value
          : 0.0;
      final headingAvailable = position.heading.isFinite &&
          position.heading >= 0 &&
          position.heading < 360 &&
          position.speed.isFinite &&
          position.speed >= 1 &&
          (position.heading != 0 || position.headingAccuracy > 0);
      if (state == LocationState.FOLLOW_AND_ROTATE_MAP && headingAvailable) {
        bearing = _smoothBearing(
          _smoothedMovementBearing,
          position.heading,
        );
        _smoothedMovementBearing = bearing;
      }

      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: mapPosition,
            zoom: _safeZoom(controller.cameraPosition?.zoom),
            bearing: bearing,
          ),
        ),
      );
    } catch (error, stackTrace) {
      log.d(
        'render location skipped while map is updating',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  double _smoothBearing(double? previous, double target) {
    if (previous == null) return target;
    final delta = (target - previous + 540) % 360 - 180;
    return (previous + delta * 0.25 + 360) % 360;
  }

  Future<void> _startNavigation(MapScreenViewModel model) async {
    // Camera animations performed after entering native tracking can trigger
    // onCameraTrackingDismissed. Set the navigation zoom first, then enable
    // follow-and-rotate so the final state remains native location tracking.
    await _mapController?.animateCamera(CameraUpdate.zoomTo(18));
    if (!mounted) return;

    final started = await model.startNavigation();
    if (!mounted || !started) return;

    // Let MapLibreMap rebuild with myLocationEnabled and GPS tracking before
    // applying the same mode directly through the platform controller.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _applyNativeLocationTracking(model);
    _updateLocationStream(model);
  }

  Future<void> _refreshRouteAndResumeNavigation(
      MapScreenViewModel model) async {
    final routeUpdated = await model.refreshRoute();
    if (!mounted || !routeUpdated) return;
    await _startNavigation(model);
  }

  Future<void> _primeLocationOnStart(
    MapScreenViewModel model, {
    bool permissionCheck = true,
  }) async {
    await model.refreshCurrentLocationFix();
    await model.onPressLocationBtn(permissionCheck: permissionCheck);
    if (!mounted) return;
    await _applyNativeLocationTracking(model);
    _updateLocationStream(model);
  }

  Future<void> _refreshLocationOnResume(MapScreenViewModel model) async {
    if (model.locationState == LocationState.NOT_AVAILABLE) return;
    await model.refreshCurrentLocationFix();
    if (!mounted) return;
    await _applyNativeLocationTracking(model);
    _updateLocationStream(model);
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    return true;
  }

  double _safeZoom(double? zoom) {
    if (zoom == null || !zoom.isFinite) return 15;
    return zoom.clamp(10, 22);
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
      // Route is added first, then Radl-Netz (same anchor below basemap labels) so
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

    if (mounted && kStoreScreenshots) {
      final pts = model.route.route?.points;
      final hasRoute = model.route.state == MapRouteState.SHOWN &&
          pts != null &&
          pts.isNotEmpty;
      setState(() {
        _storeScreenshotRouteVisualReady = hasRoute;
      });
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
        lineWidth: MapOverlayLineStyle.routeLineWidthByZoom,
      ),
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
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
    // Route must exist before Radl-Netz layers: all use the same basemap label
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
        lineWidth: MapOverlayLineStyle.gesamtNetzLineWidthByZoom,
        lineOpacity: MapOverlayLineStyle.gesamtNetzLineOpacityByZoom,
        lineCap: 'round',
        lineJoin: 'round',
        lineDasharray: [1.25, 2],
      ),
      filter: [
        Expressions.equal,
        [Expressions.get, 'gesamtnetz'],
        true
      ],
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerVisibleRadlId,
      const LineLayerProperties(
        lineColor: [Expressions.get, 'lineColor'],
        lineWidth: MapOverlayLineStyle.radlLineWidthByZoom,
        lineOpacity: MapOverlayLineStyle.radlLineOpacityByZoom,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        Expressions.equal,
        [Expressions.get, 'gesamtnetz'],
        false
      ],
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      enableInteraction: false,
    );
    // lineOpacity must stay > 0: some MapLibre builds skip hit-testing for fully
    // transparent lines, so taps never reach feature#onTap.
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerHitId,
      const LineLayerProperties(
        lineColor: '#000000',
        lineWidth: MapOverlayLineStyle.networkHitLineWidthByZoom,
        lineOpacity: 0.01,
      ),
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      enableInteraction: true,
    );
    _networkGeoJsonReady = true;
  }

  Future<void> _syncNetworkLayers(
      MapScreenViewModel model, MapLibreMapController controller) async {
    // Capture this before building the GeoJSON. The initial empty-layer sync can
    // overlap the ratings download; checking the live model only after the await
    // would then hide the loader even though this sync contains no ratings yet.
    final containsInitialLoadResult =
        model.initialLoadComplete && !model.loading;
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
    if (mounted && !_initialContentReady && containsInitialLoadResult) {
      // setGeoJsonSource completes when the data has been handed to MapLibre.
      // Keep showing the loader until onMapIdle confirms that these ratings
      // have also been rendered.
      _initialRatingsAwaitingMapIdle = true;
    }
    if (mounted && kStoreScreenshots) {
      setState(() {
        _storeScreenshotNetworkSynced = true;
      });
    }
  }
}
