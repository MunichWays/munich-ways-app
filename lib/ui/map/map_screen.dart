import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/api/poi_geojson_repository.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/poi_details.dart';
import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:munich_ways/ui/map/map_attribution.dart';
import 'package:munich_ways/ui/map/vector_basemap_constants.dart';
import 'package:munich_ways/ui/map/dark_map_style.dart';
import 'package:munich_ways/ui/map/map_overlay_line_style.dart';
import 'package:munich_ways/screenshots/store_screenshot_config.dart';
import 'package:munich_ways/screenshots/store_screenshot_controls.dart';
import 'package:munich_ways/screenshots/store_screenshot_map_ready_semantics.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_overlay/map_bottom_action_buttons.dart';
import 'package:munich_ways/ui/map/map_overlay/map_home_destination_sheet.dart';
import 'package:munich_ways/ui/map/map_overlay/map_navigation_header_bar.dart';
import 'package:munich_ways/ui/map/map_overlay/map_route_selection_panel.dart';
import 'package:munich_ways/ui/map/map_overlay/map_overlay_layout_constants.dart';
import 'package:munich_ways/ui/map/map_overlay/map_side_action_buttons.dart';
import 'package:munich_ways/ui/map/map_location_dialogs.dart';
import 'package:munich_ways/ui/map/map_long_press_action_sheet.dart';
import 'package:munich_ways/ui/map/map_loading_overlay.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/street_details_modal_listener.dart';
import 'package:munich_ways/ui/map/map_destination_offscreen_overlay.dart';
import 'package:munich_ways/ui/map/network_geojson.dart';
import 'package:munich_ways/ui/map/poi_geojson.dart';
import 'package:munich_ways/ui/map/route_position_snapper.dart';
import 'package:munich_ways/ui/map/route_overlap.dart';
import 'package:munich_ways/ui/map/route_planner_sheet.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';
import 'package:munich_ways/ui/info/info_sheet.dart';
import 'package:munich_ways/ui/poi_details/poi_details_sheet.dart';
import 'package:munich_ways/ui/app_theme_controller.dart';
import 'package:munich_ways/ui/map/map_overlay/map_settings_sheet.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:provider/provider.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

enum _RouteEndpointMove { start, destination }

@visibleForTesting
bool hasReliableMovementHeading({
  required double accuracy,
  required double heading,
  required double headingAccuracy,
  required double speed,
}) =>
    accuracy.isFinite &&
    accuracy <= 50 &&
    heading.isFinite &&
    heading >= 0 &&
    heading < 360 &&
    speed.isFinite &&
    speed >= 1 &&
    (heading != 0 || headingAccuracy > 0);

@visibleForTesting
bool isUsableMapPosition({
  required double latitude,
  required double longitude,
  required double accuracy,
}) =>
    latitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude.isFinite &&
    longitude >= -180 &&
    longitude <= 180 &&
    accuracy.isFinite &&
    accuracy <= 1000;

@visibleForTesting
bool isFreshCachedPosition(DateTime timestamp, DateTime now) {
  final age = now.difference(timestamp);
  return !age.isNegative && age <= const Duration(minutes: 15);
}

