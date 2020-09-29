import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/ui/map/geojson_converter.dart';
import 'package:munich_ways/ui/map/munichways_api.dart';
import 'package:munich_ways/ui/map/street_details.dart';

class MapScreenViewModel extends ChangeNotifier implements OnTapListener {
  GoogleMapController mapController;

  bool loading = false;

  bool firstLoad = true;

  bool get displayMissingPolylinesMsg {
    return !firstLoad &&
        (_polylinesVorrangnetz == null ||
            _polylinesVorrangnetz.isEmpty ||
            _polylinesGesamtnetz == null ||
            _polylinesGesamtnetz.isEmpty);
  }

  Set<Polyline> get polylines {
    Set<Polyline> tempPolylines = {};
    if (_isRadlvorrangnetzVisible) {
      tempPolylines.addAll(_polylinesVorrangnetz);
    }
    if (_isGesamtnetzVisible) {
      tempPolylines.addAll(_polylinesGesamtnetz);
    }
    return tempPolylines;
  }

  bool _isRadlvorrangnetzVisible = true;
  bool _isGesamtnetzVisible = false;

  bool get isRadlvorrangnetzVisible {
    return _isRadlvorrangnetzVisible;
  }

  bool get isGesamtnetzVisible {
    return _isGesamtnetzVisible;
  }

  bool currentLocationVisible = false;

  Set<Polyline> _polylinesVorrangnetz = {};
  Set<Polyline> _polylinesGesamtnetz = {};

  MunichwaysApi netzRepo = MunichwaysApi();

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

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
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
        mapController.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
                zoom: await mapController.getZoomLevel(),
                target: LatLng(position.latitude, position.longitude))));
        notifyListeners();
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
      _polylinesVorrangnetz = await netzRepo.getRadlvorrangnetz(this);
      _polylinesGesamtnetz = await netzRepo.getGesamtnetz(this);
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

  @override
  void onTap(feature) {
    log.d(feature['properties']);
    showStreetDetailsController.add(StreetDetails.fromJson(feature));
  }
}
