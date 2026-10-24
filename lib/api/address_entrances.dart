String _key(dynamic value) =>
    (value ?? '').toString().trim().toLowerCase().replaceAll('ß', 'ss');

bool _entrance(dynamic type) =>
    const ['yes', 'home', 'main', 'shop'].contains(type);

bool sameSearchAddress(Map a, Map b) {
  String street(Map p) =>
      _key(p['road'] ?? p['pedestrian'] ?? p['street'] ?? p['place']);
  String city(Map p) =>
      _key(p['city'] ?? p['town'] ?? p['village'] ?? p['municipality']);
  return _key(a['house_number']).isNotEmpty &&
      _key(a['house_number']) == _key(b['house_number']) &&
      street(a).isNotEmpty &&
      street(a) == street(b) &&
      city(a).isNotEmpty &&
      city(a) == city(b) &&
      (_key(a['postcode']).isEmpty ||
          _key(b['postcode']).isEmpty ||
          _key(a['postcode']) == _key(b['postcode']));
}

List<Map<String, dynamic>> addressEntrances(List<dynamic> raw, String query) {
  final places = raw.whereType<Map<String, dynamic>>().map((original) {
    final place = Map<String, dynamic>.from(original);
    final address = Map<String, dynamic>.from(place['address'] as Map? ?? {});
    final numbers = _key(address['house_number']).split(RegExp('[,;]'));
    final tokens = _key(query).split(RegExp(r'[\s,;]+'));
    final requested = numbers.where((n) => tokens.contains(n.trim())).toList();
    if (numbers.length > 1 && requested.length == 1) {
      address['house_number'] = requested.single.trim();
    }
    place['address'] = address;
    return place;
  }).toList();
  bool isEntrance(Map p) =>
      (p['category'] == 'entrance' && _entrance(p['type'])) ||
      _entrance((p['extratags'] as Map?)?['entrance']);
  final resolved = <Map<String, dynamic>>[];
  for (final place in places) {
    final address = place['address'] as Map;
    Map? entrance;
    if (isEntrance(place)) entrance = place;
    for (final candidate in places) {
      if (entrance != null) break;
      if (isEntrance(candidate) &&
          sameSearchAddress(address, candidate['address'] as Map)) {
        entrance = candidate;
      }
    }
    for (final candidate
        in (place['entrances'] as List? ?? const []).whereType<Map>()) {
      if (entrance != null) break;
      if (_key(address['house_number']).isNotEmpty &&
          _entrance(candidate['type']) &&
          _key((candidate['extratags'] as Map?)?['addr:housenumber']) ==
              _key(address['house_number'])) {
        entrance = candidate;
      }
    }
    resolved.add({
      ...place,
      if (entrance != null) ...{
        'lat': entrance['lat'],
        'lon': entrance['lon'],
        '_routing_entrance': true,
      }
    });
  }
  return resolved;
}
