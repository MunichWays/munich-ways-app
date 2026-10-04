import 'package:flutter_tts/flutter_tts.dart';

Future<void> initializeNavigationAudio(
  FlutterTts tts, {
  required bool android,
}) async {
  await tts.setVolume(1.0);
  if (android) {
    // iOS doesn't implement these methods and reports MissingPluginException.
    await tts.setQueueMode(0);
    await tts.setAudioAttributesForNavigation();
  }
}

/// Reapply playback settings after speech input and reactivate before each
/// prompt. flutter_tts releases the shared session when a prompt finishes.
Future<bool> prepareIosNavigationAudio(
  FlutterTts tts, {
  required bool Function() isCurrent,
}) async {
  if (!isCurrent()) return false;
  final configured = await tts.setIosAudioCategory(
    IosTextToSpeechAudioCategory.playback,
    [
      IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers,
      IosTextToSpeechAudioCategoryOptions.duckOthers,
    ],
    IosTextToSpeechAudioMode.voicePrompt,
  );
  if (configured != 1) {
    throw StateError('iOS navigation audio configuration failed');
  }
  if (!isCurrent()) return false;
  final activated = await tts.setSharedInstance(true);
  if (activated != 1) {
    throw StateError('iOS navigation audio activation failed');
  }
  return isCurrent();
}
