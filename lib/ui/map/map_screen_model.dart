import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/ui/map/munichways_api.dart';

class MapScreenViewModel extends ChangeNotifier {
  Set<Polyline> get polylines {
    Set<Polyline> tempPolylines = {};
    if(_isRadlvorrangnetzVisible){
      tempPolylines.addAll(_polylines_vorrangnetz);
    }
    if(_isGesamtnetzVisible){
      tempPolylines.addAll(_polylines_gesamtnetz);
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

  void toggleGesamtnetzVisible(){
    _isGesamtnetzVisible = !_isGesamtnetzVisible;
    notifyListeners();
  }

  void toggleRadvorrangnetzVisible(){
    _isRadlvorrangnetzVisible = !_isRadlvorrangnetzVisible;
    notifyListeners();
  }

  Set<Polyline> _polylines_vorrangnetz;
  Set<Polyline> _polylines_gesamtnetz;

  MunichwaysApi netzRepo = MunichwaysApi();

  MapScreenViewModel() {
    refreshVorrangnetz();
    refreshGesamtznetz();
  }

  Future<void> refreshVorrangnetz() async {
    log.d('refreshVorrangnetz');
    _polylines_vorrangnetz = await netzRepo.getRadlvorrangnetz();
    notifyListeners();
  }

  Future<void> refreshGesamtznetz() async {
    log.d('refreshGesamtnetz');
    _polylines_gesamtnetz = await netzRepo.getGesamtnetz();
    notifyListeners();
  }
}