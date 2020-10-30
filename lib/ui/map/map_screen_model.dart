import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/map/geojson_converter.dart';
import 'package:munich_ways/ui/map/munichways_api.dart';

class MapScreenViewModel extends ChangeNotifier {
  bool loading = false;

  bool firstLoad = true;

  bool get displayMissingPolylinesMsg {
    return !firstLoad &&
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

  bool currentLocationVisible = false;

  Set<MPolyline> _polylinesVorrangnetz = {};
  Set<MPolyline> _polylinesGesamtnetz = {};

  MunichwaysApi _netzRepo = MunichwaysApi();

  Stream<String> errorMsgs;
  StreamController<String> _errorMsgsController;

  Stream showLocationPermissionDialog;
  StreamController _permissionStreamController;

  Stream showStreetDetails;
  StreamController showStreetDetailsController;

  MapScreenViewModel() {
    _errorMsgsController = StreamController();
    errorMsgs = _errorMsgsController.stream;
    _permissionStreamController = StreamController();
    showLocationPermissionDialog = _permissionStreamController.stream;
    showStreetDetailsController = StreamController();
    showStreetDetails = showStreetDetailsController.stream;
  }

  void _displayErrorMsg(String msg) {
    _errorMsgsController.add(msg);
  }

  void onMapCreated() {
    refreshRadlnetze();
    displayCurrentLocation();
  }

  Future<void> displayCurrentLocation({bool permissionCheck = true}) async {
    LocationPermission permission = await checkPermission();
    log.d(permission);
    if (!permissionCheck &&
        (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever)) {
      log.d("ignore missing permission");
      return;
    }
    switch (permission) {
      case LocationPermission.denied:
        permission = await requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          currentLocationVisible = false;
          _displayErrorMsg("Standort Berechtigung fehlt.");
          return;
        }
        break;
      case LocationPermission.deniedForever:
        _permissionStreamController.add("");
        break;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        currentLocationVisible = true;
        Position position = await getLastKnownPosition();
        if (position != null) {
          position =
              await getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        }
        if (position != null) {
          //TODO move to position
/*          mapController.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(
                  zoom: await mapController.getZoomLevel(),
                  target: LatLng(position.latitude, position.longitude))));*/
          notifyListeners();
        } else {
          _displayErrorMsg("Aktuelle Position konnte nicht bestimmt werden");
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
    } catch (e) {
      _displayErrorMsg(e.toString());
      log.e("Error loading Netze", e);
    }
    if (firstLoad) {
      firstLoad = false;
    }
    loading = false;
    notifyListeners();
  }

  void onTap(StreetDetails details) {
    log.d(details);
    showStreetDetailsController.add(details);
  }
}
