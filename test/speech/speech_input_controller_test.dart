import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/speech/speech_input_controller.dart';
import 'package:munich_ways/speech/speech_input_engine.dart';

void main() {
  late _Engine engine;
  late SpeechInputController controller;

  setUp(() {
    engine = _Engine();
    controller = SpeechInputController(engine: engine);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
  });
  tearDown(() => controller.dispose());

  testWidgets('construction does not initialize or request microphone access',
      (tester) async {
    await tester.pump();
    expect(engine.initializations, 0);
    expect(controller.state, SpeechInputState.ready);
    expect(controller.isBusy, isFalse);
  });

  testWidgets('previews partial text and returns only one final result',
      (tester) async {
    final result = controller.start(localeId: 'de-DE');
    await tester.pump();
    expect(controller.state, SpeechInputState.listening);
    expect(engine.sessions.single.locale, 'de_DE');
    engine.current.result('Rosenheimer', false);
    expect(controller.partialText, 'Rosenheimer');
    expect(controller.isBusy, isTrue);
    engine.current.result(' Rosenheimer Straße 145 ', true);
    engine.current.result('Duplicate must be ignored', true);
    engine.current.status(SpeechInputStatus.done);
    await tester.pump();
    expect(await result, 'Rosenheimer Straße 145');
    expect(controller.partialText, 'Rosenheimer Straße 145');
    expect(controller.state, SpeechInputState.ready);
    expect(engine.cancels, 1);
  });

  testWidgets('stop waits for final text, notListening does not discard it',
      (tester) async {
    final result = controller.start(localeId: 'de');
    await tester.pump();
    engine.current.result('Marien', false);
    await controller.stop();
    engine.current.status(SpeechInputStatus.notListening);
    expect(controller.state, SpeechInputState.processing);
    expect(controller.isBusy, isTrue);
    engine.current.result('Marienplatz', true);
    await tester.pump();
    expect(await result, 'Marienplatz');
    expect(engine.stops, 1);
  });

  testWidgets(
      'cancel drops partial and late results, then allows a new session',
      (tester) async {
    final first = controller.start(localeId: 'de-DE');
    await tester.pump();
    final oldSession = engine.current;
    oldSession.result('Old preview', false);
    await controller.cancel();
    expect(await first, isNull);
    expect(controller.partialText, isEmpty);

    final second = controller.start(localeId: 'en-US');
    await tester.pump();
    oldSession.result('Old destination', true);
    oldSession.error(SpeechInputFailure.network);
    oldSession.status(SpeechInputStatus.done);
    expect(controller.state, SpeechInputState.listening);
    expect(controller.failure, isNull);
    engine.current.result('English Garden', true);
    await tester.pump();
    expect(await second, 'English Garden');
  });

  testWidgets('cancel during final grace discards text and cancels fallback',
      (tester) async {
    final result = controller.start(localeId: 'de-DE');
    await tester.pump();
    engine.current.result('Lindwurmstraße 88', false);
    engine.current.status(SpeechInputStatus.done);
    await tester.pump(const Duration(seconds: 1));
    await controller.cancel();
    await tester.pump(const Duration(seconds: 4));
    expect(await result, isNull);
    expect(controller.partialText, isEmpty);
    expect(controller.failure, isNull);
    expect(controller.isBusy, isFalse);
    expect(engine.cancels, 1);
  });

  testWidgets('double start and start during cleanup cannot overlap sessions',
      (tester) async {
    final first = controller.start(localeId: 'de');
    expect(await controller.start(localeId: 'en'), isNull);
    await tester.pump();
    engine.cancelGate = Completer<void>();
    final cancellation = controller.cancel();
    await tester.pump();
    expect(controller.state, SpeechInputState.cancelling);
    expect(await controller.start(localeId: 'de'), isNull);
    expect(engine.sessions.length, 1);
    engine.cancelGate!.complete();
    await tester.pump();
    await cancellation;
    expect(await first, isNull);
    expect(controller.isBusy, isFalse);
  });

  testWidgets('cancel during permission request never starts listening',
      (tester) async {
    engine.initializeGate = Completer<SpeechInputAvailability>();
    final result = controller.start(localeId: 'de');
    final cancellation = controller.cancel();
    engine.initializeGate!.complete(SpeechInputAvailability.available);
    await tester.pump();
    await cancellation;
    expect(await result, isNull);
    expect(engine.sessions, isEmpty);
    expect(controller.state, SpeechInputState.ready);
  });

  for (final availability in [
    SpeechInputAvailability.permissionDenied,
    SpeechInputAvailability.unavailable,
  ]) {
    testWidgets('$availability is reported and can recover on explicit retry',
        (tester) async {
      engine.availability = availability;
      final first = controller.start(localeId: 'de');
      await tester.pump();
      expect(await first, isNull);
      expect(
          controller.failure,
          availability == SpeechInputAvailability.permissionDenied
              ? SpeechInputFailure.permissionDenied
              : SpeechInputFailure.unavailable);
      expect(engine.sessions, isEmpty);
      engine.availability = SpeechInputAvailability.available;
      final retry = controller.start(localeId: 'de');
      await tester.pump();
      engine.current.result('Odeonsplatz', true);
      await tester.pump();
      expect(await retry, 'Odeonsplatz');
      expect(controller.failure, isNull);
    });
  }

  testWidgets('unsupported language does not silently select another language',
      (tester) async {
    final result = controller.start(localeId: 'fr-FR');
    await tester.pump();
    expect(await result, isNull);
    expect(controller.failure, SpeechInputFailure.languageUnavailable);
    expect(engine.sessions, isEmpty);
  });

  testWidgets('same-language locale fallback retains the device locale ID',
      (tester) async {
    engine.supportedLocales = ['de_AT'];
    final result = controller.start(localeId: 'de-DE');
    await tester.pump();
    expect(engine.current.locale, 'de_AT');
    await controller.cancel();
    expect(await result, isNull);
  });

  testWidgets('no result and empty final text are recoverable noMatch failures',
      (tester) async {
    final first = controller.start(localeId: 'de');
    await tester.pump();
    engine.current.status(SpeechInputStatus.done);
    await tester.pump();
    expect(await first, isNull);
    expect(controller.failure, SpeechInputFailure.noMatch);
    final second = controller.start(localeId: 'de');
    await tester.pump();
    engine.current.result('  ', true);
    await tester.pump();
    expect(await second, isNull);
    expect(controller.failure, SpeechInputFailure.noMatch);
  });

  testWidgets('transient network error releases the session and retry succeeds',
      (tester) async {
    final first = controller.start(localeId: 'de');
    await tester.pump();
    engine.current.error(SpeechInputFailure.network);
    await tester.pump();
    expect(await first, isNull);
    expect(controller.failure, SpeechInputFailure.network);
    final retry = controller.start(localeId: 'de');
    await tester.pump();
    engine.current.result('Isartor', true);
    await tester.pump();
    expect(await retry, 'Isartor');
  });

  for (final ending in ['done', 'noMatch', 'emptyFinal']) {
    testWidgets(
        'retains recognized destination after $ending and can listen again',
        (tester) async {
      final result = controller.start(localeId: 'de');
      await tester.pump();
      engine.current.result('Lindwurmstraße 88', false);
      engine.current.status(SpeechInputStatus.notListening);
      switch (ending) {
        case 'done':
          engine.current.status(SpeechInputStatus.done);
        case 'noMatch':
          engine.current.error(SpeechInputFailure.noMatch);
        case 'emptyFinal':
          engine.current.result('', true);
      }
      await tester.pump(const Duration(seconds: 4));
      expect(await result, 'Lindwurmstraße 88');
      expect(controller.failure, isNull);
      expect(engine.cancels, 1);
      final retry = controller.start(localeId: 'de');
      await tester.pump();
      engine.current.result('Marienplatz', true);
      await tester.pump();
      expect(await retry, 'Marienplatz');
    });
  }

  testWidgets('final correction after done takes precedence over preview',
      (tester) async {
    final result = controller.start(localeId: 'de');
    await tester.pump();
    engine.current.result('Lindwurmstraße 8', false);
    engine.current.status(SpeechInputStatus.done);
    await tester.pump(const Duration(milliseconds: 200));
    engine.current.result('Lindwurmstraße 88', true);
    await tester.pump();
    expect(await result, 'Lindwurmstraße 88');
  });

  testWidgets('technical failure does not accept partial text', (tester) async {
    final result = controller.start(localeId: 'de');
    await tester.pump();
    engine.current.result('Lindwurmstraße 88', false);
    engine.current.error(SpeechInputFailure.network);
    await tester.pump();
    expect(await result, isNull);
    expect(controller.failure, SpeechInputFailure.network);
  });

  testWidgets('failed completion retains preview for explicit use and retry',
      (tester) async {
    final result = controller.start(localeId: 'de');
    await tester.pump();
    final session = engine.current;
    session.result('Lindwurmstraße 88', false);
    engine.cancelGate = Completer<void>();
    session.error(SpeechInputFailure.unknown);
    await tester.pump();
    expect(controller.isBusy, isTrue);
    engine.cancelGate!.complete();
    await tester.pump();
    expect(await result, isNull);
    expect(controller.failure, SpeechInputFailure.unknown);
    expect(controller.partialText, 'Lindwurmstraße 88');
    expect(controller.isBusy, isFalse);
    session.result('Late correction', true);
    expect(controller.partialText, 'Lindwurmstraße 88');

    final retry = controller.start(localeId: 'de');
    expect(controller.partialText, isEmpty);
    await tester.pump();
    engine.current.result('Marienplatz', true);
    await tester.pump();
    expect(await retry, 'Marienplatz');
    expect(controller.failure, isNull);
  });

  testWidgets('cleanup failure retains recognized text without accepting it',
      (tester) async {
    final result = controller.start(localeId: 'de');
    await tester.pump();
    engine.cancelFails = true;
    engine.current.result('Lindwurmstraße 88', true);
    await tester.pump();
    expect(await result, isNull);
    expect(controller.failure, SpeechInputFailure.audio);
    expect(controller.partialText, 'Lindwurmstraße 88');
    expect(controller.isBusy, isFalse);
  });

  testWidgets('missing final callback retains text but never accepts it',
      (tester) async {
    final result = controller.start(localeId: 'de');
    await tester.pump();
    engine.current.result('Unfinished', false);
    await controller.stop();
    await tester.pump(const Duration(seconds: 4));
    expect(await result, isNull);
    expect(controller.failure, SpeechInputFailure.timeout);
    expect(controller.partialText, 'Unfinished');
  });

  testWidgets('silent engine has a bounded session and recovers on retry',
      (tester) async {
    final result = controller.start(localeId: 'de');
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(await result, isNull);
    expect(controller.failure, SpeechInputFailure.timeout);
    final retry = controller.start(localeId: 'de');
    await tester.pump();
    engine.current.result('Sendlinger Tor', true);
    await tester.pump();
    expect(await retry, 'Sendlinger Tor');
  });

  testWidgets('initialization exceptions and timeouts leave no loading lock',
      (tester) async {
    engine.initializeGate = Completer<SpeechInputAvailability>();
    final first = controller.start(localeId: 'de');
    engine.initializeGate!.completeError(StateError('No platform'));
    await tester.pump();
    expect(await first, isNull);
    expect(controller.failure, SpeechInputFailure.unavailable);
    engine.initializeGate = Completer<SpeechInputAvailability>();
    final second = controller.start(localeId: 'de');
    await tester.pump(const Duration(seconds: 60));
    expect(await second, isNull);
    expect(controller.failure, SpeechInputFailure.timeout);
    engine.initializeGate!.complete(SpeechInputAvailability.available);
    await tester.pump();
    expect(engine.sessions, isEmpty);
    expect(controller.isBusy, isFalse);
  });

  testWidgets('permission dialog inactivity waits for foreground before listen',
      (tester) async {
    engine.initializeGate = Completer<SpeechInputAvailability>();
    final result = controller.start(localeId: 'de');
    controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
    engine.initializeGate!.complete(SpeechInputAvailability.available);
    await tester.pump();
    expect(engine.sessions, isEmpty);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(engine.sessions.length, 1);
    engine.current.result('Hauptbahnhof', true);
    await tester.pump();
    expect(await result, 'Hauptbahnhof');
  });

  testWidgets('interruption while microphone is starting cancels the session',
      (tester) async {
    engine.announceListening = false;
    final result = controller.start(localeId: 'de');
    await tester.pump();
    expect(engine.sessions.length, 1);
    controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    expect(await result, isNull);
    expect(engine.cancels, 1);
  });

  testWidgets('cancel waits for pending stop before releasing the microphone',
      (tester) async {
    final result = controller.start(localeId: 'de');
    await tester.pump();
    engine.stopGate = Completer<void>();
    final stopping = controller.stop();
    final cancelling = controller.cancel();
    await tester.pump();
    expect(engine.cancels, 0);
    expect(await controller.start(localeId: 'de'), isNull);
    engine.stopGate!.complete();
    await tester.pump();
    await stopping;
    await cancelling;
    expect(await result, isNull);
    expect(engine.cancels, 1);
  });

  testWidgets('background cancels and does not restart on resume',
      (tester) async {
    final result = controller.start(localeId: 'de');
    await tester.pump();
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(await result, isNull);
    expect(await controller.start(localeId: 'de'), isNull);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(engine.sessions.length, 1);
    expect(controller.state, SpeechInputState.ready);
  });

  testWidgets('stop errors and cancellation errors do not block later retries',
      (tester) async {
    final first = controller.start(localeId: 'de');
    await tester.pump();
    engine.stopFails = true;
    await controller.stop();
    expect(await first, isNull);
    expect(controller.failure, SpeechInputFailure.audio);
    engine.cancelFails = true;
    final second = controller.start(localeId: 'de');
    await tester.pump();
    await controller.cancel();
    expect(await second, isNull);
    expect(controller.isBusy, isFalse);
    engine.cancelFails = false;
    final third = controller.start(localeId: 'de');
    await tester.pump();
    engine.current.result('Westpark', true);
    await tester.pump();
    expect(await third, 'Westpark');
  });

  testWidgets('dispose invalidates callbacks and releases microphone',
      (tester) async {
    final disposableEngine = _Engine();
    final disposable = SpeechInputController(engine: disposableEngine);
    disposable.didChangeAppLifecycleState(AppLifecycleState.resumed);
    final result = disposable.start(localeId: 'de');
    await tester.pump();
    disposable.dispose();
    disposableEngine.current.result('Too late', true);
    await tester.pump();
    expect(await result, isNull);
    expect(disposableEngine.cancels, 1);
    expect(await disposable.start(localeId: 'de'), isNull);
  });
}

