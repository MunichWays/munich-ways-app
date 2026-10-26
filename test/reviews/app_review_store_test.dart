import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/reviews/app_review_store.dart';

void main() {
  late Directory directory;
  late AppReviewStore store;
  var now = DateTime.utc(2026, 1, 1);
  var version = '3.2.2';
  AppReviewStore newStore() => AppReviewStore(
        directoryProvider: () async => directory,
        now: () => now,
        versionProvider: () async => version,
      );
  File stateFile() => File('${directory.path}/${AppReviewStore.fileName}');
  Future<Map<String, dynamic>> state() async =>
      jsonDecode(await stateFile().readAsString()) as Map<String, dynamic>;
  Future<void> qualify() async {
    for (var i = 0; i < 3; i++) {
      await store.recordCompletedTrip();
    }
  }

  setUp(() async {
    now = DateTime.utc(2026, 1, 1);
    version = '3.2.2';
    directory = await Directory.systemTemp.createTemp('app_review_store_');
    store = newStore();
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
    store = newStore();
    expect(await store.recordCompletedTrip(), isTrue);
    expect((await state())['completedTrips'], 3);
  });

  test(
      'diagnostics can read the persisted attempt during a pending native call',
      () async {
    await qualify();
    final entered = Completer<void>();
    final native = Completer<void>();
    final pending = store.requestIfEligible(
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

  test('concurrent completions are serialized without losing trips', () async {
    final results = await Future.wait(
        List.generate(12, (_) => store.recordCompletedTrip()));
    expect(results.take(2), [false, false]);
    expect(results.skip(2), everyElement(isTrue));
    expect((await state())['completedTrips'], 12);
  });

  test('unreleased manual suppression migrates once while retaining trips',
      () async {
    await stateFile().writeAsString(
        '{"schema":1,"completedTrips":3,"requestAttempted":true}');
    expect(await store.recordCompletedTrip(), isTrue);
    var requests = 0;
    await store.requestIfEligible(
        canRequest: () => true,
        request: () async {
          requests++;
          expect((await state())['schema'], 3);
          expect((await state())['completedTrips'], 4);
          expect((await state())['attempts'], hasLength(1));
        });
    store = newStore();
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestIfEligible(
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
    store = newStore();
    expect(await store.recordCompletedTrip(), isFalse);
    expect(await store.recordCompletedTrip(), isTrue);
    var requests = 0;
    await store.requestIfEligible(
        canRequest: () => true, request: () async => requests++);
    store = newStore();
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestIfEligible(
        canRequest: () => true, request: () async => requests++);
    expect(requests, 1);
    expect(await existingData.readAsString(), '{"favorite":"retained"}');
  });

  test('does not request before three trips or while UI is busy', () async {
    var requests = 0;
    Future<void> request() async => requests++;
    await store.requestIfEligible(canRequest: () => true, request: request);
    expect(await stateFile().exists(), isFalse);
    await qualify();
    await store.requestIfEligible(canRequest: () => false, request: request);
    expect(requests, 0);
    expect((await state())['attempts'], isEmpty);
  });

  test('concurrent requests hand off once and persist before native call',
      () async {
    await qualify();
    var requests = 0;
    Future<void> request() async {
      expect((await state())['attempts'], hasLength(1));
      requests++;
    }

    await Future.wait(List.generate(
        5,
        (_) =>
            store.requestIfEligible(canRequest: () => true, request: request)));
    expect(requests, 1);
    store = newStore();
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestIfEligible(canRequest: () => true, request: request);
    expect(requests, 1);
  });

  test('cancellation during reservation keeps a later request possible',
      () async {
    await qualify();
    var checks = 0;
    var requests = 0;
    Future<void> request() async => requests++;
    await store.requestIfEligible(
        canRequest: () => ++checks <= 2, request: request);
    expect(requests, 0);
    expect((await state())['attempts'], isEmpty);
    await store.requestIfEligible(canRequest: () => true, request: request);
    expect(requests, 1);
  });

  test('native failure consumes the attempt without poisoning the queue',
      () async {
    await qualify();
    await expectLater(
        store.requestIfEligible(
            canRequest: () => true,
            request: () async => throw StateError('native failure')),
        throwsStateError);
    var requests = 0;
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestIfEligible(
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
        store.requestIfEligible(canRequest: () => true, request: request),
        throwsA(isA<FileSystemException>()));
    expect(requests, 0);
    expect((await state())['attempts'], isEmpty);
    await obstruction.delete();
    await store.requestIfEligible(canRequest: () => true, request: request);
    expect(requests, 1);
  });

  test('occasional use qualifies again after three more trips and 30 days',
      () async {
    await qualify();
    var requests = 0;
    Future<void> request() async => requests++;
    await store.requestIfEligible(canRequest: () => true, request: request);
    version = '3.2.3';
    now = now.add(const Duration(days: 14));
    expect(await store.recordCompletedTrip(), isFalse);
    now = now.add(const Duration(days: 15));
    expect(await store.recordCompletedTrip(), isFalse);
    // Three additional trips suffice; reaching ten or fifty is unnecessary.
    expect(await store.recordCompletedTrip(), isFalse);
    now = now.add(const Duration(days: 1));
    store = newStore();
    expect(await store.recordCompletedTrip(), isTrue);
    await store.requestIfEligible(canRequest: () => true, request: request);
    expect(requests, 2);
    expect((await state())['attempts'], hasLength(2));
  });

  test('time and an update alone do not replace three additional trips',
      () async {
    await qualify();
    await store.requestIfEligible(canRequest: () => true, request: () async {});
    version = '3.2.3';
    now = now.add(const Duration(days: 180));
    expect(await store.recordCompletedTrip(), isFalse);
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestIfEligible(
        canRequest: () => true, request: () async => fail('too few trips'));
    expect(await store.recordCompletedTrip(), isTrue);
  });

  test('one attempt per marketing version, including after a year or rollback',
      () async {
    await qualify();
    await store.requestIfEligible(canRequest: () => true, request: () async {});
    now = now.add(const Duration(days: 366));
    await qualify();
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestIfEligible(
        canRequest: () => true, request: () async => fail('same version'));
    version = '3.2.3';
    expect(await store.recordCompletedTrip(), isTrue);
    await store.requestIfEligible(canRequest: () => true, request: () async {});
    now = now.add(const Duration(days: 366));
    await qualify();
    version = '3.2.2';
    store = newStore();
    expect(await store.recordCompletedTrip(), isFalse);
  });

  test('rolling year blocks fourth attempt until oldest expires exactly',
      () async {
    final start = now;
    var requests = 0;
    Future<void> request() async => requests++;
    for (var i = 0; i < 3; i++) {
      version = '3.2.${i + 2}';
      now = start.add(Duration(days: i * 30));
      await qualify();
      await store.requestIfEligible(canRequest: () => true, request: request);
    }
    expect(requests, 3);
    version = '3.2.5';
    now = start.add(const Duration(days: 90));
    await qualify();
    expect(await store.recordCompletedTrip(), isFalse);
    await store.requestIfEligible(canRequest: () => true, request: request);
    now = start.add(const Duration(days: 365) - const Duration(seconds: 1));
    expect(await store.recordCompletedTrip(), isFalse);
    now = start.add(const Duration(days: 365));
    store = newStore();
    expect(await store.recordCompletedTrip(), isTrue);
    await Future.wait(List.generate(
        5,
        (_) =>
            store.requestIfEligible(canRequest: () => true, request: request)));
    expect(requests, 4);
  });

  test('clock moving backwards cannot bypass the cooldown', () async {
    await qualify();
    await store.requestIfEligible(canRequest: () => true, request: () async {});
    now = now.subtract(const Duration(days: 90));
    version = '3.2.3';
    await qualify();
    await store.requestIfEligible(
        canRequest: () => true, request: () async => fail('clock went back'));
    expect(await store.recordCompletedTrip(), isFalse);
    now = DateTime.utc(2026, 1, 31);
    expect(await store.recordCompletedTrip(), isTrue);
  });

  test('consumed schema 2 migrates once without an immediate second prompt',
      () async {
    const legacy = '{"schema":2,"completedTrips":3,"requestAttempted":true}';
    await stateFile().writeAsString(legacy);
    expect((await store.readDiagnostics()).requestAttempted, isTrue);
    expect(await stateFile().readAsString(), legacy);
    expect(await store.recordCompletedTrip(), isFalse);
    final migrated = await state();
    expect(migrated['schema'], 3);
    expect((migrated['attempts'] as List).single['at'], now.toIso8601String());
    now = now.add(const Duration(days: 29));
    store = newStore();
    version = '3.2.3';
    expect(await store.recordCompletedTrip(), isFalse);
    expect(await store.recordCompletedTrip(), isFalse);
    now = now.add(const Duration(days: 1));
    expect(await store.recordCompletedTrip(), isTrue);
    await store.requestIfEligible(canRequest: () => true, request: () async {});
    expect((await state())['attempts'], hasLength(2));
  });

  test('unconsumed schema 2 retains trips without inventing an attempt',
      () async {
    await stateFile().writeAsString(
        '{"schema":2,"completedTrips":2,"requestAttempted":false}');
    expect(await store.recordCompletedTrip(), isTrue);
    expect((await state())['attempts'], isEmpty);
  });

  test('version failure keeps trip count and can recover without an attempt',
      () async {
    await qualify();
    store = AppReviewStore(
        directoryProvider: () async => directory,
        now: () => now,
        versionProvider: () async => throw StateError('version unavailable'));
    await expectLater(store.recordCompletedTrip(), throwsStateError);
    expect((await state())['completedTrips'], 4);
    await expectLater(
        store.requestIfEligible(
            canRequest: () => true, request: () async => fail('no version')),
        throwsStateError);
    expect((await state())['attempts'], isEmpty);
    store = newStore();
    await store.requestIfEligible(canRequest: () => true, request: () async {});
    expect((await state())['attempts'], hasLength(1));
  });

  test('interaction during version lookup cannot reserve a stale request',
      () async {
    await qualify();
    final lookup = Completer<String>();
    final entered = Completer<void>();
    store = AppReviewStore(
        directoryProvider: () async => directory,
        now: () => now,
        versionProvider: () {
          entered.complete();
          return lookup.future;
        });
    var idle = true;
    final pending = store.requestIfEligible(
        canRequest: () => idle, request: () async => fail('cancelled'));
    await entered.future;
    idle = false;
    lookup.complete(version);
    await pending;
    expect((await state())['attempts'], isEmpty);
    store = newStore();
    await store.requestIfEligible(canRequest: () => true, request: () async {});
    expect((await state())['attempts'], hasLength(1));
  });

  test('a native failure consumes only that opportunity; later use recovers',
      () async {
    await qualify();
    await expectLater(
        store.requestIfEligible(
            canRequest: () => true,
            request: () async => throw StateError('native failure')),
        throwsStateError);
    now = now.add(const Duration(days: 30));
    version = '3.2.3';
    await qualify();
    await store.requestIfEligible(canRequest: () => true, request: () async {});
    expect((await state())['attempts'], hasLength(2));
  });

  for (final contents in [
    '{',
    '[]',
    '{"schema":3,"completedTrips":3,"requestAttempted":false}',
    '{"schema":1,"completedTrips":-1,"requestAttempted":false}',
    '{"schema":1,"completedTrips":4,"requestAttempted":false}',
    '{"schema":1,"completedTrips":3}',
    '{"schema":3,"completedTrips":3,"attempts":[{}]}',
    '{"schema":3,"completedTrips":3,"attempts":[{"at":"invalid","version":"3.2.2","completedTrips":3}]}',
    '{"schema":3,"completedTrips":3,"attempts":[{"at":"2026-01-01T00:00:00Z","version":"","completedTrips":3}]}',
    '{"schema":3,"completedTrips":3,"attempts":[{"at":"2026-01-01T00:00:00Z","version":"3.2.2","completedTrips":4}]}',
  ]) {
    test('corrupt/unknown state stays intact and can recover: $contents',
        () async {
      await stateFile().writeAsString(contents);
      await expectLater(store.recordCompletedTrip(), throwsFormatException);
      await expectLater(
          store.requestIfEligible(
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
