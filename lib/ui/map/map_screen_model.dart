import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong/latlong.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/polyline.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/map/munichways_api.dart';

class MapScreenViewModel extends ChangeNotifier {
  bool loading = false;

  bool _firstLoad = true;

  bool get displayMissingPolylinesMsg {
    return !_firstLoad &&
        (_polylinesVorrangnetz == null ||
            _polylinesVorrangnetz.isEmpty ||
            _polylinesGesamtnetz == null ||
            _polylinesGesamtnetz.isEmpty);
  }

  Set<MPolyline> get polylines {
    Set<MPolyline> tempPolylines = {};
    if (_isRadlvorrangnetzVisible) {
      tempPolylines.addAll(_polylinesVorrangnetz);
    }
    if (_isGesamtnetzVisible) {
      tempPolylines.addAll(_polylinesGesamtnetz);
    }
    log.d("Number of polylines: ${tempPolylines.length}");
    return tempPolylines;
  }

  bool _isRadlvorrangnetzVisible = true;
  bool _isGesamtnetzVisible = true;

  bool get isRadlvorrangnetzVisible {
    return _isRadlvorrangnetzVisible;
  }

  bool get isGesamtnetzVisible {
    return _isGesamtnetzVisible;
  }

  LocationState locationState = LocationState.NOT_AVAILABLE;

  Set<MPolyline> _polylinesVorrangnetz = {};
  Set<MPolyline> _polylinesGesamtnetz = {};

  MunichwaysApi _netzRepo = MunichwaysApi();

  Stream<String> errorMsgs;
  StreamController<String> _errorMsgsController;

  Stream showLocationPermissionDialog;
  StreamController _permissionStreamController;

  Stream showStreetDetails;
  StreamController showStreetDetailsController;

  Stream<LatLng> currentLocationStream;
  StreamController<LatLng> currentLocationController;

  MapScreenViewModel() {
    _errorMsgsController = StreamController();
    errorMsgs = _errorMsgsController.stream;
    _permissionStreamController = StreamController();
    showLocationPermissionDialog = _permissionStreamController.stream;
    showStreetDetailsController = StreamController();
    showStreetDetails = showStreetDetailsController.stream;
    currentLocationController = StreamController();
    currentLocationStream = currentLocationController.stream;
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
        Position position = await Geolocator.getLastKnownPosition();
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
      _polylinesVorrangnetz = await _netzRepo.getRadlvorrangnetz();
      _polylinesGesamtnetz = await _netzRepo.getGesamtnetz();
      _polylinesGesamtnetz.forEach((e) {
        e.isGesamtnetz = true;
      });
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

  void onTap(StreetDetails details) {
    log.d(details);
    showStreetDetailsController.add(details);
  }

  void onMapPositionChanged(MapPosition position, bool hasGesture) {
    if (locationState == LocationState.FOLLOW && hasGesture) {
      log.d(locationState);
      locationState = LocationState.DISPLAY;
      log.d(locationState);
      notifyListeners();
    }
  }
}

enum LocationState {
  NOT_AVAILABLE, // due to missing permission or support of hardware
  DISPLAY, // display current location on map
  FOLLOW //move map along current location
}
