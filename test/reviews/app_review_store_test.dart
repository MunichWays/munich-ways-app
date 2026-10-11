import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/reviews/app_review_store.dart';

void main() {
  late Directory directory;
  late AppReviewStore store;
  File stateFile() => File('${directory.path}/${AppReviewStore.fileName}');
  Future<Map<String, dynamic>> state() async =>
      jsonDecode(await stateFile().readAsString()) as Map<String, dynamic>;
  Future<void> qualify() async {
    for (var i = 0; i < 3; i++) {
      await store.recordCompletedTrip();
    }
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('app_review_store_');
    store = AppReviewStore(directoryProvider: () async => directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('diagnostics reads without creating, incrementing or resetting state',
      () async {
    final empty = await store.readDiagnostics();
    expect(empty.completedTrips, 0);
    expect(empty.requestAttempted, isFalse);
    expect(await stateFile().exists(), isFalse);
    await store.recordCompletedTrip();
    final before = await stateFile().readAsString();
    expect((await store.readDiagnostics()).completedTrips, 1);
    expect(await stateFile().readAsString(), before);
    await stateFile().writeAsString('broken');
    await expectLater(store.readDiagnostics(), throwsFormatException);
    expect(await stateFile().readAsString(), 'broken');
  });

  test('third completed trip qualifies and count survives a new instance',
      () async {
    expect(await store.recordCompletedTrip(), isFalse);
    expect(await store.recordCompletedTrip(), isFalse);
    store = AppReviewStore(directoryProvider: () async => directory);
    expect(await store.recordCompletedTrip(), isTrue);
    expect((await state())['completedTrips'], 3);
  });

  test(
      'diagnostics can read the persisted attempt during a pending native call',
      () async {
    await qualify();
    final entered = Completer<void>();
    final native = Completer<void>();
    final pending = store.requestOnce(
        canRequest: () => true,
        request: () {
          entered.complete();
          return native.future;
        });
    await entered.future;
    try {
      final snapshot =
          await store.readDiagnostics().timeout(const Duration(seconds: 2));
      expect(snapshot.completedTrips, 3);
      expect(snapshot.requestAttempted, isTrue);
    } finally {
      native.complete();
      await pending;
    }
  });

  test('concurrent completions are serialized and count is bounded', () async {
    final results = await Future.wait(
        List.generate(12, (_) => store.recordCompletedTrip()));
    expect(results.take(2), [false, false]);
    expect(results.skip(2), everyElement(isTrue));
    expect((await state())['completedTrips'], 3);
  });

  test('unreleased manual suppression migrates once while retaining trips',
      () async {
    await stateFile().writeAsString(
        '{"schema":1,"completedTrips":3,"requestAttempted":true}');
    expect(await store.recordCompletedTrip(), isTrue);
    var requests = 0;
    await store.requestOnce(
        canRequest: () => true,
        request: () async {
          requests++;
          expect((await state())['schema'], 2);
          expect((await state())['completedTrips'], 3);
          expect((await state())['requestAttempted'], isTrue);
        });
    store = AppReviewStore(directoryProvider: () async => directory);
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestOnce(
        canRequest: () => true, request: () async => requests++);
    expect(requests, 1);
  });

  test('existing installation without review state starts at zero after update',
      () async {
    final existingData = File('${directory.path}/existing_settings.json');
    await existingData.writeAsString('{"favorite":"retained"}');
    expect(await stateFile().exists(), isFalse);
    expect(await store.recordCompletedTrip(), isFalse);
    expect((await state())['completedTrips'], 1);
    store = AppReviewStore(directoryProvider: () async => directory);
    expect(await store.recordCompletedTrip(), isFalse);
    expect(await store.recordCompletedTrip(), isTrue);
    var requests = 0;
    await store.requestOnce(
        canRequest: () => true, request: () async => requests++);
    store = AppReviewStore(directoryProvider: () async => directory);
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestOnce(
        canRequest: () => true, request: () async => requests++);
    expect(requests, 1);
    expect(await existingData.readAsString(), '{"favorite":"retained"}');
  });

  test('does not request before three trips or while UI is busy', () async {
    var requests = 0;
    Future<void> request() async => requests++;
    await store.requestOnce(canRequest: () => true, request: request);
    expect(await stateFile().exists(), isFalse);
    await qualify();
    await store.requestOnce(canRequest: () => false, request: request);
    expect(requests, 0);
    expect((await state())['requestAttempted'], isFalse);
  });

  test('concurrent requests hand off once and persist before native call',
      () async {
    await qualify();
    var requests = 0;
    Future<void> request() async {
      expect((await state())['requestAttempted'], isTrue);
      requests++;
    }

    await Future.wait(List.generate(
        5, (_) => store.requestOnce(canRequest: () => true, request: request)));
    expect(requests, 1);
    store = AppReviewStore(directoryProvider: () async => directory);
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestOnce(canRequest: () => true, request: request);
    expect(requests, 1);
  });

  test('cancellation during reservation keeps a later request possible',
      () async {
    await qualify();
    var checks = 0;
    var requests = 0;
    Future<void> request() async => requests++;
    await store.requestOnce(canRequest: () => ++checks == 1, request: request);
    expect(requests, 0);
    expect((await state())['requestAttempted'], isFalse);
    await store.requestOnce(canRequest: () => true, request: request);
    expect(requests, 1);
  });

  test('native failure consumes the attempt without poisoning the queue',
      () async {
    await qualify();
    await expectLater(
        store.requestOnce(
            canRequest: () => true,
            request: () async => throw StateError('native failure')),
        throwsStateError);
    var requests = 0;
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestOnce(
        canRequest: () => true, request: () async => requests++);
    expect(requests, 0);
  });

  test('failed counter write can recover without losing existing count',
      () async {
    await store.recordCompletedTrip();
    final obstruction = Directory('${stateFile().path}.tmp');
    await obstruction.create();
    await expectLater(
        store.recordCompletedTrip(), throwsA(isA<FileSystemException>()));
    expect((await state())['completedTrips'], 1);
    await obstruction.delete();
    expect(await store.recordCompletedTrip(), isFalse);
    expect(await store.recordCompletedTrip(), isTrue);
  });

  test('failed reservation never invokes native and recovers after repair',
      () async {
    await qualify();
    final obstruction = Directory('${stateFile().path}.tmp');
    await obstruction.create();
    var requests = 0;
    Future<void> request() async => requests++;
    await expectLater(
        store.requestOnce(canRequest: () => true, request: request),
        throwsA(isA<FileSystemException>()));
    expect(requests, 0);
    expect((await state())['requestAttempted'], isFalse);
    await obstruction.delete();
    await store.requestOnce(canRequest: () => true, request: request);
    expect(requests, 1);
  });

  for (final contents in [
    '{',
    '[]',
    '{"schema":3,"completedTrips":3,"requestAttempted":false}',
    '{"schema":1,"completedTrips":-1,"requestAttempted":false}',
    '{"schema":1,"completedTrips":4,"requestAttempted":false}',
    '{"schema":1,"completedTrips":3}',
  ]) {
    test('corrupt/unknown state stays intact and can recover: $contents',
        () async {
      await stateFile().writeAsString(contents);
      await expectLater(store.recordCompletedTrip(), throwsFormatException);
      await expectLater(
          store.requestOnce(
              canRequest: () => true,
              request: () async => fail('must not request')),
          throwsFormatException);
      expect(await stateFile().readAsString(), contents);
      await stateFile().writeAsString(
          '{"schema":1,"completedTrips":2,"requestAttempted":false}');
      expect(await store.recordCompletedTrip(), isTrue);
    });
  }
}
