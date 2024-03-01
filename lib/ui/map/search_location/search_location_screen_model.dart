import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:munich_ways/api/nominatim_api.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';

const MAX_NUMBER_STORED_RECENT_SEARCHES = 50;

class SearchLocationScreenViewModel extends ChangeNotifier {
  bool loading = false;

  bool isFirstSearch = true;

  List<Place> places = [];

  NominatimApi api = NominatimApi();

  String? errorMsg = null;

  List<Place> recentSearches = [];

  RecentSearchesStore recentSearchesRepo;

  SearchLocationScreenViewModel({required this.recentSearchesRepo}) {
    recentSearchesRepo.load().then((loadedPlaces) {
      recentSearches = loadedPlaces;
      notifyListeners();
    });
  }

  Future<void> startSearch(String query) async {
    isFirstSearch = false;
    log.d("startSearch " + query);
    clearErrorMsg();

    if (query.isEmpty) {
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

  void addToRecentSearches(Place place) {
    int index = recentSearches
        .indexWhere((element) => element.displayName == place.displayName);
    if (index > -1) {
      recentSearches.removeAt(index);
    }
    recentSearches.insert(0, place);
    recentSearches = recentSearches.sublist(
        0, min(recentSearches.length, MAX_NUMBER_STORED_RECENT_SEARCHES));
    recentSearchesRepo.store(recentSearches);
    notifyListeners();
  }

  void clearAllRecentSearches() {
    recentSearches.clear();
    recentSearchesRepo.store(recentSearches);
    notifyListeners();
  }
}
