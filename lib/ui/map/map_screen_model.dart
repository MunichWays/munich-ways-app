import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/screenshots/store_screenshot_config.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Which horizontal edge the map side control column is pinned to.
enum MapSidePanelEdge {
  left,
  right,
}

class MapScreenViewModel extends ChangeNotifier {
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
  bool get initialLoadComplete => !_firstLoad;

  /// Set true after [primeLocationForStoreScreenshots] finishes (success or hard failure).
  bool storeScreenshotLocationPrimeComplete = false;

  /// Zoom +/- overlay buttons; default off.
  bool _showZoomButtons = false;

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

  void _persistSettings() {
    settingsStore
        .save(SettingsData(
      showZoomButtons: _showZoomButtons,
      sidePanelEdgeName: _sidePanelEdge.name,
    ))
        .catchError((Object e, StackTrace st) {
      log.e('Failed to save settings', error: e, stackTrace: st);
    });
  }

  void _applyLoadedSettings(SettingsData data) {
    final edge = data.sidePanelEdgeName == 'left'
        ? MapSidePanelEdge.left
        : MapSidePanelEdge.right;
    if (data.showZoomButtons == _showZoomButtons && edge == _sidePanelEdge) {
      return;
    }
    _showZoomButtons = data.showZoomButtons;
    _sidePanelEdge = edge;
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

  Set<MPolyline> _polylinesGesamtnetz = {};

  MunichwaysApi _munichwaysApi = MunichwaysApi();
  RadlNaviApi _radlNaviApi = RadlNaviApi();

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

  MapScreenViewModel() {
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

    settingsStore.load().then((data) {
      _applyLoadedSettings(data);
    }).catchError((Object e, StackTrace st) {
      log.e('Failed to load settings', error: e, stackTrace: st);
    });
  }

  void _displayErrorMsg(String msg) {
    _errorMsgsController.add(msg);
  }

  void onMapReady() {
    refreshRadlnetze();
    if (kStoreScreenshots) {
      unawaited(primeLocationForStoreScreenshots());
    }
  }

  /// Requests a fresh GPS fix so Android's cached last-known location is updated.
  /// Failures are logged and ignored so callers can continue either way.
  Future<void> refreshCurrentLocationFix() async {
    try {
      await Geolocator.getCurrentPosition(
        locationSettings: _refreshLocationSettings,
      );
    } catch (e, st) {
      log.d('refreshCurrentLocationFix failed', error: e, stackTrace: st);
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

  Future<void> onPressLocationBtn({bool permissionCheck = true}) async {
    log.d("onPressLocationBtn");
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (permissionCheck && !permissionCheck) {
      log.d("ignore disable location service after return from settings");
      return;
    }

    if (!isLocationServiceEnabled) {
      locationState = LocationState.NOT_AVAILABLE;
      notifyListeners();
      _showEnableLocationServiceDialogController.add("");
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
          await _enterLocationFollowAndCenterCamera();
        } else if (afterRequest == LocationPermission.unableToDetermine) {
          _permissionStreamController.add("");
        }
        break;
      case LocationPermission.deniedForever:
        _permissionStreamController.add("");
        break;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        await _enterLocationFollowAndCenterCamera();
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
      _navigationStarted = true;
      notifyListeners();
      return true;
    }

    if (locationState != LocationState.FOLLOW) {
      await onPressLocationBtn();
    }
    if (locationState == LocationState.FOLLOW) {
      locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
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

  Future<void> refreshRadlnetze() async {
    loading = true;
    notifyListeners();

    try {
      _polylinesGesamtnetz = await _munichwaysApi.getRadlvorrangnetz();
    } catch (e) {
      _displayErrorMsg(e.toString());
      log.e("Error loading Netze", error: e);
    }
    if (_firstLoad) {
      _firstLoad = false;
    }
    loading = false;
    notifyListeners();
  }

  /// Clears the Radnetz GeoJSON cache, then downloads and parses it again so the map
  /// overlay can update without leaving the screen.
  Future<void> reloadRadnetz() async {
    await _munichwaysApi.emptyCache();
    await refreshRadlnetze();
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
    if (locationState == LocationState.FOLLOW) {
      locationState = LocationState.DISPLAY;
    }
    this.destination = place;
    _navigationStarted = false;
    notifyListeners();
    _destinationStreamController.add(place);

    // keep screen on while locating destination is on
    WakelockPlus.enable();

    unawaited(_requestRoute());
  }

  void clearDestination() {
    // Drop any in-flight route so a late response cannot repopulate the map.
    _routeRequest?.cancel();
    _routeRequest = null;
    this.destination = null;
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
    return _requestRoute();
  }

  /// Current RadlNavi request; cancelled when the user ends navigation or starts a new route.
  CancelableOperation<CycleRoute>? _routeRequest = null;

  Future<bool> _requestRoute() async {
    final to = this.destination;
    if (to == null) {
      _displayErrorMsg("Keine Route, da kein Ziel vorhanden");
      return false;
    }

    // Show feedback immediately. Resolving a fresh GPS position can itself take
    // several seconds and is part of the route recalculation from the user's
    // perspective.
    this.route = MapRoute(null, MapRouteState.LOADING);
    notifyListeners();

    // New destination / retry: abandon the previous request.
    await _routeRequest?.cancel();
    if (destination != to) {
      return false;
    }

    final from = await resolveRouteStartPosition();
    if (destination != to) {
      return false;
    }
    if (from == null) {
      _displayErrorMsg(
          "Keine Route, da kein aktueller Standort als Start vorhanden");
      this.route = MapRoute(null, MapRouteState.ERROR);
      notifyListeners();
      return false;
    }

    final request = CancelableOperation<CycleRoute>.fromFuture(
      _radlNaviApi.route([LatLng(from.latitude, from.longitude), to.latLng]),
      onCancel: () => log.d("canceled prev request"),
    );
    _routeRequest = request;

    try {
      final value = await request.valueOrCancellation();
      // User may have cleared the destination while the request was running.
      if (!identical(_routeRequest, request) ||
          destination == null ||
          value == null) {
        return false;
      }
      this.route = MapRoute(value, MapRouteState.SHOWN);
      _routeStreamController.add(this.route);
      notifyListeners();
      return true;
    } catch (e) {
      // Same as success path: ignore errors from superseded/cancelled requests.
      if (!identical(_routeRequest, request) || destination == null) {
        return false;
      }
      _displayErrorMsg("Fehler bei Routensuche $e");
      this.route = MapRoute(null, MapRouteState.ERROR);
      notifyListeners();
      return false;
    }
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
