/// Conservative spelling variants; never remove address numbers or locations.
class PlaceSearchQuery {
  static String normalize(String query) => query
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(
        RegExp(r'([a-zäöüß])([A-ZÄÖÜ])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAllMapped(
        RegExp(r'(\S\s+)e\s*\.?\s*v\.?(?![a-zäöüß])', caseSensitive: false),
        (match) => '${match[1]}e.V.',
      );

  /// One optional retry for a two-word name such as Zürich Horn.
  /// Numbers, punctuation and longer addresses must not be concatenated.
  static String? compoundAlternative(String query) {
    final match =
        RegExp(r'^([a-zäöüß]{3,}) ([a-zäöüß]{3,})$', caseSensitive: false)
            .firstMatch(query);
    return match == null ? null : '${match[1]}${match[2]!.toLowerCase()}';
  }

  /// Only for comparing names, never used as an address sent to a provider.
  static String nameKey(String name) => name
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}
