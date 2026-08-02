import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/geoapify_api.dart';
import 'package:munich_ways/api/munich_street_corrector.dart';
import 'package:munich_ways/api/nominatim_api.dart';
import 'package:munich_ways/api/recent_searches_store.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/model/place.dart';

const maxNumberStoredRecentSearches = 25;

class PlaceSearchScreenViewModel extends ChangeNotifier {
  bool loading = false;

  bool isFirstSearch = true;

  List<Place> places = [];

  GeoapifyApi api;
  NominatimApi fallbackApi;
  MunichStreetCorrector streetCorrector;
  bool resultsFromNominatim = false;
  final LatLng? searchCenter;

  String? errorMsg = null;

  List<Place> recentSearches = [];
  List<Place> favoritePlaces = [];
  String? correctedQuery;

  RecentSearchesStore recentSearchesRepo;
  RecentSearchesStore favoritesRepo;
  int _searchSequence = 0;
  bool _disposed = false;

  PlaceSearchScreenViewModel({
    required this.recentSearchesRepo,
    RecentSearchesStore? favoritesRepo,
    GeoapifyApi? api,
    NominatimApi? fallbackApi,
    MunichStreetCorrector? streetCorrector,
    this.searchCenter,
  })  : favoritesRepo = favoritesRepo ?? favoritePlacesRepo,
        api = api ?? GeoapifyApi(),
        fallbackApi = fallbackApi ?? NominatimApi(),
        streetCorrector = streetCorrector ?? MunichStreetCorrector() {
    recentSearchesRepo.load().then(
      (loadedPlaces) {
        if (_disposed) return;
        recentSearches = loadedPlaces;
        _notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        log.w(
          'Loading recent searches failed',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    this.favoritesRepo.load().then(
      (loadedPlaces) {
        if (_disposed) return;
        favoritePlaces = loadedPlaces.take(3).toList();
        _notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        log.w(
          'Loading favorite places failed',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _searchSequence++;
    super.dispose();
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
    _notifyListeners();

    try {
      var newPlaces = await _searchProviders(query);
      MunichStreetCorrection? correction;
      if (newPlaces.isEmpty) {
        correction = await streetCorrector.correct(query);
        if (correction != null && correction.query != query) {
          newPlaces = await _searchProviders(correction.query);
        }
      }
      if (searchSequence != _searchSequence) {
        return;
      }
      places = newPlaces;
      correctedQuery =
          correction?.query == query ? null : correction?.displayName;
      _notifyListeners();
    } catch (e) {
      if (searchSequence != _searchSequence) {
        return;
      }
      _displayErrorMsg(
          "Fehler bei Straßensuche. Bitte versuche es erneut.\n\n${e.toString()}");
    } finally {
      if (searchSequence == _searchSequence) {
        loading = false;
        _notifyListeners();
      }
    }
  }

  Future<List<Place>> _searchProviders(String query) async {
    try {
      final result = await api.search(
        query,
        searchCenter: searchCenter,
      );
      if (result.isNotEmpty) {
        resultsFromNominatim = false;
        return result;
      }
      log.d('Geoapify returned no places, trying Nominatim fallback');
    } catch (error, stackTrace) {
      log.w(
        'Geoapify search failed, trying Nominatim fallback',
        error: error,
        stackTrace: stackTrace,
      );
    }
    final result = await fallbackApi.search(
      query,
      searchCenter: searchCenter,
    );
    resultsFromNominatim = true;
    return result;
  }

  void _displayErrorMsg(String msg) {
    errorMsg = msg;
    _notifyListeners();
  }

  void clearErrorMsg() {
    errorMsg = null;
    _notifyListeners();
  }

  void resetSearch() {
    _searchSequence++;
    loading = false;
    isFirstSearch = true;
    places = [];
    correctedQuery = null;
    errorMsg = null;
    _notifyListeners();
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
    _notifyListeners();
  }

  bool isFavorite(Place place) => favoritePlaces.any(
        (favorite) =>
            favorite.latLng.latitude == place.latLng.latitude &&
            favorite.latLng.longitude == place.latLng.longitude,
      );

  Future<bool> toggleFavorite(Place place) async {
    final index = favoritePlaces.indexWhere(
      (favorite) =>
          favorite.latLng.latitude == place.latLng.latitude &&
          favorite.latLng.longitude == place.latLng.longitude,
    );
    if (index >= 0) {
      favoritePlaces.removeAt(index);
    } else {
      if (favoritePlaces.length >= 3) return false;
      favoritePlaces.add(place);
    }
    _notifyListeners();
    await favoritesRepo.store(favoritePlaces);
    return true;
  }

  Future<void> renameFavorite(Place place, String name) async {
    final favoriteIndex = favoritePlaces.indexWhere(
      (favorite) =>
          favorite.latLng.latitude == place.latLng.latitude &&
          favorite.latLng.longitude == place.latLng.longitude,
    );
    if (favoriteIndex < 0) return;
    final renamed = Place(name, place.latLng);
    favoritePlaces[favoriteIndex] = renamed;

    final recentIndex = recentSearches.indexWhere(
      (recent) =>
          recent.latLng.latitude == place.latLng.latitude &&
          recent.latLng.longitude == place.latLng.longitude,
    );
    if (recentIndex >= 0) {
      recentSearches[recentIndex] = renamed;
      await recentSearchesRepo.store(recentSearches);
    }
    _notifyListeners();
    await favoritesRepo.store(favoritePlaces);
  }

  Future<void> renameRecentSearch(Place place, String name) async {
    final recentIndex = recentSearches.indexWhere(
      (recent) =>
          recent.latLng.latitude == place.latLng.latitude &&
          recent.latLng.longitude == place.latLng.longitude,
    );
    if (recentIndex < 0) return;
    final renamed = Place(name, place.latLng);
    recentSearches[recentIndex] = renamed;

    final favoriteIndex = favoritePlaces.indexWhere(
      (favorite) =>
          favorite.latLng.latitude == place.latLng.latitude &&
          favorite.latLng.longitude == place.latLng.longitude,
    );
    if (favoriteIndex >= 0) {
      favoritePlaces[favoriteIndex] = renamed;
      await favoritesRepo.store(favoritePlaces);
    }
    _notifyListeners();
    await recentSearchesRepo.store(recentSearches);
  }

  void clearAllRecentSearches() {
    recentSearches.clear();
    recentSearchesRepo.store(recentSearches);
    _notifyListeners();
  }

  Future<void> deleteSavedPlace(Place place) async {
    recentSearches.removeWhere(
      (recent) =>
          recent.latLng.latitude == place.latLng.latitude &&
          recent.latLng.longitude == place.latLng.longitude,
    );
    favoritePlaces.removeWhere(
      (favorite) =>
          favorite.latLng.latitude == place.latLng.latitude &&
          favorite.latLng.longitude == place.latLng.longitude,
    );
    _notifyListeners();
    await Future.wait([
      recentSearchesRepo.store(recentSearches),
      favoritesRepo.store(favoritePlaces),
    ]);
  }
}
