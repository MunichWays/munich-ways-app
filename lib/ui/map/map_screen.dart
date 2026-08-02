import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/localization/app_localizations.dart';
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
import 'package:munich_ways/ui/map/map_loading_overlay.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/street_details_modal_listener.dart';
import 'package:munich_ways/ui/map/map_destination_offscreen_overlay.dart';
import 'package:munich_ways/ui/map/network_geojson.dart';
import 'package:munich_ways/ui/map/route_position_snapper.dart';
import 'package:munich_ways/ui/map/route_planner_sheet.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:provider/provider.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  static const latlong2.LatLng _stachus = latlong2.LatLng(48.14, 11.5652);
  static const _voiceSignalWarningDelay = Duration(seconds: 30);
  static const _notificationPermissionChannel =
      MethodChannel('com.munichways.app/notification_permission');

  static const _kNetworkSourceId = 'munichways_radlnetz';
  static const _kNetworkLayerVisibleGesamtId =
      'munichways_radlnetz_lines_gesamt';
  static const _kNetworkLayerCasingGesamtId =
      'munichways_radlnetz_casing_gesamt';
  static const _kNetworkLayerVisibleRadlId = 'munichways_radlnetz_lines_radl';
  static const _kNetworkLayerCasingRadlId = 'munichways_radlnetz_casing_radl';
  static const _kNetworkLayerHitGesamtId = 'munichways_radlnetz_hit_gesamt';
  static const _kNetworkLayerHitRadlId = 'munichways_radlnetz_hit_radl';
  static const _kRadlVorrangMinZoom = 8.0;
  static const _kGesamtnetzMinZoom = 13.0;

  /// Cycling route as GeoJSON (not [Line] annotation). Layer order: route, then
  /// Radl-Netz lines (gesamt, radl, hit), then basemap labels (water, streets, …)
  /// — all anchored with [kOpenFreeMapBasemapOverlayBelowLayerId] so the route never
  /// depends on network layer ids being present.
  static const _kRouteSourceId = 'munichways_route';
  static const _kRouteLayerId = 'munichways_route_line';
  static const _kRouteConnectorSourceId = 'munichways_route_connector';
  static const _kRouteConnectorLayerId = 'munichways_route_connector_line';

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey();
  final GlobalKey _mapLibreViewKey = GlobalKey(debugLabel: 'maplibre_map');

  bool displayCurrentLocationOnResume = false;
  late MapScreenViewModel mapViewModel;

  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _cameraReady = false;
  bool _cameraUpdateRunning = false;
  bool _firstCameraUpdate = true;
  CameraUpdate? _pendingCameraUpdate;
  bool _initialContentReady = false;
  bool _mapReadyNotified = false;
  bool _locationPrimeStarted = false;
  bool _overlaySyncScheduled = false;
  bool _overlaySyncRunning = false;
  bool _overlaySyncQueued = false;

  /// Line / GeoJSON feature id → street details (network taps + legacy line taps).
  final Map<String, StreetDetails> _streetDetailsByLineId = {};
  bool _networkGeoJsonReady = false;
  bool _routeGeoJsonReady = false;
  bool _featureTapHandlerAttached = false;
  Circle? _destinationCircle;
  final List<Circle> _routePlanCircles = [];
  StreamSubscription<Position>? _locationSubscription;
  bool _locationStreamUsesForegroundService = false;
  int _locationStreamGeneration = 0;
  Position? _latestPosition;
  Position? _pendingPosition;
  bool _locationRenderRunning = false;
  latlong2.LatLng? _lastLocationCameraPosition;
  double? _lastLocationCameraBearing;
  double? _smoothedMovementBearing;
  final FlutterTts _flutterTts = FlutterTts();
  final VoiceGuidance _voiceGuidance = VoiceGuidance();
  VoiceGuidanceDisplay? _nextManeuver;
  RoutePlannerMapSelection? _pendingRouteMapSelection;
  bool _nameNextMapSelection = false;
  Timer? _voiceSignalTimer;
  bool _notificationPermissionExplained = false;

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
  bool _initialRatingsRetryOffered = false;
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
    unawaited(_configureTextToSpeech());
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
    _voiceSignalTimer?.cancel();
    unawaited(_flutterTts.stop());
    _mapBearingDegrees.dispose();
    _compassIdleTick.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _configureTextToSpeech() async {
    try {
      await _flutterTts.setQueueMode(0);
      if (Platform.isAndroid) {
        await _flutterTts.setAudioAttributesForNavigation();
      } else if (Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
    } catch (error, stackTrace) {
      log.w(
        'Text-to-speech initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _speak(String text, {required bool english}) async {
    try {
      await _flutterTts.setLanguage(english ? 'en-US' : 'de-DE');
      await _flutterTts.stop();
      await _flutterTts.speak(text, focus: true);
    } catch (error, stackTrace) {
      log.w(
        'Voice guidance announcement failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _toggleVoiceGuidance(
    MapScreenViewModel model, {
    required bool english,
  }) {
    final enabled = !model.voiceGuidanceEnabled;
    model.setVoiceGuidanceEnabled(enabled);
    if (enabled) {
      unawaited(_speak(
        english ? 'Voice guidance enabled.' : 'Sprachansagen aktiviert.',
        english: english,
      ));
      _armVoiceSignalWarning(model);
    } else {
      _voiceSignalTimer?.cancel();
      unawaited(_flutterTts.stop());
    }
  }

  void _endRoute(MapScreenViewModel model) {
    _voiceGuidance.reset();
    _voiceSignalTimer?.cancel();
    if (_nextManeuver != null) {
      setState(() => _nextManeuver = null);
    }
    unawaited(_flutterTts.stop());
    model.clearDestination();
    unawaited(_updateLocationStream(model));
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
        model.startInitialLoad();

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
          unawaited(_scheduleCameraUpdate(
            CameraUpdate.newLatLngZoom(
              LatLng(location.latitude, location.longitude),
              max(currentZoom, 17),
            ),
          ));
        });
        model.destinationStream.listen((Place place) {
          _voiceGuidance.reset();
          if (_nextManeuver != null && mounted) {
            setState(() => _nextManeuver = null);
          }
          unawaited(_flutterTts.stop());
          final controller = _mapController;
          if (controller == null) return;
          if (!_isValidCoordinate(
              place.latLng.latitude, place.latLng.longitude)) {
            return;
          }
          final currentZoom = _safeZoom(controller.cameraPosition?.zoom);
          unawaited(_scheduleCameraUpdate(
            CameraUpdate.newLatLngZoom(
              LatLng(place.latLng.latitude, place.latLng.longitude),
              currentZoom,
            ),
          ));
        });
        model.routeStream.listen((MapRoute route) {
          final position = _latestPosition;
          if (model.navigationStarted) {
            if (position != null) {
              _refreshVoiceGuidance(model, position);
            }
            // A refreshed route must not trigger the pre-navigation overview
            // camera. It races with zoom 18 from _startNavigation and can leave
            // active navigation zoomed out to the full route bounds.
            return;
          }
          final controller = _mapController;
          if (controller == null || route.route == null) return;
          final validPoints = route.route!.points
              .where((p) => _isValidCoordinate(p.latitude, p.longitude))
              .toList();
          if (validPoints.isEmpty) return;

          if (validPoints.length == 1) {
            final currentZoom = _safeZoom(controller.cameraPosition?.zoom);
            unawaited(_scheduleCameraUpdate(
              CameraUpdate.newLatLngZoom(
                LatLng(validPoints.first.latitude, validPoints.first.longitude),
                currentZoom,
              ),
            ));
            return;
          }

          final bounds = _boundsFor(validPoints);
          unawaited(_scheduleCameraUpdate(
            CameraUpdate.newLatLngBounds(
              bounds,
              left: 24,
              top: 24,
              right: 24,
              bottom: 24,
            ),
          ));
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
            });
          }
          _scheduleOverlaySync(model);

          if (model.initialRatingsLoadFailed && !_initialRatingsRetryOffered) {
            _initialRatingsRetryOffered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _offerInitialRatingsReload(model);
            });
          }

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
                              const MinMaxZoomPreference(3, 22),
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
                                final details = mapViewModel
                                        .streetDetailsForFeatureId(line.id) ??
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
                                  if (layerId != _kNetworkLayerHitGesamtId &&
                                      layerId != _kNetworkLayerHitRadlId) {
                                    return;
                                  }
                                  final details = mapViewModel
                                          .streetDetailsForFeatureId(id) ??
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
                              _routePlanCircles.clear();
                              _streetDetailsByLineId.clear();
                              _lastSyncedNetworkFingerprint = null;
                              _lastRouteFingerprint = null;
                              setState(() {
                                _styleLoaded = true;
                                _cameraReady = false;
                                // Ratings are optional background content. The
                                // map is usable as soon as its style is ready.
                                _initialContentReady = true;
                                if (kStoreScreenshots) {
                                  _storeScreenshotNetworkSynced = false;
                                  _storeScreenshotIdleCameraDone = false;
                                  _storeScreenshotIdleCameraScheduled = false;
                                  _storeScreenshotRouteVisualReady = false;
                                }
                              });
                              _scheduleOverlaySync(model);
                              if (!kStoreScreenshots &&
                                  !_locationPrimeStarted) {
                                _locationPrimeStarted = true;
                                unawaited(_primeLocationOnStart(model));
                              }
                              final position = _latestPosition;
                              if (position != null) {
                                _pendingPosition = position;
                              }
                              unawaited(_activateCameraAfterStyle(model));
                            }

                            unawaited(afterStyle());
                          },
                          onMapLongClick: (screenPoint, latLng) {
                            unawaited(
                              _handleMapPlaceSelection(
                                model,
                                latlong2.LatLng(
                                  latLng.latitude,
                                  latLng.longitude,
                                ),
                              ),
                            );
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
                            _activateCamera(model);
                          },
                        ),
                      ),
                    ),
                  if (model.locationState == LocationState.FOLLOW ||
                      model.locationState ==
                          LocationState.FOLLOW_AND_ROTATE_MAP)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
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
                              child: model.locationState ==
                                      LocationState.FOLLOW_AND_ROTATE_MAP
                                  ? const Icon(
                                      Icons.navigation,
                                      color: Color(0xff1976d2),
                                      size: 25,
                                    )
                                  : const Center(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Color(0xff1976d2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: SizedBox(
                                          width: 12,
                                          height: 12,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (Platform.isAndroid)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: MediaQuery.paddingOf(context).top,
                      child: const ColoredBox(color: Colors.white),
                    ),
                  SafeArea(
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
                          additionalBottomOffset:
                              _sideControlsAdditionalBottomOffset(
                            context,
                            model,
                          ),
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
                        ),
                        MapBottomActionButtons(
                          model: model,
                          showSearch:
                              _initialContentReady && !model.navigationStarted,
                          onPlanRoute: () => _openRoutePlanner(model),
                          onSelectOnMap: () {
                            _nameNextMapSelection = true;
                          },
                          searchCenterProvider: () {
                            final position = _latestPosition;
                            return position == null
                                ? null
                                : latlong2.LatLng(
                                    position.latitude,
                                    position.longitude,
                                  );
                          },
                          onPressLocation: () async {
                            await model.onPressLocationBtn();
                            if (!mounted) return;
                            await _applyNativeLocationTracking(model);
                            await _updateLocationStream(model);
                          },
                          navigationBar: model.destination == null
                              ? null
                              : MapNavigationHeaderBar(
                                  model: model,
                                  onRefreshRoute: () =>
                                      _refreshRouteAndResumeNavigation(model),
                                  onEditRoute: () => _openRoutePlanner(model),
                                  onStartNavigation: () =>
                                      _startNavigation(model),
                                  onToggleVoiceGuidance: () =>
                                      _toggleVoiceGuidance(
                                    model,
                                    english: context.l10n.isEnglish,
                                  ),
                                  onEndRoute: () => _endRoute(model),
                                  nextManeuver: _nextManeuver,
                                ),
                        ),
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
                  if (model.loading)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: MapReloadingBanner(
                        message: model.initialLoadComplete
                            ? context.l10n.reloadingMap
                            : context.l10n.loadingRatingsInBackground,
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

  LocationSettings _locationSettings({
    required bool keepNavigationAliveInBackground,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: keepNavigationAliveInBackground
            ? ForegroundNotificationConfig(
                notificationTitle: context.l10n.isEnglish
                    ? 'MunichWays navigation'
                    : 'MunichWays Navigation',
                notificationText: context.l10n.isEnglish
                    ? 'Voice guidance and location remain active'
                    : 'Sprachansagen und Standort bleiben aktiv',
                notificationChannelName:
                    context.l10n.isEnglish ? 'Navigation' : 'Navigation',
                enableWakeLock: true,
                setOngoing: true,
                color: AppColors.mapAccentColor,
              )
            : null,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  Future<void> _updateLocationStream(MapScreenViewModel model) async {
    final generation = ++_locationStreamGeneration;
    if (model.locationState == LocationState.NOT_AVAILABLE) {
      final subscription = _locationSubscription;
      _locationSubscription = null;
      _locationStreamUsesForegroundService = false;
      await subscription?.cancel();
      return;
    }
    final shouldUseForegroundService =
        defaultTargetPlatform == TargetPlatform.android &&
            model.navigationStarted;
    if (_locationSubscription != null &&
        _locationStreamUsesForegroundService == shouldUseForegroundService) {
      return;
    }
    final previousSubscription = _locationSubscription;
    if (previousSubscription != null) {
      _locationSubscription = null;
      await previousSubscription.cancel();
      if (!mounted || generation != _locationStreamGeneration) return;
    }
    _locationStreamUsesForegroundService = shouldUseForegroundService;

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings(
        keepNavigationAliveInBackground: shouldUseForegroundService,
      ),
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
    if (_locationRenderRunning ||
        !mounted ||
        !_styleLoaded ||
        !_cameraReady ||
        _mapController == null) {
      return;
    }
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
    if (!mounted) return;
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        !position.accuracy.isFinite ||
        position.accuracy > 50) {
      return;
    }

    final rawPosition = latlong2.LatLng(position.latitude, position.longitude);
    model.updateWaypointProgress(rawPosition);
    _refreshVoiceGuidance(model, position);

    final controller = _mapController;
    if (!mounted || !_styleLoaded || !_cameraReady || controller == null) {
      return;
    }
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
    try {
      final state = model.locationState;
      if (state != LocationState.FOLLOW &&
          state != LocationState.FOLLOW_AND_ROTATE_MAP) {
        _smoothedMovementBearing = null;
        _lastLocationCameraPosition = null;
        _lastLocationCameraBearing = null;
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

      final previousPosition = _lastLocationCameraPosition;
      final movedMeters = previousPosition == null
          ? double.infinity
          : Geolocator.distanceBetween(
              previousPosition.latitude,
              previousPosition.longitude,
              displayedPosition.latitude,
              displayedPosition.longitude,
            );
      final previousBearing = _lastLocationCameraBearing;
      final bearingDelta = previousBearing == null
          ? double.infinity
          : ((bearing - previousBearing + 540) % 360 - 180).abs();
      final minimumMovementMeters = (position.accuracy * 0.25).clamp(3.0, 10.0);
      if (movedMeters < minimumMovementMeters &&
          (state != LocationState.FOLLOW_AND_ROTATE_MAP || bearingDelta < 5)) {
        return;
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
      _lastLocationCameraPosition = displayedPosition;
      _lastLocationCameraBearing = bearing;
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

  void _refreshVoiceGuidance(
    MapScreenViewModel model,
    Position position,
  ) {
    if (!mounted ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        !position.accuracy.isFinite ||
        position.accuracy > 50) {
      return;
    }

    _armVoiceSignalWarning(model);
    final rawPosition = latlong2.LatLng(position.latitude, position.longitude);
    _voiceGuidance.setRoute(
      model.navigationStarted ? model.route.route : null,
      intermediateDestinationNames:
          model.waypoints.map((place) => place.displayName).toList(),
    );
    final nextManeuver = model.navigationStarted
        ? _voiceGuidance.display(
            rawPosition,
            english: context.l10n.isEnglish,
            speedMetersPerSecond: position.speed,
          )
        : null;
    if (nextManeuver != _nextManeuver) {
      setState(() => _nextManeuver = nextManeuver);
    }
    if (model.navigationStarted && model.voiceGuidanceEnabled) {
      final instruction = _voiceGuidance.update(
        rawPosition,
        english: context.l10n.isEnglish,
        speedMetersPerSecond: position.speed,
      );
      if (instruction != null) {
        if (instruction.startsWith('Keine Ansage') ||
            instruction.startsWith('No directions')) {
          unawaited(_zoomOutAfterMissingDirections());
        }
        unawaited(_speak(
          instruction,
          english: context.l10n.isEnglish,
        ));
      }
    }
  }

  Future<void> _zoomOutAfterMissingDirections() async {
    final controller = _mapController;
    if (!mounted || controller == null) return;
    try {
      // `controller.cameraPosition` can remain at the value from before a
      // programmatic camera animation. Reading the native position prevents
      // subsequent warnings from repeatedly targeting the already active zoom.
      final position = await controller.queryCameraPosition();
      if (!mounted || controller != _mapController) return;
      final currentZoom = _safeZoom(
        position?.zoom ?? controller.cameraPosition?.zoom,
      );
      await controller.animateCamera(
        CameraUpdate.zoomTo((currentZoom - 2).clamp(3.0, 22.0)),
      );
    } catch (error, stackTrace) {
      log.d(
        'Zooming out after missing directions skipped while map is updating',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _offerInitialRatingsReload(MapScreenViewModel model) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final strings = context.l10n;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: Text(
            strings.isEnglish
                ? 'Ratings could not be loaded.'
                : 'Bewertungen konnten nicht geladen werden.',
          ),
          action: SnackBarAction(
            label: strings.reloadNetwork,
            onPressed: () {
              unawaited(_reloadRadnetzAfterInitialFailure(model));
            },
          ),
        ),
      );
  }

  Future<void> _reloadRadnetzAfterInitialFailure(
    MapScreenViewModel model,
  ) async {
    final updated = await model.reloadRadnetz();
    if (!mounted) return;
    final strings = context.l10n;
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            updated ? strings.mapUpdated : strings.mapUpdateFailed,
          ),
        ),
      );
  }

  Future<void> _startNavigation(MapScreenViewModel model) async {
    // Camera animations performed after entering native tracking can trigger
    // onCameraTrackingDismissed. Set the navigation zoom first, then enable
    // follow-and-rotate so the final state remains native location tracking.
    await _mapController?.animateCamera(CameraUpdate.zoomTo(18));
    if (!mounted) return;

    final started = await model.startNavigation();
    if (!mounted || !started) return;
    _armVoiceSignalWarning(model);
    await _requestNavigationNotificationPermission();
    if (!mounted) return;
    final position = _latestPosition;
    if (position != null) {
      _refreshVoiceGuidance(model, position);
    }

    // Let MapLibreMap rebuild with myLocationEnabled and GPS tracking before
    // applying the same mode directly through the platform controller.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _applyNativeLocationTracking(model);
    await _updateLocationStream(model);
  }

  Future<void> _openRoutePlanner(
    MapScreenViewModel model, {
    RoutePlannerMapSelection? initialPlan,
  }) async {
    if (!mounted) return;
    if (initialPlan == null) {
      _pendingRouteMapSelection = null;
    }
    final selection = await showRoutePlannerSheet(
      context,
      model: model,
      searchCenter: _latestPosition == null
          ? null
          : latlong2.LatLng(
              _latestPosition!.latitude,
              _latestPosition!.longitude,
            ),
      initialPlan: initialPlan,
    );
    if (!mounted || selection == null) return;

    _pendingRouteMapSelection = selection;
    final pointName = switch (selection.type) {
      RoutePlannerPointType.start =>
        context.l10n.isEnglish ? 'start' : 'Startpunkt',
      RoutePlannerPointType.stop =>
        context.l10n.isEnglish ? 'intermediate stop' : 'Zwischenziel',
      RoutePlannerPointType.destination =>
        context.l10n.isEnglish ? 'destination' : 'Ziel',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.isEnglish
              ? 'Touch and hold the $pointName on the map.'
              : '$pointName auf der Karte lange antippen.',
        ),
      ),
    );
  }

  Future<void> _handleMapPlaceSelection(
    MapScreenViewModel model,
    latlong2.LatLng position,
  ) async {
    // MapLibre invokes this from a platform callback. Defer route changes until
    // Flutter has finished the current frame before mounting a dialog.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final pendingSelection = _pendingRouteMapSelection;
    final shouldNamePlace = _nameNextMapSelection || pendingSelection != null;
    _nameNextMapSelection = false;
    if (!shouldNamePlace) {
      model.setDestination(Place(null, position));
      return;
    }

    var enteredName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canSave = enteredName.trim().isNotEmpty;
          return AlertDialog(
            title: Text(
              context.l10n.isEnglish ? 'Name this place' : 'Punkt benennen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            content: TextField(
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: context.l10n.isEnglish
                    ? 'e.g. hotel or station'
                    : 'z. B. Hotel oder Bahnhof',
              ),
              onChanged: (value) {
                setDialogState(() => enteredName = value);
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, value);
                }
              },
            ),
            actions: [
              SizedBox(
                width: 152,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    context.l10n.isEnglish ? 'Skip' : 'Überspringen',
                    maxLines: 1,
                  ),
                ),
              ),
              SizedBox(
                width: 152,
                child: FilledButton(
                  onPressed: canSave
                      ? () => Navigator.pop(dialogContext, enteredName)
                      : null,
                  child: Text(
                    context.l10n.isEnglish ? 'Save' : 'Speichern',
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    // Let the dialog route and its inherited dependencies deactivate fully
    // before opening the route planner again.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final trimmedName = name?.trim();
    final place = Place(
      trimmedName == null || trimmedName.isEmpty ? null : trimmedName,
      position,
    );
    if (place.displayName != null) {
      try {
        await recentSearchesRepo.add(place);
      } catch (error, stackTrace) {
        log.w(
          'Saving map-selected place failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (!mounted) return;

    if (pendingSelection == null) {
      model.setDestination(place);
      return;
    }
    _pendingRouteMapSelection = null;
    await _openRoutePlanner(
      model,
      initialPlan: pendingSelection.withSelectedPlace(place),
    );
  }

  Future<void> _requestNavigationNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final granted = await _notificationPermissionChannel
              .invokeMethod<bool>('isGranted') ??
          false;
      if (granted || !mounted) return;

      if (!_notificationPermissionExplained) {
        final proceed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(
                  context.l10n.isEnglish
                      ? 'Allow navigation notifications?'
                      : 'Navigations-Mitteilungen erlauben?',
                ),
                content: Text(
                  context.l10n.isEnglish
                      ? 'So spoken directions continue when the screen is off.'
                      : 'Damit Sprachansagen auch bei ausgeschaltetem Bildschirm '
                          'weiterlaufen.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(
                      context.l10n.isEnglish ? 'Not now' : 'Nicht jetzt',
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(
                      context.l10n.isEnglish ? 'Continue' : 'Weiter',
                    ),
                  ),
                ],
              ),
            ) ??
            false;
        _notificationPermissionExplained = true;
        if (!proceed || !mounted) return;
      }
      await _notificationPermissionChannel.invokeMethod<bool>('request');
    } on PlatformException catch (error, stackTrace) {
      log.w(
        'Requesting navigation notification permission failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _armVoiceSignalWarning(MapScreenViewModel model) {
    _voiceSignalTimer?.cancel();
    if (!model.navigationStarted || !model.voiceGuidanceEnabled) return;
    _voiceSignalTimer = Timer(_voiceSignalWarningDelay, () {
      if (!mounted || !model.navigationStarted || !model.voiceGuidanceEnabled) {
        return;
      }
      unawaited(_zoomOutAfterMissingDirections());
      unawaited(
        _speak(
          context.l10n.isEnglish
              ? 'No directions. Route may have been left or no GPS signal.'
              : 'Keine Ansage. Route möglicherweise verlassen oder kein GPS-Signal.',
          english: context.l10n.isEnglish,
        ),
      );
    });
  }

  Future<void> _refreshRouteAndResumeNavigation(
      MapScreenViewModel model) async {
    final routeUpdated = await model.refreshRoute();
    if (!mounted || !routeUpdated) return;
    // A successful refresh resumes navigation exactly like the Start action:
    // navigation zoom, location tracking and direction-based map rotation.
    await _startNavigation(model);
  }

  Future<void> _primeLocationOnStart(
    MapScreenViewModel model, {
    bool permissionCheck = true,
  }) async {
    await model.onPressLocationBtn(permissionCheck: permissionCheck);
    if (!mounted) return;
    await _applyNativeLocationTracking(model);
    await _updateLocationStream(model);
    final cachedPosition = await Geolocator.getLastKnownPosition();
    if (!mounted || cachedPosition == null) return;
    _latestPosition = cachedPosition;
    _pendingPosition = cachedPosition;
    unawaited(_drainLocationUpdates(model));
  }

  Future<void> _refreshLocationOnResume(MapScreenViewModel model) async {
    if (model.locationState == LocationState.NOT_AVAILABLE) return;
    final locationAvailable = await model.refreshCurrentLocationFix();
    if (!mounted) return;
    if (!locationAvailable) {
      await _applyNativeLocationTracking(model);
      await _updateLocationStream(model);
      return;
    }
    await _applyNativeLocationTracking(model);
    await _updateLocationStream(model);
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    return true;
  }

  double _safeZoom(double? zoom) {
    if (zoom == null || !zoom.isFinite) return 15;
    return zoom.clamp(3, 22);
  }

  Future<void> _activateCameraAfterStyle(MapScreenViewModel model) async {
    await WidgetsBinding.instance.endOfFrame;
    // Give the native platform view one layout pass after Flutter's frame.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted || !_styleLoaded || _cameraReady) return;

    final renderObject = _mapLibreViewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        renderObject.size.isEmpty) {
      return;
    }
    _activateCamera(model);
  }

  void _activateCamera(MapScreenViewModel model) {
    if (!mounted || !_styleLoaded || _cameraReady) return;
    _cameraReady = true;
    unawaited(_flushPendingCameraUpdate());
    final position = _latestPosition;
    if (position != null) {
      _pendingPosition = position;
      unawaited(_drainLocationUpdates(model));
    }
  }

  /// Defers camera operations until MapLibre has completed its first native
  /// render. Calling `animateCamera` earlier can abort MapLibre iOS inside
  /// `TransformState::constrainCameraAndZoomToBounds`.
  Future<void> _scheduleCameraUpdate(CameraUpdate update) async {
    _pendingCameraUpdate = update;
    await _flushPendingCameraUpdate();
  }

  Future<void> _flushPendingCameraUpdate() async {
    if (!mounted || !_styleLoaded || !_cameraReady || _cameraUpdateRunning) {
      return;
    }
    final controller = _mapController;
    final update = _pendingCameraUpdate;
    if (controller == null || update == null) return;

    _pendingCameraUpdate = null;
    _cameraUpdateRunning = true;
    try {
      // Avoid MapLibre's native easeTo path for the first iOS camera update.
      // This is the path confirmed by the TestFlight SIGABRT reports.
      if (Platform.isIOS && _firstCameraUpdate) {
        await controller.moveCamera(update);
      } else {
        await controller.animateCamera(update);
      }
      _firstCameraUpdate = false;
    } catch (error, stackTrace) {
      log.w(
        'Map camera update failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _cameraUpdateRunning = false;
    }

    if (_pendingCameraUpdate != null) {
      await _flushPendingCameraUpdate();
    }
  }

  double _sideControlsAdditionalBottomOffset(
    BuildContext context,
    MapScreenViewModel model,
  ) {
    final desiredOffset = model.destination == null
        ? 0.0
        : !model.navigationStarted
            ? 128.0
            : _nextManeuver != null
                ? 144.0
                : 72.0;
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      // Landscape has much less vertical room. Capping the offset keeps zoom
      // and compass controls on-screen while the width-limited route panel
      // remains clear below them.
      return min(desiredOffset, 80.0);
    }
    return desiredOffset;
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
      model.networkRevision,
      pl.length,
    );
    for (final p in pl) {
      final points = p.points;
      h = Object.hash(
        h,
        p.details?.munichwaysId,
        p.details?.cartoDbId,
        p.details?.farbe,
        p.details?.lastUpdated,
        points?.length,
        points?.firstOrNull?.latitude,
        points?.firstOrNull?.longitude,
        points?.lastOrNull?.latitude,
        points?.lastOrNull?.longitude,
      );
    }
    return h;
  }

  int _routeFingerprint(MapScreenViewModel model) {
    final r = model.route.route;
    final pts = r?.points;
    final connector = r?.destinationConnector;
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
      connector?.length,
      connector?.firstOrNull?.latitude,
      connector?.firstOrNull?.longitude,
      connector?.lastOrNull?.latitude,
      connector?.lastOrNull?.longitude,
      model.destination?.latLng.latitude,
      model.destination?.latLng.longitude,
      model.routeStart?.latLng.latitude,
      model.routeStart?.latLng.longitude,
      Object.hashAll(
        model.waypoints.expand(
          (place) => [
            place.latLng.latitude,
            place.latLng.longitude,
          ],
        ),
      ),
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
    for (final circle in _routePlanCircles) {
      await controller.removeCircle(circle);
    }
    _routePlanCircles.clear();

    if (model.route.state == MapRouteState.SHOWN && model.route.route != null) {
      final route = model.route.route!;
      await controller.setGeoJsonSource(_kRouteSourceId, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates':
                  route.points.map((p) => [p.longitude, p.latitude]).toList(),
            },
          },
        ],
      });
      await controller.setGeoJsonSource(_kRouteConnectorSourceId, {
        'type': 'FeatureCollection',
        'features': route.destinationConnector.length < 2
            ? <dynamic>[]
            : [
                {
                  'type': 'Feature',
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': route.destinationConnector
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
      await controller.setGeoJsonSource(_kRouteConnectorSourceId, {
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

    final customStart = model.routeStart;
    if (customStart != null) {
      _routePlanCircles.add(
        await controller.addCircle(
          CircleOptions(
            geometry: LatLng(
              customStart.latLng.latitude,
              customStart.latLng.longitude,
            ),
            circleRadius: 7,
            circleColor: '#2E7D32',
            circleStrokeColor: '#ffffff',
            circleStrokeWidth: 2.5,
          ),
        ),
      );
    }

    for (final waypoint in model.waypoints) {
      _routePlanCircles.add(
        await controller.addCircle(
          CircleOptions(
            geometry: LatLng(
              waypoint.latLng.latitude,
              waypoint.latLng.longitude,
            ),
            circleRadius: 6.5,
            circleColor: '#FF9800',
            circleStrokeColor: '#ffffff',
            circleStrokeWidth: 2.5,
          ),
        ),
      );
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
      await controller.removeLayer(_kRouteConnectorLayerId);
      await controller.removeSource(_kRouteSourceId);
      await controller.removeSource(_kRouteConnectorSourceId);
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
    await controller.addGeoJsonSource(_kRouteConnectorSourceId, {
      'type': 'FeatureCollection',
      'features': <dynamic>[],
    });
    await controller.addLineLayer(
      _kRouteSourceId,
      _kRouteLayerId,
      LineLayerProperties(
        lineColor: _hexColor(AppColors.mapRouteColor),
        lineWidth: MapOverlayLineStyle.routeLineWidthByZoom,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _kRouteConnectorSourceId,
      _kRouteConnectorLayerId,
      LineLayerProperties(
        lineColor: _hexColor(AppColors.mapRouteColor),
        lineWidth: MapOverlayLineStyle.routeLineWidthByZoom,
        lineCap: 'round',
        lineJoin: 'round',
        lineDasharray: const [1.5, 1.5],
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
      await controller.removeLayer(_kNetworkLayerHitRadlId);
      await controller.removeLayer(_kNetworkLayerHitGesamtId);
      await controller.removeLayer(_kNetworkLayerVisibleRadlId);
      await controller.removeLayer(_kNetworkLayerCasingRadlId);
      await controller.removeLayer(_kNetworkLayerVisibleGesamtId);
      await controller.removeLayer(_kNetworkLayerCasingGesamtId);
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
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerCasingGesamtId,
      const LineLayerProperties(
        lineColor: '#ffffff',
        lineWidth: MapOverlayLineStyle.networkCasingLineWidthByZoom,
        lineOpacity: 0.9,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        Expressions.equal,
        [Expressions.get, 'gesamtnetz'],
        true
      ],
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      minzoom: _kGesamtnetzMinZoom,
      enableInteraction: false,
    );
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
      minzoom: _kGesamtnetzMinZoom,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerCasingRadlId,
      const LineLayerProperties(
        lineColor: '#ffffff',
        lineWidth: MapOverlayLineStyle.networkCasingLineWidthByZoom,
        lineOpacity: 0.9,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        Expressions.equal,
        [Expressions.get, 'gesamtnetz'],
        false
      ],
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      minzoom: _kRadlVorrangMinZoom,
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
      minzoom: _kRadlVorrangMinZoom,
      enableInteraction: false,
    );
    // lineOpacity must stay > 0: some MapLibre builds skip hit-testing for fully
    // transparent lines, so taps never reach feature#onTap.
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerHitGesamtId,
      const LineLayerProperties(
        lineColor: '#000000',
        lineWidth: MapOverlayLineStyle.networkHitLineWidthByZoom,
        lineOpacity: 0.01,
      ),
      filter: [
        Expressions.equal,
        [Expressions.get, 'gesamtnetz'],
        true
      ],
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      minzoom: _kGesamtnetzMinZoom,
      enableInteraction: true,
    );
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerHitRadlId,
      const LineLayerProperties(
        lineColor: '#000000',
        lineWidth: MapOverlayLineStyle.networkHitLineWidthByZoom,
        lineOpacity: 0.01,
      ),
      filter: [
        Expressions.equal,
        [Expressions.get, 'gesamtnetz'],
        false
      ],
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      minzoom: _kRadlVorrangMinZoom,
      enableInteraction: true,
    );
    _networkGeoJsonReady = true;
  }

  Future<void> _syncNetworkLayers(
      MapScreenViewModel model, MapLibreMapController controller) async {
    final stopwatch = Stopwatch()..start();
    final visiblePolylines = model.polylines.toList();
    log.d(
      'network layer sync started: ${visiblePolylines.length} polylines, '
      'revision=${model.networkRevision}',
    );
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
    stopwatch.stop();
    log.d(
      'network layer sync finished: ${result.detailsByFeatureId.length} '
      'features in ${stopwatch.elapsedMilliseconds} ms',
    );
    if (mounted && kStoreScreenshots) {
      setState(() {
        _storeScreenshotNetworkSynced = true;
      });
    }
  }
}
