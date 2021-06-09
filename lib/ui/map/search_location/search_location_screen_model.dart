import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/ui/map/search_location/nominatim_api.dart';

class SearchLocationScreenViewModel extends ChangeNotifier {
  bool loading = false;

  List<Place> places = [];

  NominatimApi api = NominatimApi();

  String errorMsg = null;

  Future<void> startSearch(String query) async {
    log.d("startSearch " + query);
    clearErrorMsg();

    if (query == null || query.isEmpty) {
      _displayErrorMsg(
          "Suchanfrage ist leer.\nBitte gebe ein Suchbegriff z.B. eine Straße in München ein.");
      return;
    }

    loading = true;
    notifyListeners();

    try {
      places = await api.search(query + ", Bayern");
      loading = false;
      notifyListeners();
    } catch (e) {
      _displayErrorMsg(
          "Fehler bei Straßensuche. Bitte versuche es erneut.\n\n${e.toString()}");
    }
  }

  void _displayErrorMsg(String msg) {
    errorMsg = msg;
    notifyListeners();
  }

  void clearErrorMsg() {
    errorMsg = null;
    notifyListeners();
  }
}
