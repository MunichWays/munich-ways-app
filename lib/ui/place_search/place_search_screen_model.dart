import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:munich_ways/api/geoapify_api.dart';
import 'package:munich_ways/api/munich_street_corrector.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';

const maxNumberStoredRecentSearches = 25;

class PlaceSearchScreenViewModel extends ChangeNotifier {
  bool loading = false;

  bool isFirstSearch = true;

  List<Place> places = [];

  GeoapifyApi api;
  MunichStreetCorrector streetCorrector;

  String? errorMsg = null;

  List<Place> recentSearches = [];
  String? correctedQuery;

  RecentSearchesStore recentSearchesRepo;
  int _searchSequence = 0;

  PlaceSearchScreenViewModel({
    required this.recentSearchesRepo,
    GeoapifyApi? api,
    MunichStreetCorrector? streetCorrector,
  })  : api = api ?? GeoapifyApi(),
        streetCorrector = streetCorrector ?? MunichStreetCorrector() {
    recentSearchesRepo.load().then((loadedPlaces) {
      recentSearches = loadedPlaces;
      notifyListeners();
    });
  }

  Future<void> startSearch(String query) async {
    final searchSequence = ++_searchSequence;
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
      final correction = await streetCorrector.correct(query);
      final correctedSearchQuery = correction?.query ?? query;
      final newPlaces = await api.search(correctedSearchQuery);
      if (searchSequence != _searchSequence) {
        return;
      }
      places = newPlaces;
      correctedQuery =
          correction?.query == query ? null : correction?.displayName;
      loading = false;
      notifyListeners();
    } catch (e) {
      if (searchSequence != _searchSequence) {
        return;
      }
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

  void resetSearch() {
    _searchSequence++;
    loading = false;
    isFirstSearch = true;
    places = [];
    correctedQuery = null;
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
        0, min(recentSearches.length, maxNumberStoredRecentSearches));
    recentSearchesRepo.store(recentSearches);
    notifyListeners();
  }

  void clearAllRecentSearches() {
    recentSearches.clear();
    recentSearchesRepo.store(recentSearches);
    notifyListeners();
  }
}
