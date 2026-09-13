import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/brouter_api.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/saved_route.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/routing/oberbayern_coverage.dart';
import 'package:munich_ways/routing/route_error_message.dart';
import 'package:munich_ways/routing/routing_preferences.dart';
import 'package:munich_ways/routing/routing_service.dart';
import 'package:munich_ways/screenshots/store_screenshot_config.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Which horizontal edge the map side control column is pinned to.
enum MapSidePanelEdge {
  left,
  right,
}

class MapScreenViewModel extends ChangeNotifier {
  static const _ratingsRequestTimeout = Duration(seconds: 6);
  static const _initialRatingsRequestTimeout = Duration(seconds: 30);

  static const _refreshLocationSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    timeLimit: Duration(seconds: 10),
  );

  static const _routeStartLocationSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    timeLimit: Duration(seconds: 8),
  );

  bool loading = false;

  bool _firstLoad = true;
  bool _initialLoadStarted = false;
  bool get initialLoadComplete => !_firstLoad;
  bool initialRatingsLoadFailed = false;

  /// Set true after [primeLocationForStoreScreenshots] finishes (success or hard failure).
  bool storeScreenshotLocationPrimeComplete = false;

  /// Zoom +/- overlay buttons; default on.
  bool _showZoomButtons = true;

  /// Side column for layers / location / compass (zoom if enabled).
  MapSidePanelEdge _sidePanelEdge = MapSidePanelEdge.right;

  bool get showZoomButtons => _showZoomButtons;

  MapSidePanelEdge get sidePanelEdge => _sidePanelEdge;

  void setShowZoomButtons(bool value) {
    if (_showZoomButtons == value) return;
    _showZoomButtons = value;
    notifyListeners();
    _persistSettings();
  }

  void setSidePanelEdge(MapSidePanelEdge value) {
    if (_sidePanelEdge == value) return;
    _sidePanelEdge = value;
    notifyListeners();
    _persistSettings();
  }

  void setVoiceGuidanceEnabled(bool value) {
    if (_voiceGuidanceEnabled == value) return;
    _voiceGuidanceEnabled = value;
    notifyListeners();
    _settingsStore.saveVoiceGuidanceEnabled(value).catchError(
      (Object e, StackTrace st) {
        log.e(
          'Failed to save voice guidance setting',
          error: e,
          stackTrace: st,
        );
      },
    );
  }

  void setAutomaticReroutingEnabled(bool value) {
    if (_automaticReroutingEnabled == value) return;
    _automaticReroutingEnabled = value;
    notifyListeners();
    _settingsStore.saveAutomaticReroutingEnabled(value).catchError(
          (Object e, StackTrace st) => log.e(
            'Failed to save automatic rerouting setting',
            error: e,
            stackTrace: st,
          ),
        );
  }

  void setRoutingMode(RoutingMode value) {
    if (_routingMode == value) return;
    _routingMode = value;
    _routeRecommendation = null;
    notifyListeners();
    _settingsStore.saveRoutingMode(value).catchError(
      (Object e, StackTrace st) {
        log.e('Failed to save routing mode', error: e, stackTrace: st);
      },
    );
    _settingsStore.saveRouteRecommendation(null);
    if (destination != null) {
      unawaited(_requestRoute());
    }
  }

  void setBRouterProfile(BRouterProfile value) {
    if (_bRouterProfile == value) return;
    _bRouterProfile = value;
    _routeRecommendation = null;
    notifyListeners();
    _settingsStore.saveBRouterProfile(value).catchError(
      (Object e, StackTrace st) {
        log.e('Failed to save BRouter profile', error: e, stackTrace: st);
      },
    );
    _settingsStore.saveRouteRecommendation(null);
    if (destination != null) {
      unawaited(_requestRoute());
    }
  }

  void _persistSettings() {
    _settingsStore
        .saveMapSettings(
      showZoomButtons: _showZoomButtons,
      sidePanelEdgeName: _sidePanelEdge.name,
    )
        .catchError((Object e, StackTrace st) {
      log.e('Failed to save settings', error: e, stackTrace: st);
    });
  }

  void _applyLoadedSettings(SettingsData data) {
    final edge = data.sidePanelEdgeName == 'left'
        ? MapSidePanelEdge.left
        : MapSidePanelEdge.right;
    final routingMode = data.routingMode;
    if (data.showZoomButtons == _showZoomButtons &&
        edge == _sidePanelEdge &&
        data.voiceGuidanceEnabled == _voiceGuidanceEnabled &&
        data.automaticReroutingEnabled == _automaticReroutingEnabled &&
        routingMode == _routingMode &&
        data.bRouterProfile == _bRouterProfile &&
        data.routeRecommendation == _routeRecommendation) {
      return;
    }
    _showZoomButtons = data.showZoomButtons;
    _sidePanelEdge = edge;
    _voiceGuidanceEnabled = data.voiceGuidanceEnabled;
    _automaticReroutingEnabled = data.automaticReroutingEnabled;
    _routingMode = routingMode;
    _bRouterProfile = data.bRouterProfile;
    _routeRecommendation = data.routeRecommendation;
    notifyListeners();
  }

  double? bearing;

  MapRoute route = MapRoute(null, MapRouteState.NO_ROUTE);

  Set<MPolyline> get polylines {
    Set<MPolyline> tempPolylines = _polylinesGesamtnetz
        .where((polyline) =>
            (polyline.isGesamtnetz && _isGesamtnetzVisible) ||
            (polyline.isRadlVorrangNetz && _isRadlvorrangnetzVisible))
        .toSet();
    return tempPolylines;
  }

  Place? destination = null;
  Place? routeStart;
  final List<Place> waypoints = [];
  SavedRoute? selectedSavedRoute;
  int _routePlanRevision = 0;
  int _lastPassedWaypointIndex = -1;

  bool get hasCustomRoute => routeStart != null || waypoints.isNotEmpty;

  bool _isRadlvorrangnetzVisible = true;
  bool _isGesamtnetzVisible = true;

  bool get isRadlvorrangnetzVisible {
    return _isRadlvorrangnetzVisible;
  }

  bool get isGesamtnetzVisible {
    return _isGesamtnetzVisible;
  }

  LocationState locationState = LocationState.NOT_AVAILABLE;
  bool _navigationStarted = false;
  bool get navigationStarted => _navigationStarted;
  bool _voiceGuidanceEnabled = false;
  bool get voiceGuidanceEnabled => _voiceGuidanceEnabled;
  bool _automaticReroutingEnabled = true;
  bool get automaticReroutingEnabled => _automaticReroutingEnabled;
  bool get voiceGuidanceAvailable =>
      route.route?.supportsVoiceGuidance ?? false;
  RoutingMode _routingMode = RoutingMode.automatic;
  RoutingMode get routingMode => _routingMode;
  BRouterProfile _bRouterProfile = BRouterProfile.trekking;
  BRouterProfile get bRouterProfile => _bRouterProfile;
  RouteRecommendation? _routeRecommendation = RouteRecommendation.standard;
  RouteRecommendation? get routeRecommendation => _routeRecommendation;

  Set<MPolyline> _polylinesGesamtnetz = {};
  Map<String, StreetDetails> _streetDetailsByFeatureId = {};
  int _networkRevision = 0;
  int get networkRevision => _networkRevision;

  StreetDetails? streetDetailsForFeatureId(dynamic rawId) {
    if (rawId == null) return null;
    return _streetDetailsByFeatureId[rawId.toString()];
  }

  Future<void> _loadStreetDetailsInBackground() async {
    try {
      final details = await _munichwaysApi.getStreetDetails();
      _streetDetailsByFeatureId = details;
      log.d('street details loaded in background: ${details.length}');
    } catch (e, st) {
      // Details are optional. Ratings, routing and navigation remain usable.
      log.e(
        'Street details background load failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  MunichwaysApi _munichwaysApi = MunichwaysApi();
  late final RoutingService _routingService;
  bool _disposed = false;
  late final SettingsStore _settingsStore;

  late Stream<String> errorMsgs;
  late StreamController<String> _errorMsgsController;

  late Stream showLocationPermissionDialog;
  late StreamController _permissionStreamController;

  late Stream showEnableLocationServiceDialog;
  late StreamController _showEnableLocationServiceDialogController;

  late Stream<StreetDetails?> showStreetDetails;
  late StreamController<StreetDetails?> showStreetDetailsController;

  late Stream<LatLng> currentLocationBtnClickedStream;
  late StreamController<LatLng> currentLocationBtnClickedController;

  late Stream<Place> destinationStream;
  late StreamController<Place> _destinationStreamController;

  late Stream<MapRoute> routeStream;
  late StreamController<MapRoute> _routeStreamController;

  MapScreenViewModel({
    RoutingService? routingService,
    SettingsStore? store,
    MunichwaysApi? munichwaysApi,
  }) {
    _routingService = routingService ??
        RoutingService(
          radlNavi: RadlNaviApi(),
          bRouter: BRouterApi(),
          radlNaviCoverage: OberbayernCoverage(),
        );
    _settingsStore = store ?? settingsStore;
    _munichwaysApi = munichwaysApi ?? MunichwaysApi();
    _errorMsgsController = StreamController();
    errorMsgs = _errorMsgsController.stream;
    _permissionStreamController = StreamController();
    showLocationPermissionDialog = _permissionStreamController.stream;
    _showEnableLocationServiceDialogController = StreamController();
    showEnableLocationServiceDialog =
        _showEnableLocationServiceDialogController.stream;
    showStreetDetailsController = StreamController<StreetDetails?>();
    showStreetDetails = showStreetDetailsController.stream;
    currentLocationBtnClickedController = StreamController();
    currentLocationBtnClickedStream =
        currentLocationBtnClickedController.stream;
    _destinationStreamController = StreamController();
    destinationStream = _destinationStreamController.stream;
    _routeStreamController = StreamController();
    routeStream = _routeStreamController.stream;

    _settingsStore.load().then((data) {
      _applyLoadedSettings(data);
    }).catchError((Object e, StackTrace st) {
      log.e('Failed to load settings', error: e, stackTrace: st);
    });
  }

  void _displayErrorMsg(String msg) {
    _errorMsgsController.add(msg);
  }

  void onMapReady() {
    if (kStoreScreenshots) {
      unawaited(primeLocationForStoreScreenshots());
    }
  }

  void startInitialLoad() {
    if (_initialLoadStarted) return;
    _initialLoadStarted = true;
    // The network/cache enrichment is optional background content. A cold
    // install may need longer than the regular interactive reload timeout for
    // TLS setup, download and cache creation, while the map, location and
    // routing remain usable independently.
    unawaited(refreshRadlnetze(requestTimeout: _initialRatingsRequestTimeout));
  }

  /// Requests a fresh GPS fix so Android's cached last-known location is updated.
  /// Returns false without requesting a fix when system location is disabled.
  Future<bool> refreshCurrentLocationFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      locationState = LocationState.NOT_AVAILABLE;
      notifyListeners();
      return false;
    }
    try {
      await Geolocator.getCurrentPosition(
        locationSettings: _refreshLocationSettings,
      );
      return true;
    } catch (e, st) {
      log.d('refreshCurrentLocationFix failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Prefer a live fix for routing; fall back to last known if GPS is slow.
  Future<Position?> resolveRouteStartPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _routeStartLocationSettings,
      );
    } catch (e, st) {
      log.d(
        'resolveRouteStartPosition: getCurrentPosition failed, trying last known',
        error: e,
        stackTrace: st,
      );
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Obtains permission and a GPS fix without entering follow/compass tracking.
  /// Used for App Store screenshot automation so the map stays in a stable overview.
  Future<void> primeLocationForStoreScreenshots() async {
    if (!kStoreScreenshots) return;
    storeScreenshotLocationPrimeComplete = false;
    notifyListeners();

    final isLocationServiceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      locationState = LocationState.NOT_AVAILABLE;
      storeScreenshotLocationPrimeComplete = true;
      notifyListeners();
      return;
    }

    var permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          locationState = LocationState.NOT_AVAILABLE;
          storeScreenshotLocationPrimeComplete = true;
          notifyListeners();
          return;
        }
        break;
      case LocationPermission.deniedForever:
        locationState = LocationState.NOT_AVAILABLE;
        storeScreenshotLocationPrimeComplete = true;
        notifyListeners();
        return;
      case LocationPermission.unableToDetermine:
        locationState = LocationState.NOT_AVAILABLE;
        storeScreenshotLocationPrimeComplete = true;
        notifyListeners();
        return;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        break;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      locationState = LocationState.DISPLAY;
      notifyListeners();
      currentLocationBtnClickedController.add(
        LatLng(position.latitude, position.longitude),
      );
    } catch (e, st) {
      log.e('primeLocationForStoreScreenshots', error: e, stackTrace: st);
      locationState = LocationState.NOT_AVAILABLE;
      notifyListeners();
    } finally {
      storeScreenshotLocationPrimeComplete = true;
      notifyListeners();
    }
  }

  /// Toggle follow mode and notify the UI. MapLibre's native tracking mode
  /// centres the camera automatically once active, so no manual [animateCamera]
  /// call is made here. On Android, calling [animateCamera] with a new lat/lng
  /// target while tracking mode is active fires [onCameraTrackingDismissed],
  /// which would immediately cancel tracking.
  Future<void> _enterLocationFollowAndCenterCamera() async {
    if (locationState == LocationState.FOLLOW) {
      locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    } else {
      locationState = LocationState.FOLLOW;
    }
    notifyListeners();
  }

  Future<void> onPressLocationBtn({
    bool permissionCheck = true,
    bool followLocation = true,
  }) async {
    log.d("onPressLocationBtn");
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      locationState = LocationState.NOT_AVAILABLE;
      notifyListeners();
      if (permissionCheck) {
        _showEnableLocationServiceDialogController.add("");
      } else {
        log.d("location service disabled; continue without location");
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    log.d(permission);
    if (!permissionCheck &&
        (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever)) {
      log.d("ignore missing permission");
      return;
    }
    switch (permission) {
      case LocationPermission.denied:
        final afterRequest = await Geolocator.requestPermission();
        log.d(afterRequest);
        if (afterRequest == LocationPermission.denied) {
          locationState = LocationState.NOT_AVAILABLE;
          notifyListeners();
          _displayErrorMsg("Standort Berechtigung fehlt.");
        } else if (afterRequest == LocationPermission.deniedForever) {
          _permissionStreamController.add("");
        } else if (afterRequest == LocationPermission.whileInUse ||
            afterRequest == LocationPermission.always) {
          if (followLocation) {
            await _enterLocationFollowAndCenterCamera();
          } else {
            locationState = LocationState.DISPLAY;
            notifyListeners();
          }
        } else if (afterRequest == LocationPermission.unableToDetermine) {
          _permissionStreamController.add("");
        }
        break;
      case LocationPermission.deniedForever:
        _permissionStreamController.add("");
        break;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        if (followLocation) {
          await _enterLocationFollowAndCenterCamera();
        } else {
          locationState = LocationState.DISPLAY;
          notifyListeners();
        }
        break;
      case LocationPermission.unableToDetermine:
        _permissionStreamController.add("");
        break;
    }
  }

  /// Enters turn-by-turn navigation tracking in one action.
  ///
  /// The regular location button deliberately cycles through follow modes.
  /// Navigation start instead advances directly to follow-and-rotate, while
  /// reusing the same location-service and permission handling.
  Future<bool> startNavigation() async {
    if (locationState == LocationState.FOLLOW_AND_ROTATE_MAP) {
      // A late planning choice must never replace navigation after departure.
      _selectionRevision++;
      _pendingVariant = null;
      _navigationStarted = true;
      notifyListeners();
      return true;
    }

    if (locationState != LocationState.FOLLOW) {
      await onPressLocationBtn();
    }
    if (locationState == LocationState.FOLLOW) {
      locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
      // A late planning choice must never replace navigation after departure.
      _selectionRevision++;
      _pendingVariant = null;
      _navigationStarted = true;
      notifyListeners();
    }
    return locationState == LocationState.FOLLOW_AND_ROTATE_MAP;
  }

  void toggleGesamtnetzVisible() {
    _isGesamtnetzVisible = !_isGesamtnetzVisible;
    notifyListeners();
  }

  void toggleRadvorrangnetzVisible() {
    _isRadlvorrangnetzVisible = !_isRadlvorrangnetzVisible;
    notifyListeners();
  }

  /// North-up / compass control: stop follow/compass tracking like a map gesture.
  void onCompassNorthUpPressed() {
    if (locationState == LocationState.NOT_AVAILABLE) {
      return;
    }
    locationState = LocationState.DISPLAY;
    notifyListeners();
  }

  Future<bool> refreshRadlnetze({
    Duration minimumLoadingDuration = Duration.zero,
    Duration requestTimeout = _ratingsRequestTimeout,
  }) async {
    final startedAt = DateTime.now();
    final isInitialLoad = _firstLoad;
    loading = true;
    notifyListeners();
    var receivedData = false;
    var refreshFailed = false;
    var detailsLoadStarted = false;

    try {
      await for (final polylines in _munichwaysApi.getRadlvorrangnetzUpdates(
          responseTimeout: requestTimeout)) {
        log.d('ratings received by map model: ${polylines.length} polylines');
        _polylinesGesamtnetz = polylines;
        _networkRevision++;
        receivedData = true;
        if (!detailsLoadStarted) {
          detailsLoadStarted = true;
          // Prioritize the bundled geometry, then load full Munich details in
          // parallel with the lightweight Upper Bavaria update.
          unawaited(_loadStreetDetailsInBackground());
        }
        if (_firstLoad) {
          _firstLoad = false;
        }
        if (minimumLoadingDuration == Duration.zero) {
          loading = false;
        }
        log.d(
          'ratings ready: sourceSize=${polylines.length}, '
          'loading=$loading, revision=$_networkRevision',
        );
        notifyListeners();
      }
      return receivedData;
    } catch (e) {
      refreshFailed = true;
      if (!receivedData) {
        _displayErrorMsg(
          'Bewertungen konnten nicht geladen werden. '
          'Die Karte kann weiterhin verwendet werden.',
        );
      }
      if (e is! TimeoutException) {
        log.e("Error loading Netze", error: e);
      }
      return false;
    } finally {
      final remaining =
          minimumLoadingDuration - DateTime.now().difference(startedAt);
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      if (_firstLoad) {
        _firstLoad = false;
      }
      if (isInitialLoad && refreshFailed) {
        initialRatingsLoadFailed = true;
      }
      loading = false;
      log.d(
        'ratings refresh finished: receivedData=$receivedData, '
        'loading=$loading, revision=$_networkRevision',
      );
      notifyListeners();
    }
  }

  /// Clears the Radnetz GeoJSON cache, then downloads and parses it again so the map
  /// overlay can update without leaving the screen.
  Future<bool> reloadRadnetz() async {
    loading = true;
    notifyListeners();
    await _munichwaysApi.removeRatingsCache();
    final updated = await refreshRadlnetze(
      minimumLoadingDuration: const Duration(milliseconds: 1500),
    );
    initialRatingsLoadFailed = !updated;
    notifyListeners();
    return updated;
  }

  bool get shortestRouteEnabled =>
      _routingMode == RoutingMode.bRouterEverywhere &&
      _bRouterProfile == BRouterProfile.shortest;

  /// A route-scoped alternative to the persisted routing preference.
  ///
  /// It remains active for retries and rerouting, but is cleared when the
  /// current route is ended or replaced with a new destination.
  bool _temporaryShortestRouteEnabled = false;
  bool get temporaryShortestRouteEnabled => _temporaryShortestRouteEnabled;
  bool get canSelectTemporaryShortestRoute => !shortestRouteEnabled;

  /// Cached alternatives share one plan revision and never replace each other
  /// merely because a background request or comfort analysis completes.
  final Map<bool, MapRoute> _variants = {};
  final Map<bool, Future<bool>> _variantRequests = {};
  List<LatLng>? _variantCoordinates;
  int _selectionRevision = 0;
  bool? _pendingVariant;
  bool? get pendingRouteVariant => _pendingVariant;
  MapRoute? routeVariant(bool direct) => _variants[direct];
  bool get hasRouteComparison =>
      canSelectTemporaryShortestRoute && _variants.isNotEmpty;

  Future<bool> setTemporaryShortestRouteEnabled(bool enabled) async {
    if (enabled && shortestRouteEnabled) return false;
    if (_navigationStarted) {
      return _switchRouteVariantDuringNavigation(enabled);
    }
    final selection = ++_selectionRevision;
    _pendingVariant = null;
    if (_temporaryShortestRouteEnabled == enabled) {
      notifyListeners();
      return false;
    }
    if (destination == null || _variantCoordinates == null) {
      _temporaryShortestRouteEnabled = enabled;
      notifyListeners();
      if (destination == null) return false;
      return _requestRoute();
    }
    final revision = _routePlanRevision;
    _pendingVariant = enabled;
    notifyListeners();
    final ready = await (_variantRequests[enabled] ??
        _calculateVariant(enabled, revision));
    if (_disposed ||
        revision != _routePlanRevision ||
        selection != _selectionRevision) return false;
    _pendingVariant = null;
    if (ready) {
      _temporaryShortestRouteEnabled = enabled;
      route = _variants[enabled]!;
      _routeStreamController.add(route);
    } else {
      _displayErrorMsg(
          'Die gewählte Route ist derzeit nicht verfügbar. Bitte erneut versuchen.');
    }
    notifyListeners();
    return ready;
  }

  Future<bool> _switchRouteVariantDuringNavigation(bool enabled) async {
    final selection = ++_selectionRevision;
    _pendingVariant = null;
    if (_temporaryShortestRouteEnabled == enabled) {
      notifyListeners();
      return false;
    }
    final targetDestination = destination;
    if (targetDestination == null) return false;

    routeStart = null;
    if (_lastPassedWaypointIndex >= 0) {
      final passedCount =
          (_lastPassedWaypointIndex + 1).clamp(0, waypoints.length).toInt();
      waypoints.removeRange(0, passedCount);
    }
    _lastPassedWaypointIndex = -1;

    final revision = ++_routePlanRevision;
    final activeDirect = _temporaryShortestRouteEnabled;
    final activeRoute = route;
    _variants.clear();
    _variantRequests.clear();
    _variantCoordinates = null;
    if (activeRoute.state == MapRouteState.SHOWN && activeRoute.route != null) {
      _variants[activeDirect] = activeRoute;
    }
    _pendingVariant = enabled;
    notifyListeners();

    final from = await resolveRouteStartPosition();
    if (_disposed ||
        revision != _routePlanRevision ||
        selection != _selectionRevision ||
        destination != targetDestination) {
      return false;
    }
    if (from == null) {
      _pendingVariant = null;
      _displayErrorMsg(
          'Keine Route, da kein aktueller Standort als Start vorhanden');
      notifyListeners();
      return false;
    }
    _variantCoordinates = List.unmodifiable([
      LatLng(from.latitude, from.longitude),
      ...waypoints.map((place) => place.latLng),
      targetDestination.latLng,
    ]);

    final ready = await _calculateVariant(enabled, revision);
    if (_disposed ||
        revision != _routePlanRevision ||
        selection != _selectionRevision) {
      return false;
    }
    _pendingVariant = null;
    if (!ready) {
      _displayErrorMsg(
          'Die gewählte Route ist derzeit nicht verfügbar. Bitte erneut versuchen.');
      notifyListeners();
      return false;
    }

    _temporaryShortestRouteEnabled = enabled;
    route = _variants[enabled]!;
    _routeStreamController.add(route);
    notifyListeners();
    return true;
  }

  void _clearTemporaryShortestRoute() {
    _temporaryShortestRouteEnabled = false;
    _invalidateVariants();
  }

  void _invalidateVariants() {
    _selectionRevision++;
    _pendingVariant = null;
    _variants.clear();
    _variantRequests.clear();
    _variantCoordinates = null;
  }

  void setShortestRouteEnabled(bool enabled) {
    final routingMode =
        enabled ? RoutingMode.bRouterEverywhere : RoutingMode.automatic;
    final profile = enabled ? BRouterProfile.shortest : BRouterProfile.trekking;
    if (_routingMode == routingMode && _bRouterProfile == profile) return;
    _routingMode = routingMode;
    _bRouterProfile = profile;
    _routeRecommendation =
        enabled ? RouteRecommendation.shortest : RouteRecommendation.standard;
    notifyListeners();
    Future.wait([
      _settingsStore.saveRoutingMode(routingMode),
      _settingsStore.saveBRouterProfile(profile),
      _settingsStore.saveRouteRecommendation(_routeRecommendation),
    ]).catchError((Object e, StackTrace st) {
      log.e(
        'Failed to save shortest route setting',
        error: e,
        stackTrace: st,
      );
      return <void>[];
    });
    if (destination != null) {
      unawaited(_requestRoute());
    }
  }

  void setRouteRecommendation(RouteRecommendation recommendation) {
    final (routingMode, profile) = switch (recommendation) {
      RouteRecommendation.standard || RouteRecommendation.hotWeather => (
          RoutingMode.automatic,
          BRouterProfile.trekking
        ),
      RouteRecommendation.trekking => (
          RoutingMode.bRouterEverywhere,
          BRouterProfile.trekking
        ),
      RouteRecommendation.roadBike => (
          RoutingMode.bRouterEverywhere,
          BRouterProfile.fastBike
        ),
      RouteRecommendation.shortest => (
          RoutingMode.bRouterEverywhere,
          BRouterProfile.shortest
        ),
      RouteRecommendation.aloneAfterDark || RouteRecommendation.snowAndMud => (
          RoutingMode.bRouterEverywhere,
          BRouterProfile.fastBike
        ),
    };
    if (_routeRecommendation == recommendation &&
        _routingMode == routingMode &&
        _bRouterProfile == profile) {
      return;
    }
    _routeRecommendation = recommendation;
    _routingMode = routingMode;
    _bRouterProfile = profile;
    notifyListeners();
    Future.wait([
      _settingsStore.saveRouteRecommendation(recommendation),
      _settingsStore.saveRoutingMode(routingMode),
      _settingsStore.saveBRouterProfile(profile),
    ]).catchError((Object e, StackTrace st) {
      log.e('Failed to save route recommendation', error: e, stackTrace: st);
      return <void>[];
    });
    if (destination != null) unawaited(_requestRoute());
  }

  void onTap(StreetDetails? details) {
    log.d(details);
    showStreetDetailsController.add(details);
  }

  /// MapLibre: call from [MapLibreMap.onCameraMove] with the camera target.
  void onMapCenterChanged(LatLng center) {
    if (destination != null) {
      bearing = Geolocator.bearingBetween(
        center.latitude,
        center.longitude,
        destination!.latLng.latitude,
        destination!.latLng.longitude,
      );
      bearing = (bearing! + 360) % 360;
      // notifyListeners() intentionally omitted: bearing is not consumed by any
      // widget, so rebuilding the Consumer tree on every camera frame (60fps)
      // would cause overheating and jank with no visible benefit.
    }
  }

  /// Called when the user touches the map and breaks camera following.
  void onUserStoppedFollowingLocation() {
    if (locationState == LocationState.FOLLOW ||
        locationState == LocationState.FOLLOW_AND_ROTATE_MAP) {
      locationState = LocationState.DISPLAY;
      notifyListeners();
    }
  }

  void setDestination(Place? place) {
    if (place == null) {
      return;
    }
    if (locationState == LocationState.FOLLOW ||
        locationState == LocationState.FOLLOW_AND_ROTATE_MAP) {
      locationState = LocationState.DISPLAY;
    }
    routeStart = null;
    waypoints.clear();
    selectedSavedRoute = null;
    _clearTemporaryShortestRoute();
    _lastPassedWaypointIndex = -1;
    _routePlanRevision++;
    this.destination = place;
    // A new destination prepares a new route. Navigation must be started
    // explicitly so tracking and guidance are initialized for that route.
    _navigationStarted = false;
    notifyListeners();
    _destinationStreamController.add(place);

    // keep screen on while locating destination is on
    WakelockPlus.enable();

    unawaited(_requestRoute());
  }

  /// Sets a new destination and completes once its route calculation finishes.
  /// Used by deliberate quick actions that should enter navigation immediately.
  Future<bool> setDestinationAndCalculateRoute(Place place) {
    if (locationState == LocationState.FOLLOW ||
        locationState == LocationState.FOLLOW_AND_ROTATE_MAP) {
      locationState = LocationState.DISPLAY;
    }
    routeStart = null;
    waypoints.clear();
    selectedSavedRoute = null;
    _clearTemporaryShortestRoute();
    _lastPassedWaypointIndex = -1;
    _routePlanRevision++;
    destination = place;
    _navigationStarted = false;
    notifyListeners();
    _destinationStreamController.add(place);
    WakelockPlus.enable();
    return _requestRoute();
  }

  /// Applies the optional route-planning stops in one update.
  ///
  /// A null [start] keeps the established default of using the current GPS
  /// position. The regular destination search clears these options again.
  void setRoutePlan({
    required Place? start,
    required List<Place> stops,
    required Place destination,
  }) {
    final wasNavigating = _navigationStarted;
    if (!wasNavigating &&
        this.destination != null &&
        this.destination != destination) {
      _clearTemporaryShortestRoute();
    }
    if (!wasNavigating &&
        (locationState == LocationState.FOLLOW ||
            locationState == LocationState.FOLLOW_AND_ROTATE_MAP)) {
      locationState = LocationState.DISPLAY;
    }
    routeStart = wasNavigating ? null : start;
    waypoints
      ..clear()
      ..addAll(stops);
    _lastPassedWaypointIndex = -1;
    this.destination = destination;
    _routePlanRevision++;
    _navigationStarted = wasNavigating;
    notifyListeners();
    _destinationStreamController.add(destination);
    WakelockPlus.enable();
    unawaited(_requestRoute());
  }

  void setSavedRoutePlan(SavedRoute route) {
    _clearTemporaryShortestRoute();
    selectedSavedRoute = route;
    setRoutePlan(
      start: route.start,
      stops: route.stops,
      destination: route.destination,
    );
  }

  void markRouteSaved(SavedRoute route) {
    selectedSavedRoute = route;
  }

  void clearDestination() {
    // Drop any in-flight route so a late response cannot repopulate the map.
    this.destination = null;
    routeStart = null;
    waypoints.clear();
    selectedSavedRoute = null;
    _clearTemporaryShortestRoute();
    _lastPassedWaypointIndex = -1;
    _routePlanRevision++;
    _navigationStarted = false;
    notifyListeners();

    // turn screen off when locating destination is off
    WakelockPlus.disable();

    _clearRoute();
  }

  /// Recalculates the route from the current location to the current destination.
  Future<bool> refreshRoute() {
    if (destination == null) {
      return Future<bool>.value(false);
    }
    if (_navigationStarted) {
      routeStart = null;
      if (_lastPassedWaypointIndex >= 0) {
        final passedCount =
            (_lastPassedWaypointIndex + 1).clamp(0, waypoints.length).toInt();
        waypoints.removeRange(0, passedCount);
      }
      _lastPassedWaypointIndex = -1;
      _routePlanRevision++;
      notifyListeners();
    }
    return _requestRoute();
  }

  /// Records the furthest intermediate stop reached during this navigation.
  ///
  /// Reaching a later stop also marks every earlier stop as obsolete. Stops
  /// that were passed at a distance remain pending and are kept on refresh.
  void updateWaypointProgress(
    LatLng position, {
    double reachedDistanceMeters = 30,
  }) {
    if (!_navigationStarted || waypoints.isEmpty) return;
    for (var index = _lastPassedWaypointIndex + 1;
        index < waypoints.length;
        index++) {
      final waypoint = waypoints[index].latLng;
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        waypoint.latitude,
        waypoint.longitude,
      );
      if (distance <= reachedDistanceMeters) {
        _lastPassedWaypointIndex = index;
      }
    }
  }

  Future<bool> _requestRoute() async {
    final to = destination;
    if (to == null || _disposed) return false;
    // Every refresh has a new generation, including two overlapping GPS fixes.
    final revision = ++_routePlanRevision;
    _invalidateVariants();
    final direct = _temporaryShortestRouteEnabled;
    route = MapRoute(null, MapRouteState.LOADING);
    notifyListeners();
    final customStart = routeStart;
    final plannedStops = List<Place>.of(waypoints);
    Position? from;
    if (customStart == null) {
      try {
        from = await resolveRouteStartPosition()
            .timeout(const Duration(seconds: 16));
      } catch (error, stackTrace) {
        // Even the cached-location fallback can fail or never reply. Finish
        // this attempt normally so automatic and manual retries can recover.
        log.w('Resolving route start failed',
            error: error, stackTrace: stackTrace);
      }
    }
    if (_disposed || destination != to || revision != _routePlanRevision)
      return false;
    if (customStart == null && from == null) {
      _displayErrorMsg(
          'Keine Route, da kein aktueller Standort als Start vorhanden');
      route = MapRoute(null, MapRouteState.ERROR);
      notifyListeners();
      return false;
    }
    _variantCoordinates = List.unmodifiable([
      customStart?.latLng ?? LatLng(from!.latitude, from.longitude),
      ...plannedStops.map((place) => place.latLng),
      to.latLng,
    ]);
    final ready = await _calculateVariant(direct, revision, activate: true);
    if (_disposed || revision != _routePlanRevision) return false;
    // Start the alternative only after the requested route is already usable.
    if (ready &&
        canSelectTemporaryShortestRoute &&
        _routingService.supportsVariants) {
      unawaited(_calculateVariant(!direct, revision));
    }
    return ready;
  }

  Future<bool> _calculateVariant(bool direct, int revision,
      {bool activate = false}) {
    final cached = _variants[direct];
    if (cached?.state == MapRouteState.SHOWN) return Future.value(true);
    final pending = _variantRequests[direct];
    if (pending != null) return pending;
    final coordinates = _variantCoordinates;
    if (coordinates == null) return Future.value(false);
    final target = MapRoute(null, MapRouteState.LOADING);
    _variants[direct] = target;
    bool isCurrent() =>
        !_disposed &&
        destination != null &&
        revision == _routePlanRevision &&
        identical(_variants[direct], target);
    final request = () async {
      try {
        final value = await _routingService.route(coordinates,
            mode: _routingMode,
            bRouterProfile: _bRouterProfile,
            direct: direct);
        if (!isCurrent()) return false;
        target.route = value;
        target.state = MapRouteState.SHOWN;
        target.comfortState = value.comfort == null
            ? RouteComfortState.unavailable
            : RouteComfortState.ready;
        if (activate && _temporaryShortestRouteEnabled == direct) {
          route = target;
          _routeStreamController.add(route);
        }
        notifyListeners();
        unawaited(_loadRouteComfort(target));
        return true;
      } catch (error, stackTrace) {
        if (!isCurrent()) return false;
        target.state = MapRouteState.ERROR;
        if (activate && _temporaryShortestRouteEnabled == direct) {
          route = target;
          _displayErrorMsg(routeErrorMessage(error));
        } else {
          log.i('Alternative route unavailable',
              error: error, stackTrace: stackTrace);
        }
        notifyListeners();
        return false;
      } finally {
        if (isCurrent()) _variantRequests.remove(direct);
      }
    }();
    _variantRequests[direct] = request;
    notifyListeners();
    return request;
  }

  Future<void> retryRouteComfort({bool? direct}) async {
    final target = direct == null ? route : _variants[direct];
    if (target == null || target.comfortState != RouteComfortState.error)
      return;
    await _loadRouteComfort(target);
  }

  Future<void> _loadRouteComfort(MapRoute target) async {
    final cycleRoute = target.route;
    // A navigation switch retains the active route while calculating the new
    // variant. Its metadata may still complete even across a plan revision.
    // Identity checks reject results for routes that are no longer retained.
    bool isCurrent() =>
        !_disposed &&
        (identical(route, target) ||
            _variants.values.any((value) => identical(value, target))) &&
        identical(target.route, cycleRoute) &&
        destination != null &&
        target.state == MapRouteState.SHOWN;

    if (!isCurrent() ||
        cycleRoute == null ||
        cycleRoute.comfort != null ||
        target.comfortState == RouteComfortState.loading ||
        !_routingService.canAnalyzeComfort(cycleRoute)) {
      return;
    }
    target.comfortState = RouteComfortState.loading;
    notifyListeners();
    try {
      final comfort = await _routingService.analyzeComfort(cycleRoute);
      if (!isCurrent()) return;
      // Preserve navigation identity and do not emit routeStream: both voice
      // progress and the overview camera treat that as a route replacement.
      cycleRoute.comfort = comfort;
      target.comfortState = RouteComfortState.ready;
    } catch (error, stackTrace) {
      if (!isCurrent()) return;
      log.i('Optional route comfort unavailable',
          error: error, stackTrace: stackTrace);
      target.comfortState = RouteComfortState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidateVariants();
    super.dispose();
  }

  void _clearRoute() {
    this.route = MapRoute(null, MapRouteState.NO_ROUTE);
    notifyListeners();
  }
}

enum LocationState {
  NOT_AVAILABLE, // due to missing permission or support of hardware
  DISPLAY, // display current location on map
  FOLLOW, //move map along current location
  FOLLOW_AND_ROTATE_MAP //move map along current location and rotate map in direction user is heading
}
