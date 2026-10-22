import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

// Keep projection distances exact and geometry neutral: these tests describe
// the routing service's maneuvers, rather than testing inferred corner angles.
LatLng _at(double meters) => LatLng(48.14 + meters / 111320, 11.57);

RouteManeuver _maneuver(double meters, String type, String? modifier,
        {String name = '', RouteWayType? wayType}) =>
    RouteManeuver(
      location: _at(meters),
      type: type,
      modifier: modifier,
      roadName: name,
      wayType: wayType,
    );

CycleRoute _route(List<RouteManeuver> maneuvers,
        {bool supportsVoiceGuidance = true}) =>
    CycleRoute([_at(0), _at(1000)], 1000, 300,
        maneuvers: maneuvers, supportsVoiceGuidance: supportsVoiceGuidance);

void main() {
  test('house-number start skips departure and straight notification (#278)',
      () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([
        _maneuver(0, 'depart', 'straight'),
        _maneuver(19, 'notification', 'straight'),
        _maneuver(32, 'turn', 'right',
            name: 'Schloßschmidstraße', wayType: RouteWayType.road),
        _maneuver(153, 'turn', 'left',
            name: 'Birketweg', wayType: RouteWayType.road),
      ]));
    expect(guidance.startPreview(english: false),
        'In 30 Metern rechts abbiegen in Schloßschmidstraße, danach links abbiegen in Birketweg.');
    expect(guidance.startPreview(english: true),
        'In 30 meters, turn right onto Schloßschmidstraße, then turn left onto Birketweg.');
  });

  test('same-name turn and known cycle path provide orientation (#278)', () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([
        _maneuver(0, 'depart', null, name: 'Birketweg'),
        _maneuver(292, 'continue', 'left',
            name: 'Birketweg', wayType: RouteWayType.road),
        _maneuver(304, 'turn', 'right', wayType: RouteWayType.cycleway),
        _maneuver(324, 'turn', 'straight'),
      ]));
    expect(guidance.startPreview(english: false),
        'In 290 Metern links weiterfahren in Birketweg, danach rechts abbiegen auf Radweg.');
    expect(guidance.startPreview(english: true),
        'In 290 meters, keep left onto Birketweg, then turn right onto the cycle path.');
  });

  test('park start keeps slight turn and skips straight name change (#278)',
      () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([
        _maneuver(0, 'depart', 'left'),
        _maneuver(117, 'turn', 'slight right', wayType: RouteWayType.cycleway),
        _maneuver(152, 'turn', 'left',
            name: 'De-la-Paz-Straße', wayType: RouteWayType.road),
        _maneuver(181, 'new name', 'straight',
            name: 'Winfriedstraße', wayType: RouteWayType.road),
      ]));
    expect(guidance.startPreview(english: false),
        'In 120 Metern leicht rechts halten auf Radweg, danach links abbiegen in De-la-Paz-Straße.');
  });

  test('short dogleg names both roads without saying immediately (#278)', () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([
        _maneuver(0, 'depart', null, name: 'Richildenstraße'),
        _maneuver(159, 'turn', 'right',
            name: 'Laimer Straße', wayType: RouteWayType.road),
        _maneuver(182, 'turn', 'left',
            name: 'Richildenstraße', wayType: RouteWayType.road),
        _maneuver(304, 'arrive', null),
      ]));
    expect(guidance.startPreview(english: false),
        'In 160 Metern rechts abbiegen in Laimer Straße, danach links abbiegen in Richildenstraße.');
  });

  test('skips straight turns, notifications and way-type-only transitions', () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([
        _maneuver(20, 'turn', 'straight'),
        RouteManeuver(
            location: _at(25),
            type: 'notification',
            modifier: 'straight',
            enteringWayType: RouteWayType.cycleway),
        _maneuver(50, 'continue', 'straight'),
        _maneuver(80, 'turn', 'left'),
      ]));
    expect(
        guidance.startPreview(english: false), 'In 80 Metern links abbiegen.');
  });

  test('speaks at most two real turns and normalizes road names', () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([
        _maneuver(100, 'turn', 'right',
            name: '  Laimer\n Straße  ', wayType: RouteWayType.road),
        _maneuver(300, 'turn', 'left'),
        _maneuver(500, 'turn', 'uturn'),
      ]));
    expect(guidance.startPreview(english: false),
        'In 100 Metern rechts abbiegen in Laimer Straße, danach links abbiegen.');
  });

  test('handles a turn immediately at the route start', () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([_maneuver(0, 'turn', 'right')]));
    expect(guidance.startPreview(english: false), 'Hier rechts abbiegen.');
    expect(guidance.startPreview(english: true), 'Turn right here.');
  });

  test('roundabout is one real maneuver including its exit', () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([
        RouteManeuver(location: _at(100), type: 'roundabout', exit: 2),
        _maneuver(120, 'exit roundabout', 'right'),
        _maneuver(200, 'turn', 'left'),
      ]));
    expect(guidance.startPreview(english: false),
        'In 100 Metern im Kreisverkehr die zweite Ausfahrt nehmen, danach links abbiegen.');
  });

  test('preview leaves normal announcements, matching and start gate intact',
      () {
    final route = _route([
      _maneuver(100, 'turn', 'right'),
      _maneuver(300, 'turn', 'left'),
    ]);
    final previewed = VoiceGuidance()..setRoute(route);
    final control = VoiceGuidance()..setRoute(route);
    final gate = NavigationStartGate()..reset(_at(0));
    expect(gate.isWaiting(_at(0)), isTrue);
    expect(previewed.startPreview(english: false), isNotNull);
    expect(previewed.remainingEstimate, isNull);
    expect(gate.isWaiting(_at(20)), isTrue);
    expect(gate.isWaiting(_at(30)), isFalse);
    expect(previewed.announceCurrentManeuver(_at(30), english: false),
        control.announceCurrentManeuver(_at(30), english: false));
    for (final meters in [45.0, 90.0, 135.0, 200.0, 250.0, 290.0]) {
      expect(previewed.update(_at(meters), english: false),
          control.update(_at(meters), english: false));
    }
  });

  test('no preview for missing, straight-only or map-only routes', () {
    final guidance = VoiceGuidance();
    expect(guidance.startPreview(english: false), isNull);
    guidance.setRoute(_route([
      _maneuver(0, 'depart', null),
      _maneuver(50, 'turn', 'straight'),
      _maneuver(1000, 'arrive', null),
    ]));
    expect(guidance.startPreview(english: false), isNull);
    guidance.setRoute(_route([_maneuver(100, 'turn', 'right')],
        supportsVoiceGuidance: false));
    expect(guidance.startPreview(english: false), isNull);
  });

  test('ending and starting a new route replaces the preview', () {
    final guidance = VoiceGuidance()
      ..setRoute(_route([_maneuver(100, 'turn', 'right')]));
    expect(guidance.startPreview(english: false), contains('rechts'));
    guidance.reset();
    expect(guidance.startPreview(english: false), isNull);
    guidance.setRoute(_route([_maneuver(200, 'turn', 'left')]));
    expect(
        guidance.startPreview(english: false), 'In 200 Metern links abbiegen.');
  });
}
