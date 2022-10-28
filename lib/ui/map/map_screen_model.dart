import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/map/munichways_api.dart';
import 'package:wakelock/wakelock.dart';

class MapScreenViewModel extends ChangeNotifier {
  bool loading = false;

  bool _firstLoad = true;

  double? bearing;

  bool get displayMissingPolylinesMsg {
    return !_firstLoad && (_polylinesGesamtnetz.isEmpty);
  }

  Set<MPolyline> get polylines {
    Set<MPolyline> tempPolylines = _polylinesGesamtnetz
        .where((polyline) =>
            (polyline.isGesamtnetz && _isGesamtnetzVisible) ||
            (polyline.isRadlVorrangNetz && _isRadlvorrangnetzVisible))
        .toSet();
    log.d("Number of polylines: ${tempPolylines.length}");
    return tempPolylines;
  }

  Place? destination = null;

  bool _isRadlvorrangnetzVisible = true;
  bool _isGesamtnetzVisible = false;

  bool get isRadlvorrangnetzVisible {
    return _isRadlvorrangnetzVisible;
  }

  bool get isGesamtnetzVisible {
    return _isGesamtnetzVisible;
  }

  LocationState locationState = LocationState.NOT_AVAILABLE;

  Set<MPolyline> _polylinesGesamtnetz = {};

  MunichwaysApi _munichwaysApi = MunichwaysApi();

  late Stream<String> errorMsgs;
  late StreamController<String> _errorMsgsController;

  late Stream showLocationPermissionDialog;
  late StreamController _permissionStreamController;

  late Stream showEnableLocationServiceDialog;
  late StreamController _showEnableLocationServiceDialogController;

  late Stream showStreetDetails;
  late StreamController showStreetDetailsController;

  late Stream<LatLng> currentLocationStream;
  late StreamController<LatLng> currentLocationController;

  late Stream<Place> destinationStream;
  late StreamController<Place> _destinationStreamController;

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
    currentLocationController = StreamController();
    currentLocationStream = currentLocationController.stream;
    _destinationStreamController = StreamController();
    destinationStream = _destinationStreamController.stream;
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
        locationState = LocationState.FOLLOW;
        notifyListeners();
        Position? position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          currentLocationController
              .add(LatLng(position.latitude, position.longitude));
        }
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
      log.e("Error loading Netze", e);
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
    if (locationState == LocationState.FOLLOW && hasGesture) {
      log.d(locationState);
      locationState = LocationState.DISPLAY;
      log.d(locationState);
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
  }

  void clearDestination() {
    this.destination = null;
    notifyListeners();

    // turn screen off when locating destination is off
    Wakelock.disable();
  }
}

enum LocationState {
  NOT_AVAILABLE, // due to missing permission or support of hardware
  DISPLAY, // display current location on map
  FOLLOW //move map along current location
}
