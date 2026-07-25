import 'package:flutter/services.dart';

class MunichStreetCorrection {
  const MunichStreetCorrection({
    required this.query,
    required this.displayName,
  });

  final String query;
  final String displayName;
}

class MunichStreetCorrector {
  static const _assetPath = 'assets/search/munich_streets.txt';

  MunichStreetCorrector({AssetBundle? bundle})
      : _streetNames = _loadStreetNames(bundle ?? rootBundle);

  MunichStreetCorrector.fromStreetNames(Iterable<String> streetNames)
      : _streetNames = Future.value(streetNames.toList());

  final Future<List<String>> _streetNames;

  static Future<List<String>> _loadStreetNames(AssetBundle bundle) async {
    final content = await bundle.loadString(_assetPath);
    return content
        .split(RegExp(r'\r?\n'))
        .map((street) => street.trim())
        .where((street) => street.isNotEmpty)
        .toList();
  }

  Future<MunichStreetCorrection?> correct(String query) async {
    final comparableQuery = _comparableQuery(query);
    if (comparableQuery.length < 5) {
      return null;
    }

    final maximumDistance = comparableQuery.length >= 9 ? 2 : 1;
    String? bestStreet;
    var bestDistance = maximumDistance + 1;
    var bestIsAmbiguous = false;

    for (final street in await _streetNames) {
      final candidate = _normalizeStreet(street);
      if ((candidate.length - comparableQuery.length).abs() > maximumDistance) {
        continue;
      }
      final distance = _damerauLevenshtein(
        comparableQuery,
        candidate,
        maximumDistance,
      );
      if (distance < bestDistance) {
        bestStreet = street;
        bestDistance = distance;
        bestIsAmbiguous = false;
      } else if (distance == bestDistance && candidate != comparableQuery) {
        bestIsAmbiguous = true;
      }
    }

    if (bestStreet == null ||
        bestDistance > maximumDistance ||
        bestIsAmbiguous) {
      return null;
    }

    final displayName = _expandedStreetName(bestStreet);
    if (bestDistance == 0) {
      return MunichStreetCorrection(query: query, displayName: displayName);
    }

    final houseNumber =
        RegExp(r'\b\d+\s*[a-zA-Z]?\b').firstMatch(query)?.group(0);
    final correctedQuery = [
      bestStreet,
      if (houseNumber != null) houseNumber,
      'München',
    ].join(', ');
    return MunichStreetCorrection(
      query: correctedQuery,
      displayName: displayName,
    );
  }

  static String _comparableQuery(String query) {
    var normalized = _normalize(query);
    normalized = normalized
        .replaceAll(RegExp(r'\b(muenchen|munchen|bayern|deutschland)\b'), '')
        .replaceAll(RegExp(r'\b\d+\s*[a-z]?\b'), '')
        .trim();
    return _expandSuffix(normalized).replaceAll(' ', '');
  }

  static String _normalizeStreet(String street) =>
      _expandSuffix(_normalize(street)).replaceAll(' ', '');

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _expandSuffix(String value) => value
      .replaceFirst(RegExp(r'str$'), 'strasse')
      .replaceFirst(RegExp(r'pl$'), 'platz');

  static String _expandedStreetName(String street) {
    if (street.endsWith('str.')) {
      return '${street.substring(0, street.length - 4)}straße';
    }
    if (street.endsWith(' Str.')) {
      return '${street.substring(0, street.length - 4)} Straße';
    }
    if (street.endsWith('pl.')) {
      return '${street.substring(0, street.length - 3)}platz';
    }
    return street;
  }

  static int _damerauLevenshtein(
    String source,
    String target,
    int maximumDistance,
  ) {
    var previousPrevious = <int>[];
    var previous = List<int>.generate(target.length + 1, (index) => index);

    for (var sourceIndex = 1;
        sourceIndex <= source.length;
        sourceIndex++) {
      final current = List<int>.filled(target.length + 1, 0);
      current[0] = sourceIndex;

      for (var targetIndex = 1;
          targetIndex <= target.length;
          targetIndex++) {
        final substitutionCost =
            source[sourceIndex - 1] == target[targetIndex - 1] ? 0 : 1;
        current[targetIndex] = _minimum(
          current[targetIndex - 1] + 1,
          previous[targetIndex] + 1,
          previous[targetIndex - 1] + substitutionCost,
        );

        if (sourceIndex > 1 &&
            targetIndex > 1 &&
            source[sourceIndex - 1] == target[targetIndex - 2] &&
            source[sourceIndex - 2] == target[targetIndex - 1]) {
          current[targetIndex] = current[targetIndex] <
                  previousPrevious[targetIndex - 2] + 1
              ? current[targetIndex]
              : previousPrevious[targetIndex - 2] + 1;
        }
      }

      previousPrevious = previous;
      previous = current;
    }
    return previous[target.length];
  }

  static int _minimum(int first, int second, int third) {
    var result = first < second ? first : second;
    result = result < third ? result : third;
    return result;
  }
}
