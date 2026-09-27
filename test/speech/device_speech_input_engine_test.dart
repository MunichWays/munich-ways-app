import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:munich_ways/speech/device_speech_input_engine.dart';
import 'package:munich_ways/speech/speech_input_controller.dart';
import 'package:munich_ways/speech/speech_input_engine.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  late DeviceSpeechInputEngine engine;
  late List<MethodCall> calls;
  bool initialized = true;
  bool permission = true;

  Future<void> event(String method, Object data) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, data)),
      (_) {},
    );
  }

  setUp(() {
    calls = [];
    initialized = true;
    permission = true;
    engine = DeviceSpeechInputEngine(speech: SpeechToText.withMethodChannel());
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => initialized,
        'has_permission' => permission,
        'locales' => ['de_DE:Deutsch', 'en_US:English'],
        _ => true,
      };
    });
  });
  tearDown(() async {
    await engine.cancel();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('initializes once without Bluetooth or debug recording logs', () async {
    expect(await engine.initialize(), SpeechInputAvailability.available);
    expect(await engine.initialize(), SpeechInputAvailability.available);
    final initialization = calls.where((call) => call.method == 'initialize');
    expect(initialization.length, 1);
    expect(initialization.single.arguments['noBluetooth'], isTrue);
    expect(initialization.single.arguments['debugLogging'], isFalse);
    expect(await engine.locales(), ['de_DE', 'en_US']);
  });

  test('distinguishes denied permission, unavailable service and recovery',
      () async {
    initialized = false;
    permission = false;
    expect(await engine.initialize(), SpeechInputAvailability.permissionDenied);
    permission = true;
    expect(await engine.initialize(), SpeechInputAvailability.unavailable);
    initialized = true;
    expect(await engine.initialize(), SpeechInputAvailability.available);
    permission = false;
    expect(await engine.initialize(), SpeechInputAvailability.permissionDenied);
  });

  test('forwards results and status and discards callbacks after cancellation',
      () async {
    await engine.initialize();
    final results = <String>[];
    final statuses = <SpeechInputStatus>[];
    final failures = <SpeechInputFailure>[];
    await engine.listen(
      localeId: 'de_DE',
      onResult: (text, isFinal) => results.add('$isFinal:$text'),
      onStatus: statuses.add,
      onError: failures.add,
    );
    final options = calls.last.arguments as Map;
    expect(options['localeId'], 'de_DE');
    expect(options['listenMode'], ListenMode.search.index);
    expect(options['listenFor'], 15000);
    await event('notifyStatus', 'listening');
    await event(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': 'Marienplatz', 'confidence': 0.9}
          ],
          'resultType': 0,
        }));
    expect(results, ['false:Marienplatz']);
    expect(statuses, [SpeechInputStatus.listening]);
    await engine.cancel();
    await event(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': 'Too late', 'confidence': 0.9}
          ],
          'resultType': 2,
        }));
    await event('notifyStatus', 'done');
    expect(results, ['false:Marienplatz']);
    expect(statuses, [SpeechInputStatus.listening]);
    expect(failures, isEmpty);
  });

  testWidgets(
      'Android intermediate result followed by done retains destination',
      (tester) async {
    final controller = SpeechInputController(engine: engine);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    addTearDown(controller.dispose);
    final result = controller.start(localeId: 'de-DE');
    await tester.pump();
    await event('notifyStatus', 'listening');
    await event(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': 'Lindwurmstraße 88', 'confidence': 0.9}
          ],
          // Android onPartialResults may set final_result=true. The plugin maps
          // this to intermediate (1), allowing done through before a final result.
          'resultType': 1,
        }));
    expect(controller.partialText, 'Lindwurmstraße 88');
    await event('notifyStatus', 'notListening');
    await event('notifyStatus', 'done');
    await tester.pump(const Duration(seconds: 4));
    expect(await result, 'Lindwurmstraße 88');
    expect(controller.failure, isNull);
  });

  testWidgets('late client error after done preserves successful recognition',
      (tester) async {
    final messages = <String>[];
    void capture(LogEvent event) => messages.add(event.message.toString());
    Logger.addLogListener(capture);
    addTearDown(() => Logger.removeLogListener(capture));
    final controller = SpeechInputController(engine: engine);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    addTearDown(controller.dispose);
    final result = controller.start(localeId: 'de-DE');
    await tester.pump();
    await event('notifyStatus', 'listening');
    await event(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': 'Lindwurmstraße 88', 'confidence': 0.9}
          ],
          'resultType': 1,
        }));
    await event('notifyStatus', 'notListening');
    await event('notifyStatus', 'done');
    await event('notifyError',
        jsonEncode({'errorMsg': 'error_client', 'permanent': true}));
    await tester.pump(const Duration(seconds: 4));
    expect(await result, 'Lindwurmstraße 88');
    expect(controller.failure, isNull);
    expect(controller.partialText, 'Lindwurmstraße 88');
    expect(messages.join('\n'), contains('native error=error_client'));
    expect(messages.join('\n'), isNot(contains('Lindwurmstraße')));
    expect(messages.join('\n'), contains('hasText=true'));

    final retry = controller.start(localeId: 'de-DE');
    await tester.pump();
    await event('notifyStatus', 'listening');
    await event(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': 'Marienplatz', 'confidence': 0.9}
          ],
          'resultType': 2,
        }));
    await tester.pump();
    expect(await retry, 'Marienplatz');
    expect(controller.failure, isNull);
    expect(messages.join('\n'), isNot(contains('Marienplatz')));
  });

  for (final cancel in [false, true]) {
    testWidgets(
        'redundant stop error still allows ${cancel ? 'cancellation' : 'final correction'}',
        (tester) async {
      final controller = SpeechInputController(engine: engine);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      addTearDown(controller.dispose);
      final result = controller.start(localeId: 'de-DE');
      await tester.pump();
      await event('notifyStatus', 'listening');
      await event(
          'textRecognition',
          jsonEncode({
            'alternates': [
              {'recognizedWords': 'Lindwurmstraße 8', 'confidence': 0.9}
            ],
            'resultType': 1,
          }));
      await event('notifyStatus', 'notListening');
      await event('notifyStatus', 'done');
      await event('notifyError',
          jsonEncode({'errorMsg': 'error_client', 'permanent': true}));
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.isBusy, isTrue);
      if (cancel) await controller.cancel();
      await event(
          'textRecognition',
          jsonEncode({
            'alternates': [
              {'recognizedWords': 'Lindwurmstraße 88', 'confidence': 0.9}
            ],
            'resultType': 2,
          }));
      await tester.pump(const Duration(seconds: 4));
      expect(await result, cancel ? isNull : 'Lindwurmstraße 88');
      expect(controller.failure, isNull);
      expect(controller.isBusy, isFalse);
    });
  }

  for (final scenario in [
    (code: 'error_client', done: false, words: 'Lindwurmstraße 88'),
    (code: 'error_client', done: true, words: ''),
    (code: 'error_network', done: true, words: 'Lindwurmstraße 88'),
    (code: 'error_permission', done: true, words: 'Lindwurmstraße 88'),
    (code: 'error_unknown (99)', done: true, words: 'Lindwurmstraße 88'),
  ]) {
    test('forwards native failure outside redundant stop case: $scenario',
        () async {
      final failures = <SpeechInputFailure>[];
      await engine.initialize();
      await engine.listen(
        localeId: 'de_DE',
        onResult: (_, __) {},
        onStatus: (_) {},
        onError: failures.add,
      );
      await event('notifyStatus', 'listening');
      await event(
          'textRecognition',
          jsonEncode({
            'alternates': [
              {'recognizedWords': scenario.words, 'confidence': 0.9}
            ],
            'resultType': 1,
          }));
      if (scenario.done) {
        await event('notifyStatus', 'notListening');
        await event('notifyStatus', 'done');
      }
      await event('notifyError',
          jsonEncode({'errorMsg': scenario.code, 'permanent': true}));
      expect(failures, [DeviceSpeechInputEngine.mapError(scenario.code)]);
    });
  }

  test('diagnostics exclude arbitrary native error messages', () async {
    final messages = <String>[];
    void capture(LogEvent event) => messages.add(event.message.toString());
    Logger.addLogListener(capture);
    addTearDown(() => Logger.removeLogListener(capture));
    await engine.initialize();
    await engine.listen(
      localeId: 'de_DE',
      onResult: (_, __) {},
      onStatus: (_) {},
      onError: (_) {},
    );
    await event('notifyError',
        jsonEncode({'errorMsg': 'error_unknown (99)', 'permanent': true}));
    await event(
        'notifyError',
        jsonEncode(
            {'errorMsg': 'error_client: private words', 'permanent': true}));
    expect(messages.join('\n'), contains('native error=error_unknown (99)'));
    expect(messages.join('\n'), contains('native error=unrecognized_code'));
    expect(messages.join('\n'), isNot(contains('private words')));
  });

  test('maps native errors without forwarding raw platform messages', () async {
    await engine.initialize();
    final failures = <SpeechInputFailure>[];
    await engine.listen(
      localeId: 'de_DE',
      onResult: (_, __) {},
      onStatus: (_) {},
      onError: failures.add,
    );
    await event('notifyStatus', 'listening');
    await event(
        'notifyError',
        jsonEncode({
          'errorMsg': 'error_network',
          'permanent': false,
        }));
    expect(failures, [SpeechInputFailure.network]);
    expect(
        DeviceSpeechInputEngine.mapError(
            'error_speech_recognizer_request_not_authorized'),
        SpeechInputFailure.permissionDenied);
    expect(DeviceSpeechInputEngine.mapError('error_assets_not_installed'),
        SpeechInputFailure.languageUnavailable);
    expect(DeviceSpeechInputEngine.mapError('error_speech_recognizer_disabled'),
        SpeechInputFailure.unavailable);
  });
}
