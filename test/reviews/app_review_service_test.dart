import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/reviews/app_review_service.dart';
import 'package:munich_ways/reviews/app_review_store.dart';
import 'package:munich_ways/reviews/app_review_diagnostics.dart';

class FakeReviewPlatform implements AppReviewPlatform {
  bool available = true;
  bool failAvailability = false;
  bool failRequest = false;
  bool failOpen = false;
  int requests = 0;
  int storeOpens = 0;
  Completer<bool>? availability;
  Completer<void>? opening;
  Completer<void>? requesting;

  @override
  Future<bool> isAvailable() async {
    if (failAvailability) throw StateError('offline');
    if (availability != null) return availability!.future;
    return available;
  }

  @override
  Future<void> requestReview() async {
    requests++;
    if (failRequest) throw StateError('native request failed');
    if (requesting != null) await requesting!.future;
  }

  @override
  Future<void> openStoreListing() async {
    storeOpens++;
    if (failOpen) throw StateError('store missing');
    if (opening != null) await opening!.future;
  }
}

class _MemoryReviewStore extends AppReviewStore {
  bool attempted = false;

  @override
  Future<void> requestIfEligible({
    required bool Function() canRequest,
    required Future<void> Function() request,
  }) async {
    if (attempted || !canRequest()) return;
    attempted = true;
    await request();
  }
}

