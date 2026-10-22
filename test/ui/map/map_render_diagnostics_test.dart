import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/map/map_render_diagnostics.dart';

void main() {
  final epoch = DateTime.utc(2026, 10, 22, 12);

  test('pending native work remains visible while other operations complete',
      () async {
    final diagnostics = MapRenderDiagnostics(now: () => epoch);
    final native = Completer<int>();
    final pending = diagnostics.track('position camera', () => native.future);
    expect(diagnostics.snapshot(english: true)['Pending map calls'],
        contains('position camera (2026-10-22T12:00:00.000Z)'));
    expect(await diagnostics.track('position layer', () async => 42), 42);
    final snapshot = diagnostics.snapshot(english: true);
    expect(snapshot['Native map calls (started/completed/failed)'], '2/1/0');
    expect(snapshot['Pending map calls'], contains('position camera'));
    native.complete(7);
    expect(await pending, 7);
    expect(diagnostics.snapshot(english: true)['Pending map calls'], '—');
  });

  test('native failures propagate unchanged without recording private details',
      () async {
    final diagnostics = MapRenderDiagnostics(now: () => epoch);
    final error = StateError('private native error message');
    await expectLater(
        diagnostics.track<void>('position layer', () async => throw error),
        throwsA(same(error)));
    final snapshot = diagnostics.snapshot(english: true);
    expect(snapshot['Native map calls (started/completed/failed)'], '1/0/1');
    expect(snapshot['Pending map calls'], '—');
    expect(snapshot['Recent map events'], contains('failed (StateError)'));
    expect(
        snapshot.toString(), isNot(contains('private native error message')));
  });

  test('a later completion cannot hide an earlier call with the same name',
      () async {
    final diagnostics = MapRenderDiagnostics(now: () => epoch);
    final native = Completer<void>();
    final pending = diagnostics.track('read camera', () => native.future);
    await diagnostics.track('read camera', () async {});
    expect(diagnostics.snapshot(english: true)['Pending map calls'],
        contains('read camera'));
    native.complete();
    await pending;
    expect(diagnostics.snapshot(english: true)['Pending map calls'], '—');
  });

  test('event history and pending details are bounded during a native stall',
      () async {
    final diagnostics = MapRenderDiagnostics(now: () => epoch);
    final native = Completer<void>();
    final pending = [
      for (var i = 0; i < 40; i++)
        diagnostics.track('read camera', () => native.future),
    ];
    final snapshot = diagnostics.snapshot(english: true);
    expect(snapshot['Recent map events']!.split('\n'),
        hasLength(MapRenderDiagnostics.maximumEvents));
    expect(snapshot['Pending map calls']!.split('\n'),
        hasLength(MapRenderDiagnostics.maximumPendingDetails + 1));
    expect(snapshot['Pending map calls'], contains('+ 24 more'));
    native.complete();
    await Future.wait(pending);
    expect(diagnostics.snapshot(english: true)['Pending map calls'], '—');
    expect(
        diagnostics.snapshot(
            english: true)['Native map calls (started/completed/failed)'],
        '40/40/0');
  });

  test('native callback times are independent of successful channel replies',
      () async {
    var now = epoch;
    final diagnostics = MapRenderDiagnostics(now: () => now);
    diagnostics.cameraMoved();
    now = now.add(const Duration(seconds: 1));
    diagnostics.cameraIdle();
    now = now.add(const Duration(seconds: 1));
    diagnostics.mapIdle();
    now = now.add(const Duration(minutes: 1));
    await diagnostics.track('position layer', () async {});
    final snapshot = diagnostics.snapshot(english: true);
    expect(snapshot['Last native camera move (UTC)'], epoch.toIso8601String());
    expect(snapshot['Last native camera idle (UTC)'],
        epoch.add(const Duration(seconds: 1)).toIso8601String());
    expect(snapshot['Last native map idle (UTC)'],
        epoch.add(const Duration(seconds: 2)).toIso8601String());
    expect(diagnostics.snapshot(english: false),
        contains('Letzte native Kamerabewegung (UTC)'));
  });
}
