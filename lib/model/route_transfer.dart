import 'dart:convert';
import 'package:munich_ways/model/gpx_import_exception.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import 'package:munich_ways/api/radlnavi_api.dart';
import 'package:munich_ways/model/place.dart';
import 'package:munich_ways/model/route.dart';

class RouteTransfer {
  static const namespace = 'https://www.munichways.de/gpx/1';
  static const maxBytes = 4 * 1024 * 1024;
  static const maxStops = 50;
  static const gpxNamespace = 'http://www.topografix.com/GPX/1/1';
  final String name;
  final List<Place> plan;
  final CycleRoute route;
  final Map<String, dynamic>? native;
  RouteTransfer._(this.name, this.plan, this.route, this.native);
  bool get hasNavigation => native != null;

  static String gpxFilename(String name) {
    final clean = name
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '')
        .replaceAll(RegExp(r'\.gpx$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[. ]+$'), '');
    final reserved = RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
            caseSensitive: false)
        .hasMatch(clean);
    return '${clean.isEmpty || reserved ? 'MunichWays-Route' : clean}.gpx';
  }

  static bool _point(Object? p) =>
      p is List &&
      p.length == 2 &&
      p.every((v) => v is num && v.isFinite) &&
      (p[0] as num).abs() <= 180 &&
      (p[1] as num).abs() <= 90;
  static void _require(bool condition) {
    if (!condition) throw const FormatException('Invalid route transfer');
  }

  static RouteTransfer fromJson(Map<String, dynamic> value) {
    try {
      _require(utf8.encode(jsonEncode(value)).length <= maxBytes);
      _require(value['version'] == 1 &&
          value['provider'] == 'radlnavi' &&
          const ['standard', 'direct'].contains(value['variant']));
      final name = value['name'];
      _require(name is String && name.trim().isNotEmpty && name.length <= 200);
      _require(value['createdAt'] is String &&
          DateTime.tryParse(value['createdAt']) != null);
      final plan = value['plan'];
      _require(plan is List && plan.length >= 2 && plan.length <= maxStops + 2);
      final places = <Place>[];
      for (final p in plan) {
        _require(p is Map &&
            p['name'] is String &&
            (p['name'] as String).length <= 500 &&
            _point(p['coordinates']));
        places.add(Place(
            p['name'],
            LatLng((p['coordinates'][1] as num).toDouble(),
                (p['coordinates'][0] as num).toDouble())));
      }
      final response = value['response'];
      _require(response is Map &&
          response['code'] == 'Ok' &&
          response['routes'] is List &&
          response['routes'].length == 1);
      final raw = response['routes'][0];
      final geometry = raw['geometry'];
      _require(geometry is Map &&
          geometry['type'] == 'LineString' &&
          geometry['coordinates'] is List);
      final points = geometry['coordinates'] as List;
      _require(points.length >= 2 &&
          points.length <= 100000 &&
          points.every(_point));
      for (final key in ['distance', 'duration']) {
        _require(
            raw[key] is num && (raw[key] as num).isFinite && raw[key] >= 0);
      }
      final legs = raw['legs'];
      _require(legs is List && legs.length == places.length - 1);
      for (final leg in legs) {
        final steps = leg['steps'];
        _require(steps is List && steps.length >= 2 && steps.length <= 100000);
        _require(steps.first['maneuver']['type'] == 'depart' &&
            steps.last['maneuver']['type'] == 'arrive');
        for (final step in steps) {
          _require(_point(step['maneuver']['location']) &&
              step['maneuver']['type'] is String &&
              step['mode'] is String);
          for (final key in ['distance', 'duration']) {
            _require(step[key] is num &&
                (step[key] as num).isFinite &&
                step[key] >= 0);
          }
          _require(step['geometry']['type'] == 'LineString' &&
              step['geometry']['coordinates'] is List &&
              step['geometry']['coordinates'].isNotEmpty &&
              step['geometry']['coordinates'].every(_point));
        }
      }
      List<dynamic> distinct(List<dynamic> coords) {
        final result = <dynamic>[];
        for (final point in coords) {
          if (result.isEmpty ||
              result.last[0] != point[0] ||
              result.last[1] != point[1]) result.add(point);
        }
        return result;
      }

      final joined = <dynamic>[];
      for (final leg in legs) {
        for (final step in leg['steps']) {
          if (step['maneuver']['type'] != 'arrive')
            joined.addAll(step['geometry']['coordinates']);
        }
      }
      final expected = distinct(points), actual = distinct(joined);
      _require(expected.length == actual.length);
      for (var i = 0; i < expected.length; i++) {
        _require(
            expected[i][0] == actual[i][0] && expected[i][1] == actual[i][1]);
      }
      final route = RadlNaviApi(variant: value['variant']).parseResponse(
          Map<String, dynamic>.from(response),
          places.map((p) => p.latLng).toList());
      return RouteTransfer._(name, List.unmodifiable(places), route, value);
    } catch (_) {
      throw const FormatException('Invalid or unsupported MunichWays route');
    }
  }

  static RouteTransfer fromGpx(String source) {
    if (utf8.encode(source).length > maxBytes)
      throw const GpxImportException(GpxImportIssue.tooLarge);
    if (RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(source))
      throw const GpxImportException(GpxImportIssue.invalidXml);
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(source);
    } on XmlParserException {
      throw const GpxImportException(GpxImportIssue.invalidXml);
    }
    final root = doc.rootElement;
    if (!(root.name.local == 'gpx' &&
        root.namespaceUri == gpxNamespace &&
        root.getAttribute('version') == '1.1'))
      throw const GpxImportException(GpxImportIssue.unsupportedVersion);
    final native = root.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'route' && e.namespaceUri == namespace)
        .toList();
    final tracks = root.childElements
        .where((e) => e.name.local == 'trk' && e.namespaceUri == gpxNamespace)
        .toList();
    if (tracks.length != 1)
      throw GpxImportException(GpxImportIssue.trackCount, count: tracks.length);
    final segments = tracks.single.childElements
        .where(
          (e) => e.name.local == 'trkseg' && e.namespaceUri == gpxNamespace,
        )
        .toList();
    if (segments.length != 1)
      throw GpxImportException(
        GpxImportIssue.segmentCount,
        count: segments.length,
      );
    final points = <LatLng>[];
    for (final element in segments.single.childElements.where(
      (e) => e.name.local == 'trkpt' && e.namespaceUri == gpxNamespace,
    )) {
      final lat = double.tryParse(element.getAttribute('lat') ?? '');
      final lon = double.tryParse(element.getAttribute('lon') ?? '');
      if (lat == null || lon == null || !_point([lon, lat]))
        throw const GpxImportException(GpxImportIssue.invalidCoordinates);
      points.add(LatLng(lat, lon));
      if (points.length > 100000)
        throw const GpxImportException(
          GpxImportIssue.tooManyPoints,
          limit: 100000,
        );
    }
    if (points.length < 2)
      throw const GpxImportException(GpxImportIssue.noTrackPoints);
    if (native.isNotEmpty) {
      _require(native.length == 1);
      final transfer = fromJson(
        jsonDecode(native.single.innerText) as Map<String, dynamic>,
      );
      final raw = transfer.native!['response']['routes'][0]['geometry']
          ['coordinates'] as List;
      _require(raw.length == points.length);
      for (var i = 0; i < raw.length; i++) {
        _require(
          raw[i][0] == points[i].longitude && raw[i][1] == points[i].latitude,
        );
      }
      return transfer;
    }
    // Standard GPX waypoints, including Komoot highlights, in file order.
    final stops = <Place>[];
    for (final element in root.childElements.where(
      (e) => e.name.local == 'wpt' && e.namespaceUri == gpxNamespace,
    )) {
      final lat = double.tryParse(element.getAttribute('lat') ?? '');
      final lon = double.tryParse(element.getAttribute('lon') ?? '');
      if (lat == null || lon == null || !_point([lon, lat]))
        throw const GpxImportException(GpxImportIssue.invalidWaypoint);
      final label = element.childElements
          .where(
            (e) => e.name.local == 'name' && e.namespaceUri == gpxNamespace,
          )
          .firstOrNull
          ?.innerText
          .trim();
      if (label != null && label.length > 500)
        throw const GpxImportException(GpxImportIssue.invalidWaypoint);
      stops.add(
        Place(
          label?.isNotEmpty == true
              ? label!
              : 'Zwischenziel ${stops.length + 1}',
          LatLng(lat, lon),
        ),
      );
      if (stops.length > maxStops)
        throw GpxImportException(
          GpxImportIssue.tooManyStops,
          count: stops.length,
          limit: maxStops,
        );
    }
    final name = tracks.single.childElements
        .where((e) => e.name.local == 'name')
        .firstOrNull
        ?.innerText
        .trim();
    var distance = 0.0;
    for (var i = 1; i < points.length; i++) {
      distance += const Distance().as(
        LengthUnit.Meter,
        points[i - 1],
        points[i],
      );
    }
    return RouteTransfer._(
      name?.isNotEmpty == true ? name! : 'GPX-Track',
      List.unmodifiable([
        Place('Start', points.first),
        ...stops,
        Place('Ziel', points.last),
      ]),
      CycleRoute(points, distance, 0, supportsVoiceGuidance: false),
      null,
    );
  }

  static RouteTransfer fromRoute(
      CycleRoute route, List<Place> plan, String name, String variant) {
    final response = route.transferResponse;
    if (response == null) return RouteTransfer._(name, plan, route, null);
    return fromJson({
      'version': 1,
      'name': name,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'provider': 'radlnavi',
      'variant': variant,
      'plan': plan
          .map((p) => {
                'name': p.displayName ?? '',
                'coordinates': [p.latLng.longitude, p.latLng.latitude],
              })
          .toList(),
      'response': response
    });
  }

  RouteTransfer renamed(String name) => native == null
      ? RouteTransfer._(name, plan, route, null)
      : fromJson({...native!, 'name': name});

  Map<String, dynamic> toStorageJson() =>
      native ??
      {
        'trackName': name,
        'trackPlan': plan
            .map((p) => {
                  'name': p.displayName ?? '',
                  'coordinates': [p.latLng.longitude, p.latLng.latitude],
                })
            .toList(),
        'trackPoints':
            route.points.map((p) => [p.longitude, p.latitude]).toList(),
      };
  static RouteTransfer fromStorageJson(Map<String, dynamic> value) {
    if (!value.containsKey('trackPoints')) return fromJson(value);
    final points = value['trackPoints'] as List;
    _require(
        points.length >= 2 && points.length <= 100000 && points.every(_point));
    final xml = _gpx(value['trackName'] as String, points, null);
    final transfer = fromGpx(xml);
    if (!value.containsKey('trackPlan')) return transfer; // Older saved tracks.
    final plan = value['trackPlan'];
    _require(plan is List && plan.length >= 2 && plan.length <= maxStops + 2);
    final places = <Place>[];
    for (final p in plan) {
      _require(p is Map &&
          p['name'] is String &&
          (p['name'] as String).length <= 500 &&
          _point(p['coordinates']));
      places.add(Place(
          p['name'],
          LatLng((p['coordinates'][1] as num).toDouble(),
              (p['coordinates'][0] as num).toDouble())));
    }
    return RouteTransfer._(
        transfer.name, List.unmodifiable(places), transfer.route, null);
  }

  String toGpx() => _gpx(
      name,
      native?['response']['routes'][0]['geometry']['coordinates'] ??
          route.points.map((p) => [p.longitude, p.latitude]).toList(),
      native,
      plan);

  static String _gpx(String name, List points, Map<String, dynamic>? native,
      [List<Place> plan = const []]) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', nest: () {
      builder.attribute('xmlns', gpxNamespace);
      builder.attribute('xmlns:mw', namespace);
      builder.attribute('version', '1.1');
      builder.attribute('creator', 'MunichWays');
      builder.element('metadata',
          nest: () => builder.element('name', nest: name));
      if (native == null && plan.length >= 2) {
        for (final stop in plan.sublist(1, plan.length - 1)) {
          builder.element('wpt', nest: () {
            builder.attribute('lat', stop.latLng.latitude);
            builder.attribute('lon', stop.latLng.longitude);
            builder.element('name', nest: stop.displayName ?? '');
          });
        }
      }
      builder.element('trk', nest: () {
        builder.element('name', nest: name);
        builder.element('trkseg', nest: () {
          for (final p in points) {
            builder.element('trkpt', nest: () {
              builder.attribute('lat', p[1]);
              builder.attribute('lon', p[0]);
            });
          }
        });
      });
      if (native != null)
        builder.element('extensions',
            nest: () => builder.element('mw:route', nest: jsonEncode(native)));
    });
    final xml = builder.buildDocument().toXmlString();
    if (utf8.encode(xml).length > maxBytes)
      throw const FormatException('GPX exceeds 4 MB');
    return xml;
  }
}
