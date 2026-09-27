/// Platform-independent boundary for a single, short speech session.
enum SpeechInputAvailability { available, permissionDenied, unavailable }

enum SpeechInputFailure {
  permissionDenied,
  unavailable,
  languageUnavailable,
  noMatch,
  timeout,
  network,
  audio,
  busy,
  unknown,
}

enum SpeechInputStatus { listening, notListening, done }

abstract interface class SpeechInputEngine {
  /// May request permission. Called only after an explicit user action.
  Future<SpeechInputAvailability> initialize();
  Future<List<String>> locales();

  Future<void> listen({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    required void Function(SpeechInputStatus status) onStatus,
    required void Function(SpeechInputFailure failure) onError,
  });

  /// Stops recording but allows the final recognition result to arrive.
  Future<void> stop();

  /// Discards the result and releases the recording resources.
  Future<void> cancel();
}
