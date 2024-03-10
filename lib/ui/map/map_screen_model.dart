import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/munichways/munichways_api.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/map/map_action_buttons/route_button_bar.dart';
import 'package:wakelock/wakelock.dart';

class MapScreenViewModel extends ChangeNotifier {
  bool loading = false;

  bool _firstLoad = true;

  double? bearing;

  MapRoute route = MapRoute(null, MapRouteState.NO_ROUTE);

  bool get displayMissingPolylinesMsg {
    return !_firstLoad && (_polylinesGesamtnetz.isEmpty);
  }

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

  late Stream showStreetDetails;
  late StreamController showStreetDetailsController;

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
    showStreetDetailsController = StreamController();
    showStreetDetails = showStreetDetailsController.stream;
    currentLocationBtnClickedController = StreamController();
    currentLocationBtnClickedStream =
        currentLocationBtnClickedController.stream;
    _destinationStreamController = StreamController();
    destinationStream = _destinationStreamController.stream;
    _routeStreamController = StreamController();
    routeStream = _routeStreamController.stream;
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

  void onTap(StreetDetails? details) {
    log.d(details);
    showStreetDetailsController.add(details);
  }

  Future<void> onMapPositionChanged(
      MapPosition position, bool hasGesture) async {
    if (hasGesture &&
        (locationState == LocationState.FOLLOW ||
            locationState == LocationState.FOLLOW_AND_ROTATE_MAP)) {
      locationState = LocationState.DISPLAY;
      notifyListeners();
    }

    if (destination != null) {
      this.bearing = Geolocator.bearingBetween(
          position.center!.latitude,
          position.center!.longitude,
          destination!.latLng.latitude,
          destination!.latLng.longitude);
      this.bearing = (bearing! + 360) % 360;
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
    Wakelock.enable();

    _requestRoute();
  }

  void clearDestination() {
    this.destination = null;
    notifyListeners();

    // turn screen off when locating destination is off
    Wakelock.disable();

    _clearRoute();
  }

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

    _routeRequest?.cancel();
    this.route = MapRoute(null, MapRouteState.LOADING);
    notifyListeners();
    _routeRequest = CancelableOperation<CycleRoute>.fromFuture(
        _radlNaviApi.route([LatLng(from.latitude, from.longitude), to.latLng]),
        onCancel: () => {log.d("canceled prev request")});
    _routeRequest?.value.then((value) {
      this.route = MapRoute(value, MapRouteState.SHOWN);
      _routeStreamController.add(this.route);
      notifyListeners();
    }).catchError((e) {
      _displayErrorMsg("Fehler bei Routensuche $e");
      this.route = MapRoute(null, MapRouteState.ERROR);
      notifyListeners();
    });
  }

  void _clearRoute() {
    this.route = MapRoute(null, MapRouteState.NO_ROUTE);
    notifyListeners();
  }

  void toggleRoute() {
    switch (this.route.state) {
      case MapRouteState.SHOWN:
        {
          this.route = MapRoute(this.route.route, MapRouteState.HIDDEN);
        }
      case MapRouteState.HIDDEN:
        {
          this.route = MapRoute(this.route.route, MapRouteState.SHOWN);
        }
      default:
        {
          //do nothing
        }
    }
    notifyListeners();
  }
}

enum LocationState {
  NOT_AVAILABLE, // due to missing permission or support of hardware
  DISPLAY, // display current location on map
  FOLLOW, //move map along current location
  FOLLOW_AND_ROTATE_MAP //move map along current location and rotate map in direction user is heading
}
