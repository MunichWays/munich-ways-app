import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/place.dart';

/// Offline examples for #217. Addresses confirmed on the operators' websites;
/// OSM nodes/coordinates checked via the app's Nominatim proxy on 2026-10-09.
const exampleDestinations = [
  (
    name: 'Green City e.V.',
    address: 'Lindwurmstraße 88, 80337 München',
    location: LatLng(48.1250808, 11.5485480),
    website: 'https://www.greencity.de/',
    osmId: '1028507760',
    tags: {'office': 'ngo'},
  ),
  (
    name: 'Unlock Escape',
    address: 'Westenriederstraße 41, 80331 München',
    location: LatLng(48.1351713, 11.5799821),
    website: 'https://unlock-escape.de/',
    osmId: '12163409668',
    tags: {'leisure': 'escape_game'},
  ),
];

List<Place> initialExamplePlaces() => [
      for (final example in exampleDestinations)
        Place(example.name, example.location),
    ];

Map<String, dynamic> examplePlacesGeoJson() => {
      'type': 'FeatureCollection',
      'features': [
        for (final example in exampleDestinations)
          {
            'type': 'Feature',
            'id': example.osmId,
            'geometry': {
              'type': 'Point',
              'coordinates': [
                example.location.longitude,
                example.location.latitude,
              ],
            },
            'properties': {
              ...example.tags,
              'name': example.name,
              'address': example.address,
              'website': example.website,
              'osm_type': 'node',
              'osm_id': example.osmId,
            },
          },
      ],
    };