@visibleForTesting
String offRouteSpokenMessage({
  required bool english,
  required bool automaticRerouting,
  required bool firstAnnouncement,
  bool lastAutomaticAnnouncement = false,
}) {
  if (lastAutomaticAnnouncement) {
    return english
        ? 'Last automatic recalculation shortly. No further directions '
            'while off the route.'
        : 'Letzte automatische Neuberechnung in Kürze. Keine weiteren '
            'Ansagen außerhalb der Route.';
  }
  if (english) {
    return firstAnnouncement && automaticRerouting
        ? 'Route left. Recalculation follows.'
        : 'Route left.';
  }
  return firstAnnouncement && automaticRerouting
      ? 'Route verlassen. Neuberechnung folgt.'
      : 'Route verlassen.';
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  static const latlong2.LatLng _stachus = latlong2.LatLng(48.14, 11.5652);
  static const _voiceSignalWarningDelay = Duration(seconds: 30);
  static const _offRouteDisplayDelay = Duration(seconds: 2);
  static const _offRouteAnnouncementDelay = Duration(seconds: 12);
  static const _automaticRerouteDelay = Duration(seconds: 30);
  static const _maximumConsecutiveReroutes = 3;
  static const _onRouteDistanceToResetReroutes = 100.0;
  static const _onRouteDurationToResetReroutes = Duration(seconds: 60);
  static const _minimumOnRouteDistanceForTimedReset = 30.0;
  static const _maximumOnRouteProgressStep = 200.0;
  static const _navigationStartZoom = 18.0;
  static const _offRouteZoom = _navigationStartZoom - 2;
  static const _notificationPermissionChannel =
      MethodChannel('com.munichways.app/notification_permission');

  static const _kNetworkSourceId = 'munichways_radlnetz';
  static const _kRoutingCoverageSourceId = 'munichways_routing_coverage';
  static const _kRoutingCoverageLayerId = 'munichways_routing_coverage_outline';
  static const _kRoutingCoverageMaxZoom = 10.0;
  static const _kNetworkLayerVisibleGesamtId =
      'munichways_radlnetz_lines_gesamt';
  static const _kNetworkLayerDashedGesamtId =
      'munichways_radlnetz_lines_gesamt_dashed';
  static const _kNetworkLayerCasingGesamtId =
      'munichways_radlnetz_casing_gesamt';
  static const _kNetworkLayerVisibleRadlId = 'munichways_radlnetz_lines_radl';
  static const _kNetworkLayerDashedRadlId =
      'munichways_radlnetz_lines_radl_dashed';
  static const _kNetworkLayerCasingRadlId = 'munichways_radlnetz_casing_radl';
  static const _kNetworkLayerHitGesamtId = 'munichways_radlnetz_hit_gesamt';
  static const _kNetworkLayerHitRadlId = 'munichways_radlnetz_hit_radl';
  static const _kRadlVorrangMinZoom = 8.0;
  // Keep all ratings available in regional overviews without competing with
  // the priority cycling network at the widest zoom levels.
  static const _kGesamtnetzMinZoom = 10.0;
  static const _kCurrentLocationSourceId = 'munichways_current_location';
  static const _kCurrentLocationLayerId = 'munichways_current_location_dot';
  static const _kDrinkingWaterSourceId = 'munichways_drinking_water';
  static const _kDrinkingWaterLayerId = 'munichways_drinking_water_symbols';
  static const _kDrinkingWaterImageId = 'munichways_drinking_water_icon';
  static const _kPublicToiletsSourceId = 'munichways_public_toilets';
  static const _kPublicToiletsLayerId = 'munichways_public_toilets_symbols';
  static const _kPublicToiletsImageId = 'munichways_public_toilets_icon';
  static const _kRepairStationsSourceId = 'munichways_repair_stations';
  static const _kRepairStationsLayerId = 'munichways_repair_stations_symbols';
  static const _kRepairStationsImageId = 'munichways_repair_stations_icon';

  /// Cycling route as GeoJSON (not [Line] annotation). Layer order: route, then
  /// Radl-Netz lines (gesamt, radl, hit), then basemap labels (water, streets, …)
  /// — all anchored with [kOpenFreeMapBasemapOverlayBelowLayerId] so the route never
  /// depends on network layer ids being present.
  static const _kRouteSourceId = 'munichways_route';
  static const _kRouteLayerId = 'munichways_route_line';
  static const _kRouteConnectorSourceId = 'munichways_route_connector';
  static const _kRouteConnectorLayerId = 'munichways_route_connector_line';
  static const _kRouteOverlapSourceId = 'munichways_route_overlap';
  static const _kRouteOverlapLayerId = 'munichways_route_overlap_arrows';
  static const _kRouteOverlapImageId = 'route-overlap-arrow-pair-v4';

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
  Timer? _overlaySyncRetryTimer;
  Timer? _cameraSaveTimer;
  int _overlaySyncRetryCount = 0;

  /// Line / GeoJSON feature id → street details (network taps + legacy line taps).
  final Map<String, StreetDetails> _streetDetailsByLineId = {};
  bool _networkGeoJsonReady = false;
  bool _routingCoverageGeoJsonReady = false;
  bool _routingCoverageLoadStarted = false;
  bool _routingCoverageSyncRunning = false;
  Map<String, dynamic>? _routingCoverageGeoJson;
  bool _routeGeoJsonReady = false;
  bool _currentLocationGeoJsonReady = false;
  bool _drinkingWaterGeoJsonReady = false;
  bool _drinkingWaterLoadStarted = false;
  bool _drinkingWaterSyncRunning = false;
  bool _drinkingWaterSyncQueued = false;
  Future<void> _poiStyleOperationTail = Future<void>.value();
  Map<String, dynamic>? _drinkingWaterGeoJson;
  Completer<Map<String, dynamic>> _firstDrinkingWaterData = Completer();
  final PoiGeoJsonRepository _poiGeoJsonRepository = PoiGeoJsonRepository();
  StreamSubscription<Map<String, dynamic>>? _drinkingWaterSubscription;
  bool _publicToiletsGeoJsonReady = false;
  bool _publicToiletsLoadStarted = false;
  bool _publicToiletsSyncRunning = false;
  bool _publicToiletsSyncQueued = false;
  Map<String, dynamic>? _publicToiletsGeoJson;
  Completer<Map<String, dynamic>> _firstPublicToiletsData = Completer();
  StreamSubscription<Map<String, dynamic>>? _publicToiletsSubscription;
  bool _repairStationsGeoJsonReady = false;
  bool _repairStationsLoadStarted = false;
  bool _repairStationsSyncRunning = false;
  bool _repairStationsSyncQueued = false;
  Map<String, dynamic>? _repairStationsGeoJson;
  Completer<Map<String, dynamic>> _firstRepairStationsData = Completer();
  StreamSubscription<Map<String, dynamic>>? _repairStationsSubscription;
  final List<Symbol> _routePlanSymbols = [];
  latlong2.LatLng? _displayedRouteStartPoint;
  final Set<int> _routeWaypointImages = {};
  final Set<String> _routePointImages = {};
  StreamSubscription<Position>? _locationSubscription;
  bool _locationStreamUsesForegroundService = false;
  int _locationStreamGeneration = 0;
  Position? _latestPosition;
  final OberbayernCoverage _nearbyPoiCoverage = OberbayernCoverage();
  bool _showNearbyPois = false;
  int _nearbyCoverageCheckGeneration = 0;
  Position? _pendingPosition;
  bool _locationRenderRunning = false;
  latlong2.LatLng? _lastLocationCameraPosition;
  double? _lastLocationCameraBearing;
  double? _smoothedMovementBearing;
  latlong2.LatLng? _gpsMotionAnchor;
  double? _gpsMotionAnchorAccuracy;
  DateTime? _lastGpsMovementAt;
  bool _gpsStationary = true;
  bool _movementHeadingAvailable = false;
  Timer? _movementHeadingFreshnessTimer;
  final FlutterTts _flutterTts = FlutterTts();
  int _speechRequestGeneration = 0;
  final VoiceGuidance _voiceGuidance = VoiceGuidance(
    announceOffRouteWarning: false,
  );
  final NavigationStartGate _navigationStartGate = NavigationStartGate();
  VoiceGuidanceDisplay? _nextManeuver;
  VoiceGuidanceDisplay? _reroutingDisplay;
  RoutePlannerMapSelection? _pendingRouteMapSelection;
  _RouteEndpointMove? _pendingRouteEndpointMove;
  bool _nameNextMapSelection = false;
  Timer? _voiceSignalTimer;
  Timer? _offRouteDisplayTimer;
  Timer? _offRouteAnnouncementTimer;
  Timer? _automaticRerouteTimer;
  bool _offRouteEpisodeActive = false;
  bool _automaticRerouteCommitted = false;
  bool _initialGuidanceAnnouncementPending = false;
  bool _automaticReroutingSuspended = false;
  bool _offRouteCameraZoomedOut = false;
  int _consecutiveAutomaticReroutes = 0;
  int _offRouteAnnouncementCount = 0;
  double _onRouteDistanceSinceReroute = 0;
  latlong2.LatLng? _lastOnRoutePosition;
  DateTime? _onRouteSinceReroute;
  bool _notificationPermissionExplained = false;
  bool _mapAttributionExpanded = false;

  /// Map camera bearing (clockwise from north); [MapCompassControl] listens for
  /// visibility and [CompassButton] rotation. Updated in [MapLibreMap.onCameraMove].
  final ValueNotifier<double> _mapBearingDegrees = ValueNotifier<double>(0.0);

  /// Bumped on [MapLibreMap.onCameraIdle] so [MapCompassControl] can finish hide.
  final ValueNotifier<int> _compassIdleTick = ValueNotifier<int>(0);

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
  String? _mapStyleString;
  bool? _darkMapStyle;
  int _mapStyleGeneration = 0;
  bool _initialCameraLoaded = false;
  CameraPosition? _savedInitialCamera;

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
    unawaited(_loadInitialCamera());
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

  Future<void> _loadInitialCamera() async {
    CameraPosition? savedCamera;
    try {
      final settings = await settingsStore.load();
      final latitude = settings.mapLatitude;
      final longitude = settings.mapLongitude;
      final zoom = settings.mapZoom;
      final bearing = settings.mapBearing ?? 0;
      if (latitude != null &&
          longitude != null &&
          zoom != null &&
          _isValidCoordinate(latitude, longitude) &&
          zoom.isFinite &&
          zoom >= 3 &&
          zoom <= 22 &&
          bearing.isFinite) {
        savedCamera = CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: zoom,
          bearing: bearing,
        );
      }
    } catch (error, stackTrace) {
      log.w(
        'Loading saved map camera failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    setState(() {
      _savedInitialCamera = savedCamera;
      _initialCameraLoaded = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_darkMapStyle == dark) return;
    _darkMapStyle = dark;
    unawaited(_loadMapStyle(dark));
  }

  Future<void> _loadMapStyle(bool dark) async {
    String style;
    try {
      style = await rootBundle.loadString(kOpenFreeMapLibertyStyleAsset);
    } catch (error, stackTrace) {
      log.w(
        'Loading bundled map style failed; falling back to asset path',
        error: error,
        stackTrace: stackTrace,
      );
      style = kOpenFreeMapLibertyStyleAsset;
    }
    if (style != kOpenFreeMapLibertyStyleAsset) {
      style = dark ? createDarkMapStyle(style) : createCyclingMapStyle(style);
    }
    // Loading and transforming the bundled style is asynchronous. If the
    // theme changes again while it is in progress, an older request must not
    // overwrite the style for the current theme when it finishes last.
    if (!mounted || _darkMapStyle != dark) return;
    setState(() {
      // Recreate the native map for a new style instead of changing the style
      // underneath in-flight layer operations. In particular on Android,
      // callbacks from the previous style can otherwise race the new style and
      // leave overlays missing or crash the native map renderer.
      _mapStyleGeneration++;
      _mapController = null;
      _styleLoaded = false;
      _cameraReady = false;
      _networkGeoJsonReady = false;
      _routingCoverageGeoJsonReady = false;
      _routeGeoJsonReady = false;
      _currentLocationGeoJsonReady = false;
      _drinkingWaterGeoJsonReady = false;
      _publicToiletsGeoJsonReady = false;
      _repairStationsGeoJsonReady = false;
      _lastSyncedNetworkFingerprint = null;
      _lastRouteFingerprint = null;
      _mapStyleString = style;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cameraSaveTimer?.cancel();
      unawaited(_persistCameraPosition());
      return;
    }
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
    _drinkingWaterSubscription?.cancel();
    _publicToiletsSubscription?.cancel();
    _repairStationsSubscription?.cancel();
    _movementHeadingFreshnessTimer?.cancel();
    _overlaySyncRetryTimer?.cancel();
    _cameraSaveTimer?.cancel();
    _voiceSignalTimer?.cancel();
    _cancelAutomaticRerouting(resetAttempts: false);
    _stopVoiceGuidance();
    _mapBearingDegrees.dispose();
    _compassIdleTick.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _configureTextToSpeech() async {
    try {
      await _flutterTts.setQueueMode(0);
      await _flutterTts.setVolume(1.0);
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
    final generation = ++_speechRequestGeneration;
    try {
      await _flutterTts.setLanguage(english ? 'en-US' : 'de-DE');
      if (generation != _speechRequestGeneration || !mounted) return;
      // Keep navigation prompts at the TTS maximum. This is especially
      // important when the phone is muffled inside a handlebar bag.
      await _flutterTts.setVolume(1.0);
      if (generation != _speechRequestGeneration || !mounted) return;
      await _flutterTts.stop();
      if (generation != _speechRequestGeneration || !mounted) return;
      await _flutterTts.speak(text, focus: true);
    } catch (error, stackTrace) {
      log.w(
        'Voice guidance announcement failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _stopVoiceGuidance() {
    // Invalidate announcements which are still awaiting TTS setup. A plain
    // stop is insufficient: such a request could otherwise call speak after
    // navigation has already ended.
    _speechRequestGeneration++;
    unawaited(_flutterTts.stop());
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
      _stopVoiceGuidance();
    }
  }

  void _endRoute(MapScreenViewModel model) {
    _voiceGuidance.reset();
    _navigationStartGate.reset();
    _initialGuidanceAnnouncementPending = false;
    _voiceSignalTimer?.cancel();
    _cancelAutomaticRerouting();
    if (_nextManeuver != null) {
      setState(() => _nextManeuver = null);
    }
    _stopVoiceGuidance();
    model.clearDestination();
    unawaited(_updateLocationStream(model));
    // Native tracking changes can finish without onCameraMove. Explicitly
    // publish the retained bearing so the compass remains visible when the
    // route ends on a rotated map.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_syncCompassBearingFromMap());
      _compassIdleTick.value++;
    });
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
    final statusBarBackground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0B1218)
        : Colors.white;
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
          _navigationStartGate.reset();
          _initialGuidanceAnnouncementPending = false;
          _cancelAutomaticRerouting();
          if (_nextManeuver != null && mounted) {
            setState(() => _nextManeuver = null);
          }
          _stopVoiceGuidance();
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
        if (!kStoreScreenshots && !_locationPrimeStarted) {
          _locationPrimeStarted = true;
          // Location acquisition is independent of map/style loading. Starting
          // it here lets the first cached or live fix wait for the map instead
          // of making the user wait at the Stachus while both run serially.
          unawaited(_primeLocationOnStart(model));
        }
        return model;
      },
      child: Consumer<MapScreenViewModel>(
        builder: (context, model, child) {
          final mapStyleGeneration = _mapStyleGeneration;
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
          final bottomActionRowPadding = _mapAttributionExpanded
              ? kMapBottomActionRowExpandedPadding
              : kMapBottomActionRowCollapsedPadding;

          return ScaffoldMessenger(
            key: scaffoldMessengerKey,
            child: Scaffold(
              key: scaffoldKey,
              body: Stack(
                children: [
                  const StreetDetailsModalListener(),
                  if (!_mountMapView || _mapStyleString == null)
                    Positioned.fill(
                      child: ColoredBox(
                        color: statusBarBackground,
                        child: Center(
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ),
                      ),
                    ),
                  if (_mountMapView &&
                      _mapStyleString != null &&
                      _initialCameraLoaded)
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
                          key: ValueKey(mapStyleGeneration),
                          styleString: _mapStyleString!,
                          initialCameraPosition: _savedInitialCamera ??
                              CameraPosition(
                                target: LatLng(
                                  _stachus.latitude,
                                  _stachus.longitude,
                                ),
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
                            if (!mounted ||
                                mapStyleGeneration != _mapStyleGeneration) {
                              return;
                            }
                            _mapController = controller;
                          },
                          onStyleLoadedCallback: () {
                            if (!mounted ||
                                mapStyleGeneration != _mapStyleGeneration) {
                              return;
                            }
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
                              _routingCoverageGeoJsonReady = false;
                              _routeGeoJsonReady = false;
                              _currentLocationGeoJsonReady = false;
                              _drinkingWaterGeoJsonReady = false;
                              _publicToiletsGeoJsonReady = false;
                              _repairStationsGeoJsonReady = false;
                              if (!mounted ||
                                  mapStyleGeneration != _mapStyleGeneration ||
                                  !identical(c, _mapController)) {
                                return;
                              }
                              // Style rebuild clears native annotations; drop stale handles.
                              _routePlanSymbols.clear();
                              _routeWaypointImages.clear();
                              _routePointImages.clear();
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
                              _scheduleRoutingCoverageSync();
                              _startRoutingCoverageLoad();
                              _scheduleDrinkingWaterSync();
                              _schedulePublicToiletsSync();
                              _scheduleRepairStationsSync();
                              _startDrinkingWaterLoad();
                              _startPublicToiletsLoad();
                              _startRepairStationsLoad();
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
                              _handleMapLongPress(
                                model,
                                screenPoint,
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
                            _scheduleCameraPersistence();
                          },
                        ),
                      ),
                    ),
                  if (model.locationState ==
                          LocationState.FOLLOW_AND_ROTATE_MAP &&
                      _movementHeadingAvailable)
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
                            child: const SizedBox(
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
                  if (Platform.isAndroid)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: MediaQuery.paddingOf(context).top,
                      child: ColoredBox(color: statusBarBackground),
                    ),
                  Positioned.fill(
                    child: SafeArea(
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
                                  bottomActionRowPadding:
                                      bottomActionRowPadding,
                                ),
                              ),
                            ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 22,
                            child: IgnorePointer(
                              ignoring: !_mapAttributionExpanded,
                              child: MapAttribution(
                                expanded: _mapAttributionExpanded,
                                inline: true,
                              ),
                            ),
                          ),
                          MapSideActionButtons(
                            model: model,
                            mapController: _mapController,
                            mapBearingDegrees: _mapBearingDegrees,
                            compassIdleTick: _compassIdleTick,
                            bottomActionRowPadding:
                                kMapBottomActionRowCollapsedPadding,
                            additionalBottomOffset:
                                _sideControlsAdditionalBottomOffset(
                              context,
                              model,
                            ),
                            onNorthUp: () async {
                              model.onCompassNorthUpPressed();
                              final c = _mapController;
                              if (c != null) {
                                await c
                                    .animateCamera(CameraUpdate.bearingTo(0));
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
                              await _updateLocationStream(model);
                            },
                          ),
                          Positioned(
                            top: _mapAttributionExpanded ? 36 : 28,
                            right: 12,
                            child: Material(
                              color: Colors.transparent,
                              elevation: 0,
                              shape: const CircleBorder(),
                              child: SizedBox.square(
                                dimension: 36,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  iconSize: 15,
                                  tooltip: context.l10n.isEnglish
                                      ? 'Map attribution'
                                      : 'Kartenquellen',
                                  onPressed: () => setState(() {
                                    _mapAttributionExpanded =
                                        !_mapAttributionExpanded;
                                  }),
                                  icon: const Text(
                                    '©',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.munichWaysBlue,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (model.destination != null ||
                              model.initialRatingsLoadFailed)
                            MapBottomActionButtons(
                              model: model,
                              showSearch: false,
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
                              onReloadNetwork: () =>
                                  _reloadRadnetzAfterInitialFailure(model),
                              attributionExpanded: _mapAttributionExpanded,
                              onToggleAttribution: () => setState(() {
                                _mapAttributionExpanded =
                                    !_mapAttributionExpanded;
                              }),
                              navigationBar: model.destination == null
                                  ? null
                                  : MapNavigationHeaderBar(
                                      model: model,
                                      onRefreshRoute: () =>
                                          _refreshRouteAndResumeNavigation(
                                              model),
                                      onEditRoute: () =>
                                          _openRoutePlanner(model),
                                      onStartNavigation: () =>
                                          _startNavigation(model),
                                      onToggleVoiceGuidance: () =>
                                          _toggleVoiceGuidance(
                                        model,
                                        english: context.l10n.isEnglish,
                                      ),
                                      onShowInfo: () =>
                                          showMapInfoSheet(context),
                                      onShowSettings: () =>
                                          showMapSettingsSheet(
                                        context,
                                        model,
                                        onReloadMapData: () =>
                                            _reloadMapData(model),
                                      ),
                                      onEndRoute: () => _endRoute(model),
                                      nextManeuver: _nextManeuver,
                                    ),
                            ),
                          if (_initialContentReady &&
                              !model.navigationStarted &&
                              model.destination == null &&
                              _pendingRouteMapSelection == null)
                            MapHomeDestinationSheet(
                              searchCenter: _latestPosition == null
                                  ? null
                                  : latlong2.LatLng(
                                      _latestPosition!.latitude,
                                      _latestPosition!.longitude,
                                    ),
                              onSelected: (selection) {
                                if (selection is Place) {
                                  model.setDestination(selection);
                                } else if (selection is SavedRoute) {
                                  model.setSavedRoutePlan(selection);
                                }
                              },
                              onPlanRoute: () => _openRoutePlanner(model),
                              onNearbySelected: (type) =>
                                  _navigateToNearbyPoi(model, type),
                              showNearby: _showNearbyPois,
                              onSelectOnMap: () {
                                _nameNextMapSelection = true;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.l10n.tr(
                                        'Gewünschtes Ziel auf der Karte lange antippen.',
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onShowInfo: () => showMapInfoSheet(context),
                              onToggleAttribution: () => setState(() {
                                _mapAttributionExpanded =
                                    !_mapAttributionExpanded;
                              }),
                              onShowSettings: () => showMapSettingsSheet(
                                context,
                                model,
                                onReloadMapData: () => _reloadMapData(model),
                              ),
                              attributionExpanded: _mapAttributionExpanded,
                            ),
                          if (_pendingRouteMapSelection case final selection?)
                            MapRouteSelectionPanel(
                              type: selection.type,
                              onCancel: () => setState(() {
                                _pendingRouteMapSelection = null;
                              }),
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
        if (!isFreshCachedPosition(position.timestamp, DateTime.now()) ||
            !isUsableMapPosition(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
            )) {
          return;
        }
        _latestPosition = position;
        unawaited(_updateNearbyPoiAvailability(position));
        _pendingPosition = position;
        context
            .read<AppThemeController>()
            .updateLocation(position.latitude, position.longitude);
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
    _updateMovementHeadingAvailability(position);
    if (!isUsableMapPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    )) {
      return;
    }

    final rawPosition = latlong2.LatLng(position.latitude, position.longitude);
    final reliableForNavigation = position.accuracy <= 50;
    if (reliableForNavigation) {
      model.updateWaypointProgress(rawPosition);
      _refreshVoiceGuidance(model, position);
    }

    final controller = _mapController;
    if (!mounted || !_styleLoaded || !_cameraReady || controller == null) {
      return;
    }
    var displayedPosition = rawPosition;
    final routePoints = model.route.route?.points;
    if (reliableForNavigation &&
        model.navigationStarted &&
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
      await _showCurrentLocation(controller, mapPosition);
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
      final headingAvailable = _hasReliableMovementHeading(position);
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

  Future<void> _showCurrentLocation(
    MapLibreMapController controller,
    LatLng position,
  ) async {
    final geoJson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [position.longitude, position.latitude],
          },
          'properties': <String, dynamic>{},
        },
      ],
    };
    if (!_currentLocationGeoJsonReady) {
      await controller.addGeoJsonSource(_kCurrentLocationSourceId, geoJson);
      await controller.addCircleLayer(
        _kCurrentLocationSourceId,
        _kCurrentLocationLayerId,
        const CircleLayerProperties(
          circleRadius: 8,
          circleColor: '#1976d2',
          circleStrokeWidth: 4,
          circleStrokeColor: '#ffffff',
        ),
      );
      _currentLocationGeoJsonReady = true;
      return;
    }
    await controller.setGeoJsonSource(_kCurrentLocationSourceId, geoJson);
  }

  bool _hasReliableMovementHeading(Position position) =>
      hasReliableMovementHeading(
        accuracy: position.accuracy,
        heading: position.heading,
        headingAccuracy: position.headingAccuracy,
        speed: position.speed,
      );

  void _updateMovementHeadingAvailability(Position position) {
    _movementHeadingFreshnessTimer?.cancel();
    final available = _hasReliableMovementHeading(position);
    if (_movementHeadingAvailable != available && mounted) {
      setState(() => _movementHeadingAvailable = available);
    }
    if (!available) return;
    _movementHeadingFreshnessTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || !_movementHeadingAvailable) return;
      setState(() => _movementHeadingAvailable = false);
    });
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
    if (!model.navigationStarted) {
      _navigationStartGate.reset();
    }
    _voiceGuidance.setRoute(
      model.navigationStarted ? model.route.route : null,
      intermediateDestinationNames:
          model.waypoints.map((place) => place.displayName).toList(),
    );
    final routeGuidanceDisplay = model.navigationStarted
        ? _voiceGuidance.display(
            rawPosition,
            english: context.l10n.isEnglish,
            speedMetersPerSecond: position.speed,
          )
        : null;
    final waitingForInitialDirection = model.navigationStarted &&
        !_voiceGuidance.finalDestinationReached &&
        _navigationStartGate.isWaiting(rawPosition);
    if (waitingForInitialDirection) {
      if (_offRouteEpisodeActive || _reroutingDisplay != null) {
        _cancelAutomaticRerouting(resetAttempts: false);
      }
    } else {
      _updateAutomaticRerouting(model, rawPosition, position);
    }
    if (!waitingForInitialDirection && _initialGuidanceAnnouncementPending) {
      _initialGuidanceAnnouncementPending = false;
      if (!_offRouteEpisodeActive) {
        _announceCurrentGuidance(model, rawPosition, position.speed);
      }
    }
    final nextManeuver = model.navigationStarted
        ? _voiceGuidance.finalDestinationReached
            ? routeGuidanceDisplay
            : waitingForInitialDirection
                ? VoiceGuidanceDisplay(
                    text: context.l10n.followRouteOnMap,
                    type: 'map',
                  )
                : _reroutingDisplay ?? routeGuidanceDisplay
        : null;
    if (nextManeuver != _nextManeuver) {
      setState(() => _nextManeuver = nextManeuver);
    }
    if (model.navigationStarted &&
        model.voiceGuidanceEnabled &&
        !_automaticRerouteCommitted &&
        (!waitingForInitialDirection ||
            _voiceGuidance.finalDestinationReached)) {
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

  void _announceCurrentGuidance(
    MapScreenViewModel model,
    latlong2.LatLng position,
    double speedMetersPerSecond,
  ) {
    if (!mounted ||
        !model.navigationStarted ||
        !model.voiceGuidanceEnabled ||
        !model.voiceGuidanceAvailable) {
      return;
    }
    final english = context.l10n.isEnglish;
    final instruction = _voiceGuidance.announceCurrentManeuver(
      position,
      english: english,
      speedMetersPerSecond: speedMetersPerSecond,
    );
    if (instruction != null) {
      unawaited(_speak(instruction, english: english));
    }
  }

  void _updateAutomaticRerouting(
    MapScreenViewModel model,
    latlong2.LatLng routePosition,
    Position gpsPosition,
  ) {
    if (_voiceGuidance.finalDestinationReached) {
      if (_offRouteEpisodeActive || _reroutingDisplay != null) {
        _cancelAutomaticRerouting(resetAttempts: false);
      }
      return;
    }
    _updateGpsMotionState(gpsPosition);
    final isOffRoute = _voiceGuidance.isOffRouteForRerouting(
      routePosition,
      horizontalAccuracyMeters: gpsPosition.accuracy,
    );
    if (!model.navigationStarted || _gpsStationary || !isOffRoute) {
      if (model.navigationStarted) {
        if (!isOffRoute) _recordOnRouteProgress(routePosition);
      }
      if (_offRouteEpisodeActive || _reroutingDisplay != null) {
        if (_automaticRerouteCommitted &&
            model.navigationStarted &&
            model.automaticReroutingEnabled &&
            !_automaticReroutingSuspended) {
          return;
        }
        _cancelAutomaticRerouting(resetAttempts: false);
      }
      return;
    }
    _lastOnRoutePosition = null;
    _onRouteSinceReroute = null;
    if (_offRouteEpisodeActive) return;

    _offRouteEpisodeActive = true;
    _automaticRerouteCommitted = false;
    _offRouteDisplayTimer = Timer(_offRouteDisplayDelay, () {
      if (!_stillOffRoute(model)) return;
      _setReroutingDisplay(
        context.l10n.isEnglish
            ? 'Route left or no GPS signal'
            : 'Route verlassen oder kein GPS-Signal',
      );
      unawaited(_zoomOutAfterMissingDirections());
    });

    // Three consecutive recalculations only pause automation for this
    // navigation. While paused, keep the map status useful but do not annoy a
    // rider without a phone mount with more off-route announcements.
    if (_automaticReroutingSuspended && model.automaticReroutingEnabled) {
      _setReroutingDisplay(
        context.l10n.isEnglish ? 'Follow map' : 'Karte beachten',
      );
      return;
    }

    _offRouteAnnouncementTimer = Timer(_offRouteAnnouncementDelay, () {
      if (!_stillOffRoute(model)) return;
      final automatic =
          model.automaticReroutingEnabled && !_automaticReroutingSuspended;
      _automaticRerouteCommitted = automatic;
      final isLastAutomaticAnnouncement = automatic &&
          _consecutiveAutomaticReroutes == _maximumConsecutiveReroutes - 1;
      final message = context.l10n.isEnglish
          ? automatic
              ? isLastAutomaticAnnouncement
                  ? 'Last automatic recalculation shortly. No further '
                      'directions while off the route.'
                  : 'Route left or no GPS signal. '
                      'Recalculating automatically shortly.'
              : 'Route left or no GPS signal.'
          : automatic
              ? isLastAutomaticAnnouncement
                  ? 'Letzte automatische Neuberechnung in Kürze. Keine '
                      'weiteren Ansagen außerhalb der Route.'
                  : 'Route verlassen oder kein GPS-Signal. Automatische '
                      'Neuberechnung in Kürze.'
              : 'Route verlassen oder kein GPS-Signal.';
      _setReroutingDisplay(message);
      if (model.voiceGuidanceEnabled && model.voiceGuidanceAvailable) {
        final english = context.l10n.isEnglish;
        final spokenMessage = offRouteSpokenMessage(
          english: english,
          automaticRerouting: automatic,
          firstAnnouncement: _offRouteAnnouncementCount == 0,
          lastAutomaticAnnouncement: isLastAutomaticAnnouncement,
        );
        _offRouteAnnouncementCount++;
        unawaited(_speak(spokenMessage, english: english));
      }
    });

    if (model.automaticReroutingEnabled && !_automaticReroutingSuspended) {
      _automaticRerouteTimer = Timer(_automaticRerouteDelay, () {
        if (model.automaticReroutingEnabled &&
            (_automaticRerouteCommitted || _stillOffRoute(model))) {
          unawaited(_performAutomaticReroute(model));
        }
      });
    }
  }

  void _updateGpsMotionState(Position position) {
    final current = latlong2.LatLng(position.latitude, position.longitude);
    final anchor = _gpsMotionAnchor;
    if (anchor == null) {
      _gpsMotionAnchor = current;
      _gpsMotionAnchorAccuracy = position.accuracy;
      _gpsStationary = true;
      return;
    }

    final distance = const latlong2.Distance().as(
      latlong2.LengthUnit.Meter,
      anchor,
      current,
    );
    final accuracy = max(_gpsMotionAnchorAccuracy ?? 0, position.accuracy);
    final movementThreshold = (accuracy * 1.5).clamp(8.0, 25.0);
    if (distance >= movementThreshold && distance <= 200) {
      _gpsMotionAnchor = current;
      _gpsMotionAnchorAccuracy = position.accuracy;
      _lastGpsMovementAt = DateTime.now();
    }
    final lastMovement = _lastGpsMovementAt;
    _gpsStationary = lastMovement == null ||
        DateTime.now().difference(lastMovement) > const Duration(seconds: 8);
  }

  bool _stillOffRoute(MapScreenViewModel model) {
    final position = _latestPosition;
    return mounted &&
        model.navigationStarted &&
        position != null &&
        position.accuracy.isFinite &&
        position.accuracy <= 50 &&
        !_gpsStationary &&
        _voiceGuidance.isOffRouteForRerouting(
          latlong2.LatLng(position.latitude, position.longitude),
          horizontalAccuracyMeters: position.accuracy,
        );
  }

  Future<void> _performAutomaticReroute(MapScreenViewModel model) async {
    if (_consecutiveAutomaticReroutes >= _maximumConsecutiveReroutes) {
      _automaticReroutingSuspended = true;
      _voiceSignalTimer?.cancel();
      _setReroutingDisplay(
        context.l10n.isEnglish
            ? 'Automatic recalculation paused. Recalculate manually to resume.'
            : 'Automatische Neuberechnung pausiert. Zum Fortsetzen manuell '
                'neu berechnen.',
      );
      return;
    }
    _consecutiveAutomaticReroutes++;
    _onRouteDistanceSinceReroute = 0;
    _lastOnRoutePosition = null;
    _onRouteSinceReroute = null;
    _setReroutingDisplay(
      context.l10n.isEnglish
          ? 'Recalculating route...'
          : 'Route wird neu berechnet...',
    );
    final updated = await model.refreshRoute();
    if (!mounted) return;
    if (!updated) {
      _setReroutingDisplay(
        context.l10n.isEnglish
            ? 'Recalculation failed. Will retry later.'
            : 'Neuberechnung fehlgeschlagen. Neuer Versuch später.',
      );
    } else {
      final position = _latestPosition;
      _navigationStartGate.reset(
        position == null ||
                !position.latitude.isFinite ||
                !position.longitude.isFinite
            ? null
            : latlong2.LatLng(position.latitude, position.longitude),
      );
      _initialGuidanceAnnouncementPending = true;
      _cancelAutomaticRerouting(resetAttempts: false);
      await _restoreNavigationZoom(model);
      if (position != null) {
        _refreshVoiceGuidance(model, position);
      }
    }
    if (_consecutiveAutomaticReroutes >= _maximumConsecutiveReroutes) {
      _automaticReroutingSuspended = true;
      _voiceSignalTimer?.cancel();
      _setReroutingDisplay(
        context.l10n.isEnglish
            ? 'Automatic recalculation paused after 3 consecutive '
                'recalculations. Recalculate manually to resume.'
            : 'Automatische Neuberechnung nach 3 aufeinanderfolgenden '
                'Neuberechnungen pausiert. Zum Fortsetzen manuell neu '
                'berechnen.',
      );
    }
    _offRouteEpisodeActive = false;
    _automaticRerouteCommitted = false;
  }

  void _recordOnRouteProgress(latlong2.LatLng position) {
    final previous = _lastOnRoutePosition;
    _lastOnRoutePosition = position;
    if (_consecutiveAutomaticReroutes == 0) return;
    _onRouteSinceReroute ??= DateTime.now();
    if (previous == null) return;

    final step = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
    // Ignore implausible GPS jumps; they must not make separate reroutes look
    // independent without confirmed on-route riding.
    if (!step.isFinite || step <= 0 || step > _maximumOnRouteProgressStep) {
      return;
    }
    _onRouteDistanceSinceReroute += step;
    final continuouslyOnRoute = DateTime.now().difference(
      _onRouteSinceReroute!,
    );
    final recoveredByDistance =
        _onRouteDistanceSinceReroute >= _onRouteDistanceToResetReroutes;
    final recoveredByTime = continuouslyOnRoute >=
            _onRouteDurationToResetReroutes &&
        _onRouteDistanceSinceReroute >= _minimumOnRouteDistanceForTimedReset;
    if (!recoveredByDistance && !recoveredByTime) {
      return;
    }

    _automaticReroutingSuspended = false;
    _consecutiveAutomaticReroutes = 0;
    _onRouteDistanceSinceReroute = 0;
    _onRouteSinceReroute = null;
  }

  void _setReroutingDisplay(String text) {
    if (!mounted || _reroutingDisplay?.text == text) return;
    setState(() {
      _reroutingDisplay = VoiceGuidanceDisplay(
        text: text,
        type: 'notification',
      );
      _nextManeuver = _reroutingDisplay;
    });
  }

  void _cancelAutomaticRerouting({bool resetAttempts = true}) {
    _offRouteDisplayTimer?.cancel();
    _offRouteAnnouncementTimer?.cancel();
    _automaticRerouteTimer?.cancel();
    _offRouteDisplayTimer = null;
    _offRouteAnnouncementTimer = null;
    _automaticRerouteTimer = null;
    _offRouteEpisodeActive = false;
    _automaticRerouteCommitted = false;
    if (resetAttempts) {
      _automaticReroutingSuspended = false;
      _consecutiveAutomaticReroutes = 0;
      _offRouteAnnouncementCount = 0;
      _onRouteDistanceSinceReroute = 0;
      _lastOnRoutePosition = null;
      _onRouteSinceReroute = null;
    }
    _reroutingDisplay = null;
  }

  Future<void> _zoomOutAfterMissingDirections() async {
    final controller = _mapController;
    if (!mounted || controller == null) return;
    try {
      // Always use the same overview. Subtracting from the current zoom here
      // would zoom farther out after every repeated rerouting attempt.
      _offRouteCameraZoomedOut = true;
      await _scheduleCameraUpdate(CameraUpdate.zoomTo(_offRouteZoom));
    } catch (error, stackTrace) {
      log.d(
        'Zooming out after missing directions skipped while map is updating',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _restoreNavigationZoom(MapScreenViewModel model) async {
    if (!_offRouteCameraZoomedOut ||
        !model.navigationStarted ||
        model.locationState != LocationState.FOLLOW_AND_ROTATE_MAP) {
      return;
    }
    await _scheduleCameraUpdate(CameraUpdate.zoomTo(_navigationStartZoom));
    _offRouteCameraZoomedOut = false;
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
    final updated = await _reloadMapData(model);
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

  Future<bool> _reloadMapData(MapScreenViewModel model) async {
    final radnetzReload = model.reloadRadnetz();
    await _reloadDrinkingWaterPois();
    await _reloadPublicToilets();
    await _reloadRepairStations();
    return radnetzReload;
  }

  Future<void> _startNavigation(MapScreenViewModel model) async {
    final started = await model.startNavigation();
    if (!mounted || !started) return;
    _offRouteCameraZoomedOut = false;
    final initialPosition = _latestPosition;
    _navigationStartGate.reset(
      initialPosition == null ||
              !initialPosition.latitude.isFinite ||
              !initialPosition.longitude.isFinite
          ? null
          : latlong2.LatLng(
              initialPosition.latitude,
              initialPosition.longitude,
            ),
    );
    _initialGuidanceAnnouncementPending = true;
    if (initialPosition != null &&
        initialPosition.latitude.isFinite &&
        initialPosition.longitude.isFinite &&
        initialPosition.accuracy.isFinite &&
        initialPosition.accuracy <= 50) {
      final headingAvailable = _hasReliableMovementHeading(initialPosition);
      await _scheduleCameraUpdate(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              initialPosition.latitude,
              initialPosition.longitude,
            ),
            zoom: _navigationStartZoom,
            bearing: headingAvailable ? initialPosition.heading : 0,
          ),
        ),
      );
    } else {
      await _scheduleCameraUpdate(
        CameraUpdate.zoomTo(_navigationStartZoom),
      );
    }
    if (!mounted) return;
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

    setState(() => _pendingRouteMapSelection = selection);
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
      final place = Place(null, position);
      final addToDisplayedRoute = !model.navigationStarted &&
          model.route.state == MapRouteState.SHOWN &&
          model.destination != null;
      if (addToDisplayedRoute) {
        model.setRoutePlan(
          start: model.routeStart,
          stops: [...model.waypoints, place],
          destination: model.destination!,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.isEnglish
                  ? 'Intermediate stop added.'
                  : 'Zwischenziel hinzugefügt.',
            ),
          ),
        );
      } else {
        model.setDestination(place);
      }
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
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  context.l10n.isEnglish ? 'Skip' : 'Überspringen',
                ),
              ),
              FilledButton(
                onPressed: canSave
                    ? () => Navigator.pop(dialogContext, enteredName)
                    : null,
                child: Text(
                  context.l10n.isEnglish ? 'Save' : 'Speichern',
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
    setState(() => _pendingRouteMapSelection = null);
    await _openRoutePlanner(
      model,
      initialPlan: pendingSelection.withSelectedPlace(place),
    );
  }

  Future<void> _handleMapLongPress(
    MapScreenViewModel model,
    Point<double> screenPoint,
    latlong2.LatLng position,
  ) async {
    final endpointMove = _pendingRouteEndpointMove;
    if (endpointMove != null) {
      setState(() => _pendingRouteEndpointMove = null);
      final destination = model.destination;
      if (destination == null) return;
      final place = Place(null, position);
      model.setRoutePlan(
        start:
            endpointMove == _RouteEndpointMove.start ? place : model.routeStart,
        stops: List<Place>.of(model.waypoints),
        destination: endpointMove == _RouteEndpointMove.destination
            ? place
            : destination,
      );
      return;
    }

    // Explicit map-selection flows already tell the user which point to pick.
    if (_nameNextMapSelection || _pendingRouteMapSelection != null) {
      await _handleMapPlaceSelection(model, position);
      return;
    }

    final details = await _streetDetailsAt(screenPoint);
    final poiDetails = await _poiDetailsAt(screenPoint);
    final endpoint = await _routeEndpointAt(model, screenPoint);
    if (!mounted) return;
    final action = await _showLongPressActions(
      model,
      screenPoint,
      details,
      poiDetails,
      endpoint,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case MapLongPressAction.showDetails:
        if (poiDetails != null) {
          _showPoiDetails(model, poiDetails, position);
        } else if (details != null) {
          model.onTap(details);
        }
        return;
      case MapLongPressAction.startRoute:
        final routeReady = await model.setDestinationAndCalculateRoute(
          Place(null, position),
        );
        if (!mounted || !routeReady) return;
        await _startNavigation(model);
        return;
      case MapLongPressAction.addWaypoint:
        model.setRoutePlan(
          start: model.routeStart,
          stops: [...model.waypoints, Place(null, position)],
          destination: model.destination!,
        );
        return;
      case MapLongPressAction.moveStart:
        _beginEndpointMove(_RouteEndpointMove.start);
        return;
      case MapLongPressAction.moveDestination:
        _beginEndpointMove(_RouteEndpointMove.destination);
        return;
    }
  }

  void _beginEndpointMove(_RouteEndpointMove endpoint) {
    setState(() => _pendingRouteEndpointMove = endpoint);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          endpoint == _RouteEndpointMove.start
              ? (context.l10n.isEnglish
                  ? 'Touch and hold the new starting point.'
                  : 'Neuen Startpunkt lange antippen.')
              : (context.l10n.isEnglish
                  ? 'Touch and hold the new destination.'
                  : 'Neues Ziel lange antippen.'),
        ),
        action: SnackBarAction(
          label: context.l10n.tr('Abbrechen'),
          onPressed: () {
            if (mounted) setState(() => _pendingRouteEndpointMove = null);
          },
        ),
      ),
    );
  }

  Future<MapLongPressAction?> _showLongPressActions(
    MapScreenViewModel model,
    Point<double> screenPoint,
    StreetDetails? details,
    PoiDetails? poiDetails,
    _RouteEndpointMove? endpoint,
  ) async {
    if (!mounted) return null;
    final mapBox = _mapLibreViewKey.currentContext?.findRenderObject();
    final overlayState = Overlay.of(context, rootOverlay: true);
    final overlay = overlayState.context.findRenderObject();
    if (mapBox is! RenderBox || overlay is! RenderBox) return null;
    // Android's native MapLibre callback reports physical pixels, while
    // Flutter positions overlays in logical pixels. iOS reports UIKit points
    // already, so only Android needs the density conversion.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final logicalPoint =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? Offset(screenPoint.x / pixelRatio, screenPoint.y / pixelRatio)
            : Offset(screenPoint.x, screenPoint.y);
    final boundedPoint = Offset(
      logicalPoint.dx.clamp(0.0, mapBox.size.width),
      logicalPoint.dy.clamp(0.0, mapBox.size.height),
    );
    final globalPoint = mapBox.localToGlobal(boundedPoint);
    final overlayPoint = overlay.globalToLocal(globalPoint);
    return showMapLongPressActionOverlay(
      context,
      anchor: overlayPoint,
      overlaySize: overlay.size,
      streetDetails: details,
      hasPoiDetails: poiDetails != null,
      canAddWaypoint: !model.navigationStarted &&
          model.route.state != MapRouteState.NO_ROUTE &&
          model.destination != null,
      canMoveStart: endpoint == _RouteEndpointMove.start,
      canMoveDestination: endpoint == _RouteEndpointMove.destination,
    );
  }

  Future<_RouteEndpointMove?> _routeEndpointAt(
    MapScreenViewModel model,
    Point<double> pressedPoint,
  ) async {
    final controller = _mapController;
    final route = model.route.route;
    if (controller == null ||
        model.navigationStarted ||
        model.destination == null) {
      return null;
    }

    try {
      Future<bool> isNear(latlong2.LatLng location) async {
        final point = await controller.toScreenLocation(
          LatLng(location.latitude, location.longitude),
        );
        final dx = point.x - pressedPoint.x;
        final dy = point.y - pressedPoint.y;
        return sqrt(dx * dx + dy * dy) <= 82;
      }

      if (await isNear(model.destination!.latLng)) {
        return _RouteEndpointMove.destination;
      }
      final start = model.routeStart?.latLng ??
          (route != null && route.points.isNotEmpty
              ? route.points.first
              : _displayedRouteStartPoint);
      if (start == null) return null;
      return await isNear(start) ? _RouteEndpointMove.start : null;
    } catch (error, stackTrace) {
      log.d(
        'Checking a long press against route endpoints failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<StreetDetails?> _streetDetailsAt(Point<double> screenPoint) async {
    final controller = _mapController;
    if (controller == null || !_networkGeoJsonReady) return null;
    try {
      final features = await controller.queryRenderedFeatures(
        screenPoint,
        const [_kNetworkLayerHitRadlId, _kNetworkLayerHitGesamtId],
        null,
      );
      for (final feature in features) {
        if (feature is! Map) continue;
        final id = feature['id'];
        final details = mapViewModel.streetDetailsForFeatureId(id) ??
            _streetDetailsForNetworkFeatureId(id);
        if (details != null) return details;
      }
    } catch (error, stackTrace) {
      log.d(
        'Querying a long-pressed network feature failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  Future<PoiDetails?> _poiDetailsAt(Point<double> screenPoint) async {
    final controller = _mapController;
    if (controller == null ||
        (!_drinkingWaterGeoJsonReady &&
            !_publicToiletsGeoJsonReady &&
            !_repairStationsGeoJsonReady)) {
      return null;
    }
    try {
      final layers = <String>[
        if (_drinkingWaterGeoJsonReady) _kDrinkingWaterLayerId,
        if (_publicToiletsGeoJsonReady) _kPublicToiletsLayerId,
        if (_repairStationsGeoJsonReady) _kRepairStationsLayerId,
      ];
      final features = await controller.queryRenderedFeatures(
        screenPoint,
        layers,
        null,
      );
      for (final feature in features) {
        if (feature is Map && feature['properties'] is Map) {
          return PoiDetails.fromGeoJsonFeature(feature);
        }
      }
    } catch (error, stackTrace) {
      log.d(
        'Querying a long-pressed POI failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  void _showPoiDetails(
    MapScreenViewModel model,
    PoiDetails details,
    latlong2.LatLng position,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) => PoiDetailsSheet(
        details: details,
        onRouteHere: () {
          Navigator.pop(sheetContext);
          unawaited(
            _startRouteToPoi(model, details, details.location ?? position),
          );
        },
      ),
    );
  }

  Future<void> _startRouteToPoi(
    MapScreenViewModel model,
    PoiDetails details,
    latlong2.LatLng position,
  ) async {
    final routeReady = await model.setDestinationAndCalculateRoute(
      Place(
        details.title.isEmpty
            ? switch (details.type) {
                PoiType.drinkingWater => context.l10n.isEnglish
                    ? 'Drinking water fountain'
                    : 'Trinkwasserbrunnen',
                PoiType.publicToilet => context.l10n.isEnglish
                    ? 'Public toilet'
                    : 'Öffentliche Toilette',
                PoiType.bicycleRepairStation => context.l10n.isEnglish
                    ? 'Bicycle repair station'
                    : 'Fahrrad-Servicestation',
              }
            : details.title,
        position,
      ),
    );
    if (!mounted || !routeReady) return;
    await _startNavigation(model);
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
    if (_automaticReroutingSuspended ||
        !model.navigationStarted ||
        !model.voiceGuidanceEnabled ||
        !model.voiceGuidanceAvailable) {
      return;
    }
    _voiceSignalTimer = Timer(_voiceSignalWarningDelay, () {
      if (!mounted ||
          !model.navigationStarted ||
          !model.voiceGuidanceEnabled ||
          !model.voiceGuidanceAvailable) {
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
    // A manual recalculation resumes a temporary safety pause. It must not
    // override a setting that the user deliberately switched off.
    if (_automaticReroutingSuspended && model.automaticReroutingEnabled) {
      _cancelAutomaticRerouting();
    }
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
    await model.onPressLocationBtn(
      permissionCheck: permissionCheck,
      followLocation: false,
    );
    if (!mounted) return;
    await _applyNativeLocationTracking(model);
    if (model.locationState != LocationState.NOT_AVAILABLE) {
      try {
        final cachedPosition = await Geolocator.getLastKnownPosition();
        if (mounted &&
            cachedPosition != null &&
            isFreshCachedPosition(cachedPosition.timestamp, DateTime.now()) &&
            isUsableMapPosition(
              latitude: cachedPosition.latitude,
              longitude: cachedPosition.longitude,
              accuracy: cachedPosition.accuracy,
            )) {
          setState(() => _latestPosition = cachedPosition);
          unawaited(_updateNearbyPoiAvailability(cachedPosition));
          _pendingPosition = cachedPosition;
          context.read<AppThemeController>().updateLocation(
                cachedPosition.latitude,
                cachedPosition.longitude,
              );
          unawaited(_drainLocationUpdates(model));
        }
      } catch (error, stackTrace) {
        log.d(
          'Reading cached startup location failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (!mounted) return;
    await _updateLocationStream(model);
  }

  Future<void> _updateNearbyPoiAvailability(Position position) async {
    final generation = ++_nearbyCoverageCheckGeneration;
    try {
      final withinCoverage = await _nearbyPoiCoverage.contains(
        latlong2.LatLng(position.latitude, position.longitude),
      );
      if (!mounted || generation != _nearbyCoverageCheckGeneration) return;
      if (_showNearbyPois != withinCoverage) {
        setState(() => _showNearbyPois = withinCoverage);
      }
    } catch (error, stackTrace) {
      log.w(
        'Checking nearby-POI coverage failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted || generation != _nearbyCoverageCheckGeneration) return;
      if (_showNearbyPois) setState(() => _showNearbyPois = false);
    }
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

  Future<void> _persistCameraPosition() async {
    if (!_cameraReady || !mounted) return;
    try {
      final position = await _mapController?.queryCameraPosition();
      if (position == null ||
          !_isValidCoordinate(
            position.target.latitude,
            position.target.longitude,
          ) ||
          !position.zoom.isFinite ||
          !position.bearing.isFinite) {
        return;
      }
      _savedInitialCamera = position;
      await settingsStore.saveMapCamera(
        latitude: position.target.latitude,
        longitude: position.target.longitude,
        zoom: _safeZoom(position.zoom),
        bearing: position.bearing,
      );
    } catch (error, stackTrace) {
      log.w(
        'Saving map camera failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _scheduleCameraPersistence() {
    _cameraSaveTimer?.cancel();
    _cameraSaveTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_persistCameraPosition());
    });
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
    // The navigation header always contains a guidance row. If there is no
    // maneuver, it shows "Karte beachten" instead, with the same height.
    final desiredOffset = model.destination == null
        ? 160.0
        : model.navigationStarted
            ? 144.0
            : 128.0;
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
    _overlaySyncRetryTimer?.cancel();
    _overlaySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlaySyncScheduled = false;
      if (!mounted) return;
      unawaited(_syncOverlays(model));
    });
  }

  void _startRoutingCoverageLoad() {
    if (_routingCoverageLoadStarted) return;
    _routingCoverageLoadStarted = true;
    _nearbyPoiCoverage.featureCollection.then((geoJson) {
      if (!mounted) return;
      _routingCoverageGeoJson = geoJson;
      _scheduleRoutingCoverageSync();
    }).catchError((Object error, StackTrace stackTrace) {
      log.w(
        'Loading Oberbayern routing boundary failed',
        error: error,
        stackTrace: stackTrace,
      );
    });
  }

  void _scheduleRoutingCoverageSync() {
    if (!mounted ||
        !_styleLoaded ||
        _routingCoverageGeoJsonReady ||
        _routingCoverageSyncRunning ||
        _routingCoverageGeoJson == null ||
        _mapController == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncRoutingCoverage());
    });
  }

  Future<void> _syncRoutingCoverage() async {
    final controller = _mapController;
    final geoJson = _routingCoverageGeoJson;
    if (!_styleLoaded ||
        _routingCoverageGeoJsonReady ||
        _routingCoverageSyncRunning ||
        controller == null ||
        geoJson == null) {
      return;
    }
    _routingCoverageSyncRunning = true;
    try {
      await controller.addGeoJsonSource(_kRoutingCoverageSourceId, geoJson);
      await controller.addLineLayer(
        _kRoutingCoverageSourceId,
        _kRoutingCoverageLayerId,
        LineLayerProperties(
          lineColor: Theme.of(context).brightness == Brightness.dark
              ? '#ffb45c'
              : '#d96b00',
          lineWidth: const [
            Expressions.interpolate,
            ['linear'],
            [Expressions.zoom],
            3,
            1.5,
            9,
            3.0,
          ],
          lineOpacity: 0.9,
          lineDasharray: const [2.0, 1.5],
          lineCap: 'round',
          lineJoin: 'round',
        ),
        belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
        maxzoom: _kRoutingCoverageMaxZoom,
        enableInteraction: false,
      );
      if (!mounted || !identical(controller, _mapController)) return;
      _routingCoverageGeoJsonReady = true;
    } catch (error, stackTrace) {
      log.w(
        'Adding Oberbayern routing boundary failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _routingCoverageSyncRunning = false;
    }
  }

  void _retryOverlaySync(MapScreenViewModel model) {
    if (!mounted || !_styleLoaded || _mapController == null) return;
    _overlaySyncRetryTimer?.cancel();
    final delay = Duration(
      milliseconds: min(2000, 100 * (1 << min(_overlaySyncRetryCount, 4))),
    );
    _overlaySyncRetryCount++;
    _overlaySyncRetryTimer = Timer(delay, () {
      if (mounted) _scheduleOverlaySync(model);
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
        if (!mounted || !identical(controller, _mapController)) return;
        _lastSyncedNetworkFingerprint = netFp;
      }
      if (routeChanged) {
        await _syncRouteAndDestinationLayers(model, controller);
        if (!mounted || !identical(controller, _mapController)) return;
        _lastRouteFingerprint = routeFp;
      }
      _overlaySyncRetryCount = 0;
    } catch (error, stackTrace) {
      // Native style setup can briefly reject source/layer operations directly
      // after onStyleLoaded (especially on slower Android devices). Keep the
      // model data and retry instead of requiring an app restart.
      log.w(
        'Map overlay sync failed; retrying',
        error: error,
        stackTrace: stackTrace,
      );
      _retryOverlaySync(model);
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
    for (final symbol in _routePlanSymbols) {
      await controller.removeSymbol(symbol);
    }
    _routePlanSymbols.clear();

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
      await controller.setGeoJsonSource(
        _kRouteOverlapSourceId,
        buildRouteOverlapGeoJson(route.points),
      );
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
      await controller.setGeoJsonSource(
        _kRouteOverlapSourceId,
        buildRouteOverlapGeoJson(const []),
      );
    }

    if (model.destination != null) {
      const imageName = 'route-destination-flag-v3';
      if (!_routePointImages.contains(imageName)) {
        await controller.addImage(
          imageName,
          await _createRouteDestinationFlagImage(),
        );
        _routePointImages.add(imageName);
      }
      _routePlanSymbols.add(
        await controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(
              model.destination!.latLng.latitude,
              model.destination!.latLng.longitude,
            ),
            iconImage: imageName,
            iconSize: 1.45,
            iconAnchor: 'bottom',
          ),
        ),
      );
    }

    final route = model.route.route;
    if (model.destination == null ||
        model.route.state == MapRouteState.NO_ROUTE) {
      _displayedRouteStartPoint = null;
    } else if (model.route.state == MapRouteState.SHOWN &&
        route != null &&
        route.points.isNotEmpty) {
      _displayedRouteStartPoint = route.points.first;
    }
    final startPoint = model.routeStart?.latLng ?? _displayedRouteStartPoint;
    if (startPoint != null) {
      const imageName = 'route-start-v2';
      if (!_routePointImages.contains(imageName)) {
        await controller.addImage(imageName, await _createRouteStartImage());
        _routePointImages.add(imageName);
      }
      _routePlanSymbols.add(
        await controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(
              startPoint.latitude,
              startPoint.longitude,
            ),
            iconImage: imageName,
            iconSize: 1.45,
            iconAnchor: 'center',
          ),
        ),
      );
    }

    for (var index = 0; index < model.waypoints.length; index++) {
      final waypoint = model.waypoints[index];
      final geometry = LatLng(
        waypoint.latLng.latitude,
        waypoint.latLng.longitude,
      );
      final number = index + 1;
      final imageName = 'route-waypoint-$number';
      if (!_routeWaypointImages.contains(number)) {
        await controller.addImage(
          imageName,
          await _createRouteWaypointImage(number),
        );
        _routeWaypointImages.add(number);
      }
      _routePlanSymbols.add(
        await controller.addSymbol(
          SymbolOptions(
            geometry: geometry,
            iconImage: imageName,
            iconSize: 1.4,
            iconAnchor: 'center',
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

  Future<Uint8List> _createRouteWaypointImage(int number) async {
    const size = 48.0;
    const center = ui.Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawCircle(
      center,
      22,
      ui.Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      19,
      ui.Paint()..color = AppColors.munichWaysOrange,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> _createDrinkingWaterImage() async {
    const size = 72.0;
    const center = ui.Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawCircle(center, 34, ui.Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      30,
      ui.Paint()..color = AppColors.mapRouteColor,
    );
    final drop = ui.Path()
      ..moveTo(36, 12)
      ..cubicTo(32, 21, 22, 32, 22, 42)
      ..cubicTo(22, 51, 28, 58, 36, 58)
      ..cubicTo(44, 58, 50, 51, 50, 42)
      ..cubicTo(50, 32, 40, 21, 36, 12)
      ..close();
    canvas.drawPath(drop, ui.Paint()..color = Colors.white);
    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> _createPoiIconImage(IconData icon) async {
    const size = 72.0;
    const center = ui.Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawCircle(center, 34, ui.Paint()..color = Colors.white);
    canvas.drawCircle(center, 30, ui.Paint()..color = AppColors.mapRouteColor);
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 39,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> _createRouteDestinationFlagImage() async {
    const width = 80.0;
    const height = 92.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final whiteOutline = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;
    final redStroke = ui.Paint()
      ..color = AppColors.mapRed
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = ui.StrokeCap.round;
    const poleTop = ui.Offset(16, 8);
    const poleBottom = ui.Offset(16, 86);
    canvas.drawLine(poleTop, poleBottom, whiteOutline);
    canvas.drawLine(poleTop, poleBottom, redStroke);

    final flag = ui.Path()
      ..moveTo(16, 11)
      ..lineTo(70, 16)
      ..lineTo(56, 34)
      ..lineTo(70, 52)
      ..lineTo(16, 46)
      ..close();
    canvas.drawPath(flag, whiteOutline);
    canvas.save();
    canvas.clipPath(flag);
    const cell = 14.0;
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 5; column++) {
        canvas.drawRect(
          ui.Rect.fromLTWH(
            14 + column * cell,
            8 + row * cell,
            cell,
            cell,
          ),
          ui.Paint()
            ..color = (row + column).isEven ? Colors.white : AppColors.mapRed,
        );
      }
    }
    canvas.restore();
    canvas.drawPath(flag, redStroke);

    final image = await recorder.endRecording().toImage(
          width.toInt(),
          height.toInt(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> _createRouteStartImage() async {
    const size = 64.0;
    const center = ui.Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawCircle(center, 31, ui.Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      27,
      ui.Paint()..color = AppColors.munichWaysBlue,
    );
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'S',
        style: TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<Uint8List> _createRouteOverlapArrowPairImage() async {
    const width = 96.0;
    const height = 38.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, width - 4, height - 4),
        const Radius.circular(10),
      ),
      ui.Paint()..color = const Color(0xE6222630),
    );
    final white = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.fill;

    final forward = ui.Path()
      ..moveTo(9, 15)
      ..lineTo(31, 15)
      ..lineTo(31, 9)
      ..lineTo(43, 19)
      ..lineTo(31, 29)
      ..lineTo(31, 23)
      ..lineTo(9, 23)
      ..close();
    final backward = ui.Path()
      ..moveTo(87, 15)
      ..lineTo(65, 15)
      ..lineTo(65, 9)
      ..lineTo(53, 19)
      ..lineTo(65, 29)
      ..lineTo(65, 23)
      ..lineTo(87, 23)
      ..close();
    for (final path in [forward, backward]) {
      canvas.drawPath(path, white);
    }

    final image = await recorder.endRecording().toImage(
          width.toInt(),
          height.toInt(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> _removeRouteGeoJsonLayers(
      MapLibreMapController controller) async {
    if (!_routeGeoJsonReady) return;
    try {
      await controller.removeLayer(_kRouteLayerId);
      await controller.removeLayer(_kRouteConnectorLayerId);
      await controller.removeSource(_kRouteSourceId);
      await controller.removeSource(_kRouteConnectorSourceId);
      await controller.removeSource(_kRouteOverlapSourceId);
    } catch (_) {
      // Style may have already dropped layers.
    }
  }

  Future<void> _ensureRouteGeoJsonLayer(
      MapLibreMapController controller) async {
    if (_routeGeoJsonReady) return;
    final routeColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.mapRouteColorDark
        : AppColors.mapRouteColor;
    await controller.addGeoJsonSource(_kRouteSourceId, {
      'type': 'FeatureCollection',
      'features': <dynamic>[],
    });
    await controller.addGeoJsonSource(_kRouteConnectorSourceId, {
      'type': 'FeatureCollection',
      'features': <dynamic>[],
    });
    await controller.addGeoJsonSource(_kRouteOverlapSourceId, {
      'type': 'FeatureCollection',
      'features': <dynamic>[],
    });
    await controller.addLineLayer(
      _kRouteSourceId,
      _kRouteLayerId,
      LineLayerProperties(
        lineColor: _hexColor(routeColor),
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
        lineColor: _hexColor(routeColor),
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
      await controller.removeLayer(_kRouteOverlapLayerId);
      await controller.removeLayer(_kNetworkLayerDashedRadlId);
      await controller.removeLayer(_kNetworkLayerVisibleRadlId);
      await controller.removeLayer(_kNetworkLayerCasingRadlId);
      await controller.removeLayer(_kNetworkLayerDashedGesamtId);
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final networkWidth = dark
        ? MapOverlayLineStyle.darkNetworkLineWidthByZoom
        : MapOverlayLineStyle.radlLineWidthByZoom;
    final networkCasingWidth = dark
        ? MapOverlayLineStyle.darkNetworkCasingLineWidthByZoom
        : MapOverlayLineStyle.networkCasingLineWidthByZoom;
    final networkCasingColor = dark ? '#17232b' : '#ffffff';
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
      LineLayerProperties(
        lineColor: networkCasingColor,
        lineWidth: networkCasingWidth,
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
    // Line style represents the Happy-Bike level, independent of network:
    // green/yellow are solid; red/black are dashed.
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerVisibleGesamtId,
      LineLayerProperties(
        lineColor: [Expressions.get, 'lineColor'],
        lineWidth: networkWidth,
        lineOpacity: MapOverlayLineStyle.gesamtNetzLineOpacityByZoom,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        'all',
        [
          Expressions.equal,
          [Expressions.get, 'gesamtnetz'],
          true
        ],
        [
          Expressions.equal,
          [Expressions.get, 'lineDashed'],
          false
        ],
      ],
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      minzoom: _kGesamtnetzMinZoom,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerDashedGesamtId,
      LineLayerProperties(
        lineColor: [Expressions.get, 'lineColor'],
        lineWidth: networkWidth,
        lineOpacity: MapOverlayLineStyle.gesamtNetzLineOpacityByZoom,
        lineCap: 'round',
        lineJoin: 'round',
        lineDasharray: [1.25, 2],
      ),
      filter: [
        'all',
        [
          Expressions.equal,
          [Expressions.get, 'gesamtnetz'],
          true
        ],
        [
          Expressions.equal,
          [Expressions.get, 'lineDashed'],
          true
        ],
      ],
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      minzoom: _kGesamtnetzMinZoom,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerCasingRadlId,
      LineLayerProperties(
        lineColor: networkCasingColor,
        lineWidth: networkCasingWidth,
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
      _kNetworkLayerDashedRadlId,
      LineLayerProperties(
        lineColor: [Expressions.get, 'lineColor'],
        lineWidth: networkWidth,
        lineOpacity: MapOverlayLineStyle.radlLineOpacityByZoom,
        lineCap: 'round',
        lineJoin: 'round',
        lineDasharray: [1.25, 2],
      ),
      filter: [
        'all',
        [
          Expressions.equal,
          [Expressions.get, 'gesamtnetz'],
          false
        ],
        [
          Expressions.equal,
          [Expressions.get, 'lineDashed'],
          true
        ],
      ],
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      minzoom: _kRadlVorrangMinZoom,
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _kNetworkSourceId,
      _kNetworkLayerVisibleRadlId,
      LineLayerProperties(
        lineColor: [Expressions.get, 'lineColor'],
        lineWidth: networkWidth,
        lineOpacity: MapOverlayLineStyle.radlLineOpacityByZoom,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        'all',
        [
          Expressions.equal,
          [Expressions.get, 'gesamtnetz'],
          false
        ],
        [
          Expressions.equal,
          [Expressions.get, 'lineDashed'],
          false
        ],
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
    if (!_routePointImages.contains(_kRouteOverlapImageId)) {
      await controller.addImage(
        _kRouteOverlapImageId,
        await _createRouteOverlapArrowPairImage(),
      );
      _routePointImages.add(_kRouteOverlapImageId);
    }
    await controller.addSymbolLayer(
      _kRouteOverlapSourceId,
      _kRouteOverlapLayerId,
      const SymbolLayerProperties(
        symbolPlacement: 'line',
        symbolSpacing: 180,
        iconImage: _kRouteOverlapImageId,
        iconSize: 1.0,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconRotationAlignment: 'map',
        iconPitchAlignment: 'map',
      ),
      belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
      minzoom: 12,
      enableInteraction: false,
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
      (farbe) => _hexColor(AppColors.getPolylineColor(
        farbe,
        dark: Theme.of(context).brightness == Brightness.dark,
      )),
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

  void _startDrinkingWaterLoad() {
    if (_drinkingWaterLoadStarted) return;
    _drinkingWaterLoadStarted = true;
    _drinkingWaterSubscription =
        _poiGeoJsonRepository.drinkingWaterUpdates().listen(
      (geoJson) {
        _drinkingWaterGeoJson = geoJson;
        if (!_firstDrinkingWaterData.isCompleted) {
          _firstDrinkingWaterData.complete(geoJson);
        }
        _scheduleDrinkingWaterSync();
      },
      onError: (Object error, StackTrace stackTrace) {
        log.w(
          'Drinking-water POI update failed',
          error: error,
          stackTrace: stackTrace,
        );
      },
      onDone: () {
        _drinkingWaterSubscription = null;
        if (_drinkingWaterGeoJson == null) {
          _drinkingWaterLoadStarted = false;
        }
      },
    );
  }

  Future<void> _reloadDrinkingWaterPois() async {
    await _drinkingWaterSubscription?.cancel();
    _drinkingWaterSubscription = null;
    _drinkingWaterLoadStarted = false;
    _firstDrinkingWaterData = Completer<Map<String, dynamic>>();
    try {
      await _poiGeoJsonRepository.removeCache(
        PoiGeoJsonRepository.drinkingWaterUrl,
      );
    } catch (error, stackTrace) {
      log.w(
        'Clearing drinking-water POI cache failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (mounted) _startDrinkingWaterLoad();
  }

  void _startPublicToiletsLoad() {
    if (_publicToiletsLoadStarted) return;
    _publicToiletsLoadStarted = true;
    _publicToiletsSubscription =
        _poiGeoJsonRepository.publicToiletsUpdates().listen(
              (geoJson) {
                _publicToiletsGeoJson = geoJson;
                if (!_firstPublicToiletsData.isCompleted) {
                  _firstPublicToiletsData.complete(geoJson);
                }
                _schedulePublicToiletsSync();
              },
              onError: (Object error, StackTrace stackTrace) => log.w(
                'Public-toilet POI update failed',
                error: error,
                stackTrace: stackTrace,
              ),
              onDone: () {
                _publicToiletsSubscription = null;
                if (_publicToiletsGeoJson == null)
                  _publicToiletsLoadStarted = false;
              },
            );
  }

  void _startRepairStationsLoad() {
    if (_repairStationsLoadStarted) return;
    _repairStationsLoadStarted = true;
    _repairStationsSubscription =
        _poiGeoJsonRepository.bicycleRepairStationsUpdates().listen(
              (geoJson) {
                _repairStationsGeoJson = geoJson;
                if (!_firstRepairStationsData.isCompleted) {
                  _firstRepairStationsData.complete(geoJson);
                }
                _scheduleRepairStationsSync();
              },
              onError: (Object error, StackTrace stackTrace) => log.w(
                'Bicycle-repair-station POI update failed',
                error: error,
                stackTrace: stackTrace,
              ),
              onDone: () {
                _repairStationsSubscription = null;
                if (_repairStationsGeoJson == null)
                  _repairStationsLoadStarted = false;
              },
            );
  }

  Future<void> _reloadPublicToilets() async {
    await _publicToiletsSubscription?.cancel();
    _publicToiletsSubscription = null;
    _publicToiletsLoadStarted = false;
    _firstPublicToiletsData = Completer<Map<String, dynamic>>();
    try {
      await _poiGeoJsonRepository.removeCache(
        PoiGeoJsonRepository.publicToiletsUrl,
      );
    } catch (error, stackTrace) {
      log.w('Clearing public-toilet POI cache failed',
          error: error, stackTrace: stackTrace);
    }
    if (mounted) _startPublicToiletsLoad();
  }

  Future<void> _reloadRepairStations() async {
    await _repairStationsSubscription?.cancel();
    _repairStationsSubscription = null;
    _repairStationsLoadStarted = false;
    _firstRepairStationsData = Completer<Map<String, dynamic>>();
    try {
      await _poiGeoJsonRepository.removeCache(
        PoiGeoJsonRepository.bicycleRepairStationsUrl,
      );
    } catch (error, stackTrace) {
      log.w('Clearing bicycle-repair-station POI cache failed',
          error: error, stackTrace: stackTrace);
    }
    if (mounted) _startRepairStationsLoad();
  }

  Future<void> _navigateToNearbyPoi(
    MapScreenViewModel model,
    NearbyPoiType type,
  ) async {
    switch (type) {
      case NearbyPoiType.drinkingWater:
        _startDrinkingWaterLoad();
        break;
      case NearbyPoiType.publicToilet:
        _startPublicToiletsLoad();
        break;
      case NearbyPoiType.bicycleRepairStation:
        _startRepairStationsLoad();
        break;
    }
    Map<String, dynamic> geoJson;
    try {
      geoJson = switch (type) {
        NearbyPoiType.drinkingWater => _drinkingWaterGeoJson ??
            await _firstDrinkingWaterData.future
                .timeout(const Duration(seconds: 12)),
        NearbyPoiType.publicToilet => _publicToiletsGeoJson ??
            await _firstPublicToiletsData.future
                .timeout(const Duration(seconds: 12)),
        NearbyPoiType.bicycleRepairStation => _repairStationsGeoJson ??
            await _firstRepairStationsData.future
                .timeout(const Duration(seconds: 12)),
      };
    } catch (error, stackTrace) {
      log.w(
        'Waiting for nearby POIs failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isEnglish
                ? 'Nearby places could not be loaded.'
                : 'Orte in der Nähe konnten nicht geladen werden.',
          ),
        ),
      );
      return;
    }

    final position = _latestPosition ?? await model.resolveRouteStartPosition();
    if (!mounted) return;
    if (position == null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isEnglish
                ? 'Your location could not be determined.'
                : 'Dein Standort konnte nicht ermittelt werden.',
          ),
        ),
      );
      return;
    }
    _latestPosition = position;
    final origin = latlong2.LatLng(position.latitude, position.longitude);
    final destination = switch (type) {
      NearbyPoiType.drinkingWater => nearestPoiPlace(
          geoJson,
          origin,
          fallbackName: context.l10n.isEnglish
              ? 'Drinking water fountain'
              : 'Trinkwasserbrunnen',
        ),
      NearbyPoiType.publicToilet => nearestPoiPlace(
          geoJson,
          origin,
          fallbackName:
              context.l10n.isEnglish ? 'Public toilet' : 'Öffentliche Toilette',
        ),
      NearbyPoiType.bicycleRepairStation => nearestPoiPlace(
          geoJson,
          origin,
          fallbackName: context.l10n.isEnglish
              ? 'Bicycle repair station'
              : 'Fahrrad-Servicestation',
        ),
    };
    if (destination == null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isEnglish
                ? 'No matching place was found.'
                : 'Es wurde kein passender Ort gefunden.',
          ),
        ),
      );
      return;
    }
    final routeReady = await model.setDestinationAndCalculateRoute(destination);
    if (!mounted || !routeReady) return;
    await _startNavigation(model);
  }

  void _scheduleDrinkingWaterSync() {
    if (!_styleLoaded || _drinkingWaterGeoJson == null) return;
    if (_drinkingWaterSyncRunning) {
      _drinkingWaterSyncQueued = true;
      return;
    }
    _drinkingWaterSyncRunning = true;
    unawaited(_runDrinkingWaterSync());
  }

  Future<void> _runDrinkingWaterSync() async {
    try {
      do {
        _drinkingWaterSyncQueued = false;
        final controller = _mapController;
        final geoJson = _drinkingWaterGeoJson;
        if (!mounted || controller == null || geoJson == null) return;
        try {
          await _serializePoiStyleOperation(() async {
            if (!mounted ||
                !_styleLoaded ||
                !identical(controller, _mapController)) {
              return;
            }
            if (!_drinkingWaterGeoJsonReady) {
              await controller.addGeoJsonSource(
                _kDrinkingWaterSourceId,
                geoJson,
              );
              await controller.addImage(
                _kDrinkingWaterImageId,
                await _createDrinkingWaterImage(),
              );
              await controller.addSymbolLayer(
                _kDrinkingWaterSourceId,
                _kDrinkingWaterLayerId,
                const SymbolLayerProperties(
                  iconImage: _kDrinkingWaterImageId,
                  iconSize: 1.0,
                  iconAllowOverlap: true,
                  iconIgnorePlacement: false,
                ),
                belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
                minzoom: 13,
                enableInteraction: false,
              );
              _drinkingWaterGeoJsonReady = true;
            } else {
              await controller.setGeoJsonSource(
                _kDrinkingWaterSourceId,
                geoJson,
              );
            }
          });
        } catch (error, stackTrace) {
          // Style changes can race an optional background update. The latest
          // data remains in memory and is applied by the next style callback.
          _drinkingWaterGeoJsonReady = false;
          log.w(
            'Displaying drinking-water POIs failed',
            error: error,
            stackTrace: stackTrace,
          );
        }
      } while (_drinkingWaterSyncQueued);
    } finally {
      _drinkingWaterSyncRunning = false;
      if (_drinkingWaterSyncQueued) _scheduleDrinkingWaterSync();
    }
  }

  void _schedulePublicToiletsSync() {
    if (!_styleLoaded || _publicToiletsGeoJson == null) return;
    if (_publicToiletsSyncRunning) {
      _publicToiletsSyncQueued = true;
      return;
    }
    _publicToiletsSyncRunning = true;
    unawaited(_runPublicToiletsSync());
  }

  Future<void> _runPublicToiletsSync() async {
    try {
      do {
        _publicToiletsSyncQueued = false;
        final controller = _mapController;
        final geoJson = _publicToiletsGeoJson;
        if (!mounted || controller == null || geoJson == null) return;
        try {
          await _serializePoiStyleOperation(() async {
            if (!mounted ||
                !_styleLoaded ||
                !identical(controller, _mapController)) {
              return;
            }
            if (!_publicToiletsGeoJsonReady) {
              await controller.addGeoJsonSource(
                  _kPublicToiletsSourceId, geoJson);
              await controller.addImage(
                _kPublicToiletsImageId,
                await _createPoiIconImage(Icons.wc),
              );
              await controller.addSymbolLayer(
                _kPublicToiletsSourceId,
                _kPublicToiletsLayerId,
                const SymbolLayerProperties(
                  iconImage: _kPublicToiletsImageId,
                  iconSize: .9,
                  iconAllowOverlap: true,
                  iconIgnorePlacement: true,
                ),
                minzoom: 16,
                enableInteraction: false,
              );
              _publicToiletsGeoJsonReady = true;
            } else {
              await controller.setGeoJsonSource(
                  _kPublicToiletsSourceId, geoJson);
            }
          });
        } catch (error, stackTrace) {
          _publicToiletsGeoJsonReady = false;
          log.w('Displaying public-toilet POIs failed',
              error: error, stackTrace: stackTrace);
        }
      } while (_publicToiletsSyncQueued);
    } finally {
      _publicToiletsSyncRunning = false;
      if (_publicToiletsSyncQueued) _schedulePublicToiletsSync();
    }
  }

  void _scheduleRepairStationsSync() {
    if (!_styleLoaded || _repairStationsGeoJson == null) return;
    if (_repairStationsSyncRunning) {
      _repairStationsSyncQueued = true;
      return;
    }
    _repairStationsSyncRunning = true;
    unawaited(_runRepairStationsSync());
  }

  Future<void> _runRepairStationsSync() async {
    try {
      do {
        _repairStationsSyncQueued = false;
        final controller = _mapController;
        final geoJson = _repairStationsGeoJson;
        if (!mounted || controller == null || geoJson == null) return;
        try {
          await _serializePoiStyleOperation(() async {
            if (!mounted ||
                !_styleLoaded ||
                !identical(controller, _mapController)) {
              return;
            }
            if (!_repairStationsGeoJsonReady) {
              await controller.addGeoJsonSource(
                  _kRepairStationsSourceId, geoJson);
              await controller.addImage(
                _kRepairStationsImageId,
                await _createPoiIconImage(Icons.build),
              );
              await controller.addSymbolLayer(
                _kRepairStationsSourceId,
                _kRepairStationsLayerId,
                const SymbolLayerProperties(
                  iconImage: _kRepairStationsImageId,
                  iconSize: 1,
                  iconAllowOverlap: true,
                  iconIgnorePlacement: true,
                ),
                belowLayerId: kOpenFreeMapBasemapOverlayBelowLayerId,
                minzoom: 13,
                enableInteraction: false,
              );
              _repairStationsGeoJsonReady = true;
            } else {
              await controller.setGeoJsonSource(
                  _kRepairStationsSourceId, geoJson);
            }
          });
        } catch (error, stackTrace) {
          _repairStationsGeoJsonReady = false;
          log.w('Displaying bicycle-repair-station POIs failed',
              error: error, stackTrace: stackTrace);
        }
      } while (_repairStationsSyncQueued);
    } finally {
      _repairStationsSyncRunning = false;
      if (_repairStationsSyncQueued) _scheduleRepairStationsSync();
    }
  }

  Future<void> _serializePoiStyleOperation(
    Future<void> Function() operation,
  ) async {
    final previous = _poiStyleOperationTail;
    final completed = Completer<void>();
    _poiStyleOperationTail = completed.future;
    try {
      await previous;
      await operation();
    } finally {
      completed.complete();
    }
  }
}