class _Session {
  _Session(this.locale, this.result, this.status, this.error);
  final String locale;
  final void Function(String, bool) result;
  final void Function(SpeechInputStatus) status;
  final void Function(SpeechInputFailure) error;
}

class _Engine implements SpeechInputEngine {
  int initializations = 0;
  int stops = 0;
  int cancels = 0;
  bool stopFails = false;
  bool cancelFails = false;
  bool announceListening = true;
  SpeechInputAvailability availability = SpeechInputAvailability.available;
  List<String> supportedLocales = ['de_DE', 'en-US'];
  Completer<SpeechInputAvailability>? initializeGate;
  Completer<void>? cancelGate;
  Completer<void>? stopGate;
  final sessions = <_Session>[];
  _Session get current => sessions.last;

  @override
  Future<SpeechInputAvailability> initialize() async {
    initializations++;
    return initializeGate == null ? availability : await initializeGate!.future;
  }

  @override
  Future<List<String>> locales() async => supportedLocales;

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    required void Function(SpeechInputStatus status) onStatus,
    required void Function(SpeechInputFailure failure) onError,
  }) async {
    sessions.add(_Session(localeId, onResult, onStatus, onError));
    if (announceListening) onStatus(SpeechInputStatus.listening);
  }

  @override
  Future<void> stop() async {
    stops++;
    if (stopFails) throw StateError('Audio interrupted');
    await stopGate?.future;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    if (cancelFails) throw StateError('Audio unavailable');
    await cancelGate?.future;
  }
}
