import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/api/settings_store.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/map_route_state.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/map/navigation_camera_follow.dart';
import 'package:munich_ways/ui/map/navigation_remaining.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

import '../../support/wakelock_stub.dart';

class _Settings extends SettingsStore {
  @override
  Future<SettingsData> load() async => SettingsData.defaults;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(stubWakelock);
  final epoch = DateTime(2026, 10, 17, 12);
  DateTime time(int seconds) => epoch.add(Duration(seconds: seconds));
  LatLng at(double meters) => LatLng(48 + meters / 111195, 11.5);
  const moving = NavigationMotionSample(moving: true, confirmedMeters: 15);
  late NavigationCameraFollowGate gate;
  setUp(() => gate = NavigationCameraFollowGate());

  bool resume(int seconds,
          {NavigationMotionSample motion = moving, int? fix}) =>
      gate.shouldResume(
          now: time(seconds), fixTime: time(fix ?? seconds), motion: motion);

  test('stationary inspection has no timeout that recentres the map', () {
    gate.pointerDown(1, time(0));
    gate.pointerUp(1, time(1));
    expect(resume(60, motion: const NavigationMotionSample()), isFalse);
    expect(resume(600, motion: const NavigationMotionSample(moving: true)),
        isFalse);
    expect(resume(601), isTrue);
  });

  test('moving rider can resume only after the gesture release delay', () {
    gate.pointerDown(1, time(0));
    expect(resume(10), isFalse);
    gate.pointerUp(1, time(10));
    expect(resume(12), isFalse);
    expect(resume(13), isTrue);
  });

  test('pinching keeps the camera still until both fingers are released', () {
    gate.pointerDown(1, time(0));
    gate.pointerDown(2, time(1));
    gate.pointerUp(1, time(2));
    expect(resume(10), isFalse);
    gate.pointerUp(2, time(10));
    expect(resume(12), isFalse);
    expect(resume(13), isTrue);
  });

  test('each new gesture restarts the quiet period', () {
    gate.pointerDown(1, time(0));
    gate.pointerUp(1, time(1));
    gate.pointerDown(2, time(3));
    gate.pointerUp(2, time(5));
    expect(resume(7), isFalse);
    expect(resume(8), isTrue);
  });

  test('north-up inspection has the same quiet period as map gestures', () {
    gate.recordInteraction(time(10));
    expect(resume(12), isFalse);
    expect(resume(13), isTrue);
  });

  test('old, replayed and future fixes cannot restore the camera', () {
    gate.recordInteraction(time(10));
    expect(resume(20, fix: 9), isFalse);
    expect(resume(20, fix: 10), isFalse);
    expect(resume(20, fix: 21), isFalse);
    expect(resume(20, fix: 20), isTrue);
  });

  test('a reset forgets an old interaction and every active pointer', () {
    gate.pointerDown(1, time(0));
    gate.reset();
    expect(gate.interacting, isFalse);
    expect(resume(10), isFalse);
    gate.recordInteraction(time(20));
    expect(resume(23), isTrue);
  });

  test('GPS jitter and cached moving state cannot end stationary inspection',
      () {
    final motion = NavigationMotionTracker();
    motion.update(at(0), 5, now: time(0));
    motion.update(at(20), 5, now: time(5));
    gate.recordInteraction(time(6));
    final jitter = motion.update(at(21), 5, now: time(10));
    expect(jitter.moving, isTrue);
    expect(resume(10, motion: jitter), isFalse);
    expect(resume(15, motion: motion.update(at(40), 5, now: time(15))), isTrue);
  });

  test('GPS gaps, jumps and inaccurate fixes require fresh movement afterwards',
      () {
    final motion = NavigationMotionTracker();
    motion.update(at(0), 5, now: time(0));
    gate.recordInteraction(time(1));
    expect(resume(5, motion: motion.update(at(500), 5, now: time(5))), isFalse);
    expect(
        resume(10, motion: motion.update(at(520), 80, now: time(10))), isFalse);
    expect(
        resume(15, motion: motion.update(at(540), 5, now: time(15))), isFalse);
    expect(
        resume(60, motion: motion.update(at(560), 5, now: time(60))), isFalse);
    expect(
        resume(65, motion: motion.update(at(580), 5, now: time(65))), isTrue);
  });

  test('camera-only resume retains route, remaining values and consumed speech',
      () async {
    final route = CycleRoute([at(0), at(100), at(200)], 200, 60,
        maneuvers: [
          RouteManeuver(location: at(100), type: 'turn', modifier: 'right')
        ]);
    final model = MapScreenViewModel(store: _Settings())
      ..route = MapRoute(route, MapRouteState.SHOWN)
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    addTearDown(model.dispose);
    await model.startNavigation();
    final guidance = VoiceGuidance()..setRoute(route);
    final remaining = NavigationRemainingController();
    addTearDown(remaining.dispose);
    expect(guidance.update(at(50), english: true), contains('turn right'));

    model.onUserStoppedFollowingLocation();
    remaining.setPaused(model.navigationPaused);
    guidance.display(at(70), english: true);
    remaining.update(guidance.remainingEstimate, fixTime: DateTime.now());
    expect(model.navigationActive, isTrue);
    expect(remaining.value, isNotNull);
    expect(model.resumeNavigationCameraFollowing(), isTrue);
    expect(model.route.route, same(route));
    expect(guidance.update(at(70), english: true), isNull);
    expect(guidance.update(at(90), english: true), contains('here'));
    expect(model.locationState, LocationState.FOLLOW_AND_ROTATE_MAP);
  });

  test('confirmed riding never resumes a deliberate navigation pause',
      () async {
    final model = MapScreenViewModel(store: _Settings())
      ..locationState = LocationState.FOLLOW_AND_ROTATE_MAP;
    addTearDown(model.dispose);
    await model.startNavigation();
    model.onUserStoppedFollowingLocation();
    gate.recordInteraction(time(0));
    model.pauseNavigation();
    expect(resume(10), isTrue);
    expect(model.resumeNavigationCameraFollowing(), isFalse);
    expect(model.navigationPaused, isTrue);
    expect(model.locationState, LocationState.DISPLAY);
  });
}
