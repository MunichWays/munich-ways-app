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
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Which horizontal edge the map side control column is pinned to.
enum MapSidePanelEdge {
  left,
  right,
}

class MapScreenViewModel extends ChangeNotifier {
  bool loading = false;

  bool _firstLoad = true;

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
    onPressLocationBtn();
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
        permission = await Geolocator.requestPermission();
        log.d(permission);
        if (permission == LocationPermission.denied) {
          locationState = LocationState.NOT_AVAILABLE;
          _displayErrorMsg("Standort Berechtigung fehlt.");
        } else if (permission == LocationPermission.deniedForever) {
          _permissionStreamController.add("");
        }
        break;
      case LocationPermission.deniedForever:
        _permissionStreamController.add("");
        break;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        if (locationState == LocationState.FOLLOW) {
          locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
        } else {
          locationState = LocationState.FOLLOW;
        }
        notifyListeners();
        Position? position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          currentLocationBtnClickedController
              .add(LatLng(position.latitude, position.longitude));
        }
        break;
      case LocationPermission.unableToDetermine:
        _permissionStreamController.add("");
        break;
    }
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
      notifyListeners();
    }
  }

  /// MapLibre: call from [MapLibreMap.onCameraTrackingDismissed] when the user
  /// breaks location follow / compass tracking.
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
    notifyListeners();
    _destinationStreamController.add(place);

    // keep screen on while locating destination is on
    WakelockPlus.enable();

    _requestRoute();
  }

  void clearDestination() {
    // Drop any in-flight route so a late response cannot repopulate the map.
    _routeRequest?.cancel();
    _routeRequest = null;
    this.destination = null;
    notifyListeners();

    // turn screen off when locating destination is off
    WakelockPlus.disable();

    _clearRoute();
  }

  /// Current RadlNavi request; cancelled when the user ends navigation or starts a new route.
  CancelableOperation<CycleRoute>? _routeRequest = null;

  void _requestRoute() async {
    Position? from = await Geolocator.getLastKnownPosition();
    if (from == null) {
      _displayErrorMsg(
          "Keine Route, da kein aktueller Standort als Start vorhanden");
      return;
    }
    final to = this.destination;
    if (to == null) {
      _displayErrorMsg("Keine Route, da kein Ziel vorhanden");
      return;
    }

    _routeRequest
        ?.cancel(); // New destination / retry: abandon previous request.
    this.route = MapRoute(null, MapRouteState.LOADING);
    notifyListeners();
    _routeRequest = CancelableOperation<CycleRoute>.fromFuture(
        _radlNaviApi.route([LatLng(from.latitude, from.longitude), to.latLng]),
        onCancel: () => {log.d("canceled prev request")});
    _routeRequest?.value.then((value) {
      // User may have cleared the destination while the request was running.
      if (destination == null) {
        return;
      }
      this.route = MapRoute(value, MapRouteState.SHOWN);
      _routeStreamController.add(this.route);
      notifyListeners();
    }).catchError((e) {
      // Same as success path: ignore errors from superseded/cancelled requests.
      if (destination == null) {
        return;
      }
      _displayErrorMsg("Fehler bei Routensuche $e");
      this.route = MapRoute(null, MapRouteState.ERROR);
      notifyListeners();
    });
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
