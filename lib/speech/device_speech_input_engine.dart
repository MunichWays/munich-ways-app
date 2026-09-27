import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/speech/speech_input_engine.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// The app owns one instance, provided by SpeechInputController.
class DeviceSpeechInputEngine implements SpeechInputEngine {
  DeviceSpeechInputEngine({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  void Function(SpeechInputStatus)? _onStatus;
  void Function(SpeechInputFailure)? _onError;
  int _generation = 0;

  @override
  Future<SpeechInputAvailability> initialize() async {
    if (!_initialized) {
      _initialized = await _speech.initialize(
        // Bluetooth microphone routing is a separate device-tested increment.
        options: [SpeechToText.androidNoBluetooth],
        onStatus: (status) {
          final mapped = switch (status) {
            SpeechToText.listeningStatus => SpeechInputStatus.listening,
            SpeechToText.notListeningStatus => SpeechInputStatus.notListening,
            SpeechToText.doneStatus => SpeechInputStatus.done,
            _ => null,
          };
          if (mapped != null) {
            log.d('Speech input: native status=${mapped.name} '
                'active=${_onStatus != null}');
            _onStatus?.call(mapped);
          }
        },
        onError: (error) {
          final failure = mapError(error.errorMsg);
          // Only structured codes belong in diagnostics, never arbitrary
          // platform error messages (which may contain recognized words).
          final code =
              RegExp(r'^error_[a-z_]+(?: \(-?\d+\))?$').hasMatch(error.errorMsg)
                  ? error.errorMsg
                  : 'unrecognized_code';
          log.w('Speech input: native error=$code mapped=${failure.name} '
              'permanent=${error.permanent} active=${_onError != null}');
          // Android can report ERROR_CLIENT when the plugin's pause timer
          // calls stopListening after recognition has already ended. Preserve
          // the controller's final-result grace period for this exact case.
          // An early client error or any other failure must still be surfaced.
          if (error.errorMsg == 'error_client' &&
              _speech.lastStatus == SpeechToText.doneStatus &&
              _speech.lastRecognizedWords.trim().isNotEmpty) {
            log.d('Speech input: ignoring redundant stop error after done');
            return;
          }
          _onError?.call(failure);
        },
      );
    }
    // Also detects permission revoked in Settings after a successful session.
    if (!await _speech.hasPermission) {
      return SpeechInputAvailability.permissionDenied;
    }
    return _initialized
        ? SpeechInputAvailability.available
        : SpeechInputAvailability.unavailable;
  }

  @override
  Future<List<String>> locales() async =>
      (await _speech.locales()).map((locale) => locale.localeId).toList();

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    required void Function(SpeechInputStatus status) onStatus,
    required void Function(SpeechInputFailure failure) onError,
  }) async {
    final generation = ++_generation;
    _onStatus = onStatus;
    _onError = onError;
    await _speech.listen(
      onResult: (result) {
        if (generation == _generation) {
          log.d('Speech input: native result final=${result.finalResult} '
              'hasText=${result.recognizedWords.trim().isNotEmpty}');
          onResult(result.recognizedWords, result.finalResult);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.search,
        partialResults: true,
        // The controller owns cleanup, including non-permanent errors.
        cancelOnError: false,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() async {
    ++_generation;
    _onStatus = null;
    _onError = null;
    if (_initialized) await _speech.cancel();
  }

  static SpeechInputFailure mapError(String code) => switch (code) {
        'error_permission' ||
        'error_insufficient_permissions' ||
        'error_speech_recognizer_request_not_authorized' =>
          SpeechInputFailure.permissionDenied,
        'error_language_not_supported' ||
        'error_language_unavailable' ||
        'error_assets_not_installed' =>
          SpeechInputFailure.languageUnavailable,
        'error_no_match' => SpeechInputFailure.noMatch,
        'error_speech_timeout' ||
        'error_network_timeout' =>
          SpeechInputFailure.timeout,
        'error_network' ||
        'error_server' ||
        'error_server_disconnected' =>
          SpeechInputFailure.network,
        'error_audio' ||
        'error_audio_error' ||
        'error_listen_failed' =>
          SpeechInputFailure.audio,
        'error_busy' ||
        'error_recognizer_busy' ||
        'error_too_many_requests' ||
        'error_speech_recognizer_already_active' =>
          SpeechInputFailure.busy,
        'error_not_available' ||
        'error_speech_recognizer_disabled' =>
          SpeechInputFailure.unavailable,
        _ => SpeechInputFailure.unknown,
      };
}
