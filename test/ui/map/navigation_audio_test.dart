import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:munich_ways/ui/map/navigation_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _IosTts tts;

  setUp(() {
    tts = _IosTts();
  });

  Future<int> prompt() async {
    final ready = await prepareIosNavigationAudio(tts, isCurrent: () => true);
    expect(ready, isTrue);
    return await tts.speak('Test') as int;
  }

  test('iOS initialization succeeds without unsupported Android methods',
      () async {
    await initializeNavigationAudio(tts, android: false);
    expect(tts.calls, ['setVolume']);
    expect(await prompt(), 1);
  });

  test('Android retains queue flushing and navigation audio attributes',
      () async {
    tts = _IosTts(android: true);
    await initializeNavigationAudio(tts, android: true);
    expect(tts.calls,
        ['setVolume', 'setQueueMode', 'setAudioAttributesForNavigation']);
  });

  test('reactivates for the next prompt after the plugin releases audio',
      () async {
    expect(await prompt(), 1);
    expect(tts.active, isFalse);
    expect(await prompt(), 1);
    expect(tts.calls, [
      'setIosAudioCategory',
      'setSharedInstance',
      'speak',
      'setIosAudioCategory',
      'setSharedInstance',
      'speak',
    ]);
  });

  test('activation failure is reported and the next prompt can recover',
      () async {
    tts.failActivation = true;
    await expectLater(prompt(), throwsStateError);
    expect(tts.calls, isNot(contains('speak')));
    tts.failActivation = false;
    expect(await prompt(), 1);
  });

  test('configuration failure prevents activation and permits retry', () async {
    tts.failConfiguration = true;
    await expectLater(prompt(), throwsStateError);
    expect(tts.calls, ['setIosAudioCategory']);
    tts.failConfiguration = false;
    expect(await prompt(), 1);
  });

  test('ending navigation during configuration prevents activation', () async {
    tts.configureGate = Completer<void>();
    var current = true;
    final pending = prepareIosNavigationAudio(tts, isCurrent: () => current);
    await Future<void>.delayed(Duration.zero);
    current = false;
    tts.configureGate!.complete();
    expect(await pending, isFalse);
    expect(tts.calls, ['setIosAudioCategory']);
  });

  test('an obsolete prompt does not change the audio session', () async {
    expect(
        await prepareIosNavigationAudio(tts, isCurrent: () => false), isFalse);
    expect(tts.calls, isEmpty);
  });
}

// Model iOS plugin behavior without requiring iOS on the test host.
class _IosTts extends FlutterTts {
  _IosTts({this.android = false});
  final bool android;
  bool active = false;
  bool failActivation = false;
  bool failConfiguration = false;
  final calls = <String>[];
  Completer<void>? configureGate;

  @override
  Future<dynamic> setVolume(double volume) async {
    calls.add('setVolume');
    expect(volume, 1.0);
    return 1;
  }

  @override
  Future<dynamic> setQueueMode(int mode) async {
    calls.add('setQueueMode');
    if (!android)
      throw MissingPluginException('setQueueMode unsupported on iOS');
    expect(mode, 0);
    return 1;
  }

  @override
  Future<dynamic> setAudioAttributesForNavigation() async {
    calls.add('setAudioAttributesForNavigation');
    if (!android)
      throw MissingPluginException('Android audio attributes on iOS');
    return 1;
  }

  @override
  Future<dynamic> setIosAudioCategory(IosTextToSpeechAudioCategory category,
      List<IosTextToSpeechAudioCategoryOptions> options,
      [IosTextToSpeechAudioMode mode =
          IosTextToSpeechAudioMode.defaultMode]) async {
    calls.add('setIosAudioCategory');
    expect(category, IosTextToSpeechAudioCategory.playback);
    expect(mode, IosTextToSpeechAudioMode.voicePrompt);
    expect(
        options,
        containsAll([
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions
              .interruptSpokenAudioAndMixWithOthers,
        ]));
    if (configureGate != null) await configureGate!.future;
    return failConfiguration ? 0 : 1;
  }

  @override
  Future<dynamic> setSharedInstance(bool sharedSession) async {
    calls.add('setSharedInstance');
    expect(sharedSession, isTrue);
    if (failActivation) return 0;
    active = true;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    calls.add('speak');
    // flutter_tts deactivates the shared session when an utterance completes.
    if (!active) return 0;
    active = false;
    return 1;
  }
}
