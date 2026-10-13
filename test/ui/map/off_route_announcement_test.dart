import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:munich_ways/ui/map/off_route_announcement.dart';
import 'package:munich_ways/ui/map/voice_guidance.dart';

void main() {
  testWidgets('sparse moving fixes deliver a missed warning exactly once',
      (tester) async {
    final announcement = OffRouteAnnouncement();
    addTearDown(announcement.cancel);
    final motion = NavigationMotionTracker();
    final start = DateTime(2026, 10, 12);
    var now = start;
    var warnings = 0;
    LatLng at(double meters) => LatLng(48 + meters / 111195, 11.5);
    motion.update(at(0), 5, now: now);
    now = start.add(const Duration(seconds: 5));
    motion.update(at(20), 5, now: now);
    announcement.schedule(const Duration(seconds: 12), () {
      if (!motion.isMovingAt(now)) return false;
      warnings++;
      return true;
    });

    // The timer fires between GPS fixes, after moving state has expired.
    now = start.add(const Duration(seconds: 17));
    await tester.pump(const Duration(seconds: 12));
    expect(warnings, 0);

    // A fresh, plausible moving fix must not require another 12-second delay.
    now = start.add(const Duration(seconds: 18));
    motion.update(at(60), 5, now: now);
    announcement.retryIfDue();
    expect(warnings, 1);
    announcement.retryIfDue();
    await tester.pump(const Duration(seconds: 30));
    expect(warnings, 1);
  });

  testWidgets('frequent location updates never shorten the warning delay',
      (tester) async {
    final announcement = OffRouteAnnouncement();
    addTearDown(announcement.cancel);
    var warnings = 0;
    announcement.schedule(const Duration(seconds: 12), () {
      warnings++;
      return true;
    });
    for (var second = 0; second < 11; second++) {
      await tester.pump(const Duration(seconds: 1));
      announcement.retryIfDue();
    }
    expect(warnings, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(warnings, 1);
  });

  testWidgets('a stop or missing fresh GPS defers delivery until recovery',
      (tester) async {
    final announcement = OffRouteAnnouncement();
    addTearDown(announcement.cancel);
    var moving = false;
    var fresh = false;
    var warnings = 0;
    announcement.schedule(const Duration(seconds: 12), () {
      if (!moving || !fresh) return false;
      warnings++;
      return true;
    });
    await tester.pump(const Duration(seconds: 60));
    announcement.retryIfDue();
    fresh = true;
    announcement.retryIfDue();
    expect(warnings, 0);
    moving = true;
    fresh = false;
    announcement.retryIfDue();
    expect(warnings, 0);
    fresh = true;
    announcement.retryIfDue();
    expect(warnings, 1);
  });

  for (final elapsed in [false, true]) {
    testWidgets('cancellation removes a ${elapsed ? 'due' : 'waiting'} warning',
        (tester) async {
      final announcement = OffRouteAnnouncement();
      var ready = false;
      var warnings = 0;
      announcement.schedule(const Duration(seconds: 12), () {
        if (!ready) return false;
        warnings++;
        return true;
      });
      if (elapsed) await tester.pump(const Duration(seconds: 12));
      announcement.cancel();
      ready = true;
      announcement.retryIfDue();
      await tester.pump(const Duration(seconds: 30));
      expect(warnings, 0);
    });
  }

  testWidgets('a new episode replaces the old pending warning', (tester) async {
    final announcement = OffRouteAnnouncement();
    addTearDown(announcement.cancel);
    var oldAttempts = 0;
    var newWarnings = 0;
    announcement.schedule(const Duration(seconds: 12), () {
      oldAttempts++;
      return false;
    });
    await tester.pump(const Duration(seconds: 12));
    expect(oldAttempts, 1);
    announcement.schedule(const Duration(seconds: 12), () {
      newWarnings++;
      return true;
    });
    announcement.retryIfDue();
    expect(newWarnings, 0);
    await tester.pump(const Duration(seconds: 12));
    expect(newWarnings, 1);
    expect(oldAttempts, 1);
  });
}