void main() {
  late Directory directory;
  late AppReviewStore store;
  late FakeReviewPlatform platform;
  late AppReviewService service;
  var webOpens = 0;
  var webSucceeds = true;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('app_review_service_');
    store = AppReviewStore(
        directoryProvider: () async => directory,
        versionProvider: () async => '3.2.2');
    platform = FakeReviewPlatform();
    webOpens = 0;
    webSucceeds = true;
    service = AppReviewService(
      store: store,
      platform: platform,
      openWebListing: () async {
        webOpens++;
        return webSucceeds;
      },
    );
    for (var i = 0; i < 3; i++) {
      await store.recordCompletedTrip();
    }
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
      'diagnostics distinguishes API handoff from unavailable store and survives restart',
      () async {
    platform.available = false;
    await service.requestAutomaticReview(canRequest: () => true);
    var data = await service.readDiagnostics();
    expect(data.completedTrips, 3);
    expect(data.requestAttempted, isFalse);
    expect(data.storeAvailable, isFalse);
    expect(data.events.map((e) => e.event),
        contains(ReviewDiagnosticEvent.storeUnavailable));
    expect(data.events.map((e) => e.event),
        isNot(contains(ReviewDiagnosticEvent.nativeHandoff)));
    platform.available = true;
    await service.requestAutomaticReview(canRequest: () => true);
    data = await service.readDiagnostics();
    expect(data.requestAttempted, isTrue);
    expect(
        data.events.map((e) => e.event),
        containsAllInOrder([
          ReviewDiagnosticEvent.nativeHandoff,
          ReviewDiagnosticEvent.nativeCompleted,
        ]));
    service = AppReviewService(store: store, platform: platform);
    data = await service.readDiagnostics();
    expect(data.completedTrips, 3);
    expect(data.requestAttempted, isTrue);
    expect(data.events, isEmpty);
    expect(data.storeAvailable, isNull);
    expect(platform.requests, 1);
  });

  test(
      'diagnostics reports storage failure without resetting and bounds session history',
      () async {
    final file = File('${directory.path}/${AppReviewStore.fileName}');
    await file.writeAsString('broken');
    final data = await service.readDiagnostics();
    expect(data.completedTrips, isNull);
    expect(data.requestAttempted, isNull);
    expect(data.storageError, 'FormatException');
    expect(await file.readAsString(), 'broken');
    for (var i = 0; i < 40; i++) {
      service.recordDiagnosticEvent(ReviewDiagnosticEvent.promptCancelled);
    }
    expect((await service.readDiagnostics()).events.length, 20);
    expect(data.events, isEmpty);
    expect(platform.requests, 0);
  });

  testWidgets(
      'availability timeout can recover and late result does not request',
      (tester) async {
    final memory = _MemoryReviewStore();
    service = AppReviewService(store: memory, platform: platform);
    final oldAvailability = Completer<bool>();
    platform.availability = oldAvailability;
    final pending = service.requestAutomaticReview(canRequest: () => true);
    await tester.pump(const Duration(seconds: 6));
    await pending;
    expect(platform.requests, 0);
    expect(memory.attempted, isFalse);
    oldAvailability.complete(true);
    await tester.pump();
    expect(platform.requests, 0);
    platform.availability = null;
    await service.requestAutomaticReview(canRequest: () => true);
    expect(platform.requests, 1);
  });

  testWidgets(
      'native timeout is contained and does not retry the handed off request',
      (tester) async {
    service = AppReviewService(store: _MemoryReviewStore(), platform: platform);
    platform.requesting = Completer<void>();
    final pending = service.requestAutomaticReview(canRequest: () => true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    await pending;
    await service.requestAutomaticReview(canRequest: () => true);
    expect(platform.requests, 1);
    platform.requesting!.complete();
    await tester.pump();
  });

  test('unavailable store leaves a later native request possible', () async {
    platform.available = false;
    await service.requestAutomaticReview(canRequest: () => true);
    expect(platform.requests, 0);
    platform.available = true;
    await service.requestAutomaticReview(canRequest: () => true);
    await service.requestAutomaticReview(canRequest: () => true);
    expect(platform.requests, 1);
    expect(webOpens, 0);
  });

  test('availability failure recovers without automatic store redirect',
      () async {
    platform.failAvailability = true;
    await service.requestAutomaticReview(canRequest: () => true);
    platform.failAvailability = false;
    await service.requestAutomaticReview(canRequest: () => true);
    expect(platform.requests, 1);
    expect(platform.storeOpens, 0);
    expect(webOpens, 0);
  });

  test('UI cancellation while checking availability prevents native handoff',
      () async {
    platform.availability = Completer<bool>();
    var canRequest = true;
    final request =
        service.requestAutomaticReview(canRequest: () => canRequest);
    canRequest = false;
    platform.availability!.complete(true);
    await request;
    expect(platform.requests, 0);
    expect(await store.recordCompletedTrip(), isTrue);
  });

  test('native exception is contained and the attempt is not repeated',
      () async {
    platform.failRequest = true;
    await service.requestAutomaticReview(canRequest: () => true);
    platform.failRequest = false;
    await service.requestAutomaticReview(canRequest: () => true);
    expect(platform.requests, 1);
    expect(webOpens, 0);
  });

  test('manual store opening uses HTTPS without consuming automatic request',
      () async {
    platform.failOpen = true;
    expect(await service.openStoreListing(), isTrue);
    expect(webOpens, 1);
    await service.requestAutomaticReview(canRequest: () => true);
    expect(platform.requests, 1);
  });

  test('failed manual opening can retry and does not consume eligibility',
      () async {
    platform.failOpen = true;
    webSucceeds = false;
    expect(await service.openStoreListing(), isFalse);
    expect(await store.recordCompletedTrip(), isTrue);
    platform.failOpen = false;
    expect(await service.openStoreListing(), isTrue);
    expect(platform.storeOpens, 2);
    expect(webOpens, 1);
  });

  test('simultaneous manual taps share one launch; later taps remain available',
      () async {
    platform.opening = Completer<void>();
    final first = service.openStoreListing();
    final second = service.openStoreListing();
    expect(identical(first, second), isTrue);
    expect(platform.storeOpens, 1);
    platform.opening!.complete();
    expect(await first, isTrue);
    expect(await service.openStoreListing(), isTrue);
    expect(platform.storeOpens, 2);
  });

  test('storage failure skips review and recovers once storage is repaired',
      () async {
    final file = File('${directory.path}/${AppReviewStore.fileName}');
    final obstruction = Directory('${file.path}.tmp');
    await obstruction.create();
    await service.requestAutomaticReview(canRequest: () => true);
    expect(platform.requests, 0);
    await obstruction.delete();
    await service.requestAutomaticReview(canRequest: () => true);
    expect(platform.requests, 1);
  });

  test('manual opening is independent of review state and storage failures',
      () async {
    final file = File('${directory.path}/${AppReviewStore.fileName}');
    final obstruction = Directory('${file.path}.tmp');
    await obstruction.create();
    expect(await service.openStoreListing(), isTrue);
    await obstruction.delete();
    expect(await service.openStoreListing(), isTrue);
    expect((jsonDecode(await file.readAsString()) as Map)['attempts'], isEmpty);
    await service.requestAutomaticReview(canRequest: () => true);
    expect(platform.requests, 1);
  });
}
