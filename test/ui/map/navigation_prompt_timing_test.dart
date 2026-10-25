import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

// Exact projection distances, independent of live routing and inferred corners.
LatLng _at(double meters) => LatLng(48.14 + meters / 111320, 11.57);

RouteManeuver _turn(double meters, String modifier,
        {String name = 'Erste Straße', RouteWayType? enteringWayType}) =>
    RouteManeuver(
        location: _at(meters),
        type: 'turn',
        modifier: modifier,
        roadName: name,
        wayType: RouteWayType.road,
        enteringWayType: enteringWayType);

CycleRoute _route(List<RouteManeuver> maneuvers) =>
    CycleRoute([_at(0), _at(800)], 800, 240, maneuvers: maneuvers);

void main() {
  for (final english in [false, true]) {
    test('late automatic approach waits for the immediate turn ($english)', () {
      final guidance = VoiceGuidance()..setRoute(_route([_turn(100, 'right')]));
      expect(guidance.update(_at(61), english: english), isNull);
      expect(
          guidance.announceCurrentManeuver(_at(70), english: english), isNull);
      expect(guidance.update(_at(80), english: english), isNull);
      expect(guidance.display(_at(80), english: english)?.text,
          'In 20 m ${english ? 'right' : 'rechts'}');
      expect(
          guidance.update(_at(88), english: english),
          english
              ? 'Turn right, onto Erste Straße here.'
              : 'Hier rechts abbiegen, in Erste Straße.');
      expect(guidance.update(_at(90), english: english), isNull);
    });

    test(
        '40 metres still permits one approach and one immediate turn ($english)',
        () {
      final guidance = VoiceGuidance()..setRoute(_route([_turn(100, 'right')]));
      expect(
          guidance.update(_at(60), english: english),
          english
              ? 'In 40 meters, turn right, onto Erste Straße.'
              : 'In 40 Metern rechts abbiegen, in Erste Straße.');
      expect(guidance.update(_at(70), english: english), isNull);
      expect(guidance.update(_at(88), english: english),
          contains(english ? 'here' : 'Hier'));
    });

    test('explicit speaker repeat stays useful with little lead ($english)',
        () {
      final guidance = VoiceGuidance()..setRoute(_route([_turn(100, 'right')]));
      expect(
          guidance.announceCurrentManeuver(_at(70),
              english: english, repeat: true),
          english ? 'In 30 meters, turn right.' : 'In 30 Metern rechts.');
      expect(guidance.update(_at(72), english: english), isNull);
      expect(guidance.update(_at(88), english: english),
          contains(english ? 'here' : 'Hier'));
    });

    test('speed lookahead also suppresses a late approach ($english)', () {
      final guidance = VoiceGuidance()..setRoute(_route([_turn(100, 'right')]));
      const speed = 30 / 3.6;
      expect(
          guidance.update(_at(50),
              english: english, speedMetersPerSecond: speed),
          isNull);
      expect(
          guidance.update(_at(65),
              english: english, speedMetersPerSecond: speed),
          contains(english ? 'here' : 'Hier'));
    });

    test('close pair is short; the second turn can name its road ($english)',
        () {
      final guidance = VoiceGuidance()
        ..setRoute(_route([
          _turn(100, 'right'),
          _turn(122, 'left', name: 'Schloßschmidstraße'),
        ]));
      expect(
          guidance.update(_at(41), english: english),
          english
              ? 'In 60 meters, turn right, then immediately turn left.'
              : 'In 60 Metern rechts, danach sofort links.');
      expect(
          guidance.update(_at(90), english: english),
          english
              ? 'Turn right here, then immediately turn left.'
              : 'Hier rechts, danach sofort links.');
      expect(
          guidance.update(_at(126), english: english),
          english
              ? 'Turn left, onto Schloßschmidstraße here.'
              : 'Hier links abbiegen, in Schloßschmidstraße.');
      expect(guidance.update(_at(130), english: english), isNull);
    });
  }

  test('third close turn keeps the middle instruction short too', () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([
        _turn(100, 'right'),
        _turn(122, 'left', name: 'Zweite Straße'),
        _turn(148, 'sharp right', name: 'Dritte Straße'),
      ]));
    expect(guidance.update(_at(90), english: false),
        'Hier rechts, danach sofort links.');
    expect(guidance.update(_at(126), english: false),
        'Hier links, danach sofort scharf rechts.');
    expect(guidance.update(_at(151), english: false),
        'Hier scharf rechts abbiegen, in Dritte Straße.');
  });

  test('compact pair retains slight/sharp directions and way changes', () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([
        _turn(100, 'sharp right', enteringWayType: RouteWayType.cycleway),
        _turn(122, 'slight left', enteringWayType: RouteWayType.road),
      ]));
    expect(guidance.update(_at(90), english: false),
        'Hier scharf rechts, auf Radweg, danach sofort leicht links, auf Straße.');
  });

  test('compact roundabout keeps its exit number', () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([
        RouteManeuver(location: _at(100), type: 'roundabout', exit: 3),
        _turn(122, 'right'),
      ]));
    expect(guidance.update(_at(90), english: false),
        'Hier im Kreisverkehr die dritte Ausfahrt nehmen, danach sofort rechts.');
  });

  test('replaced route recovers after a suppressed late approach', () {
    final guidance = VoiceGuidance()..setRoute(_route([_turn(100, 'right')]));
    expect(guidance.update(_at(70), english: false), isNull);
    guidance.setRoute(_route([_turn(200, 'left', name: 'Neue Straße')]));
    expect(guidance.resumeAt(_at(70)), isTrue);
    expect(guidance.announceCurrentManeuver(_at(70), english: false),
        'In 130 Metern links abbiegen, in Neue Straße.');
    expect(guidance.update(_at(70), english: false), isNull);
  });

  for (final speed in [0.0, -1.0, double.nan, double.infinity]) {
    test('unusable speed retains distance based guidance ($speed)', () {
      final guidance = VoiceGuidance()..setRoute(_route([_turn(100, 'right')]));
      expect(
          guidance.update(_at(70), english: false, speedMetersPerSecond: speed),
          isNull);
      expect(
          guidance.update(_at(90), english: false, speedMetersPerSecond: speed),
          'Hier rechts abbiegen, in Erste Straße.');
    });
  }
}
