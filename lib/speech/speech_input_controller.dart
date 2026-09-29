import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/speech/device_speech_input_engine.dart';
import 'package:munich_ways/speech/speech_input_engine.dart';

enum SpeechInputState {
  ready,
  initializing,
  listening,
  processing,
  cancelling,
  error
}

/// Owns microphone sessions only; never changes search or navigation state.
///
/// [start] returns one recognized text, or null on cancellation/failure.
/// Partial text is preview-only during recording. A completed recognition may
/// retain it when no final correction arrives. Call [cancel] on view close.
class SpeechInputController extends ChangeNotifier with WidgetsBindingObserver {
  SpeechInputController({
    SpeechInputEngine? engine,
    this.setupTimeout = const Duration(seconds: 60),
    this.operationTimeout = const Duration(seconds: 5),
    this.sessionTimeout = const Duration(seconds: 20),
    this.finalResultTimeout = const Duration(seconds: 4),
  }) : _engine = engine ?? DeviceSpeechInputEngine() {
    WidgetsBinding.instance.addObserver(this);
  }

  final SpeechInputEngine _engine;
  final Duration setupTimeout;
  final Duration operationTimeout;
  final Duration sessionTimeout;
  final Duration finalResultTimeout;
  SpeechInputState _state = SpeechInputState.ready;
  SpeechInputFailure? _failure;
  String _partialText = '';
  int _generation = 0;
  bool _disposed = false;
  bool _inputStarted = false;
  bool _requestingPermission = false;
  Future<void>? _preparation;
  Future<void>? _stopping;
  Future<void>? _cleanup;
  Completer<String?>? _result;
  Completer<void>? _resumed;
  Timer? _sessionTimer;
  Timer? _finalTimer;
  AppLifecycleState? _lifecycle = WidgetsBinding.instance.lifecycleState;

  SpeechInputState get state => _state;
  SpeechInputFailure? get failure => _failure;
  String get partialText => _partialText;
  bool get isBusy => _result != null || _cleanup != null;

  /// Subsequent microphone taps start directly after the first explicit start.
  bool get hasStartedInput => _inputStarted;
  void markInputStarted() => _inputStarted = true;

  /// Explicit foreground user action only. Concurrent requests are ignored.
  Future<String?> start({required String localeId}) {
    if (_disposed || isBusy || !_inForeground) return Future.value(null);
    final result = Completer<String?>();
    _result = result;
    final generation = ++_generation;
    _failure = null;
    _partialText = '';
    _state = SpeechInputState.initializing;
    _preparation = _prepare(generation, localeId);
    _notify();
    return result.future;
  }

  bool get _inForeground =>
      _lifecycle == null || _lifecycle == AppLifecycleState.resumed;

  bool _current(int generation) =>
      !_disposed && generation == _generation && _result != null;

  Future<void> _prepare(int generation, String requestedLocale) async {
    var phase = 'initialize';
    try {
      _requestingPermission = true;
      final availability = await _engine.initialize().timeout(setupTimeout);
      log.d(
          'Speech input: session=$generation availability=${availability.name}');
      _requestingPermission = false;
      if (!_current(generation)) return;
      if (availability != SpeechInputAvailability.available) {
        unawaited(_finish(
          failure: availability == SpeechInputAvailability.permissionDenied
              ? SpeechInputFailure.permissionDenied
              : SpeechInputFailure.unavailable,
        ));
        return;
      }
      phase = 'locales';
      final locales = await _engine.locales().timeout(operationTimeout);
      if (!_current(generation)) return;
      final locale = _selectLocale(requestedLocale, locales);
      if (locale == null) {
        unawaited(_finish(failure: SpeechInputFailure.languageUnavailable));
        return;
      }
      // iOS permission dialogs temporarily make the app inactive. Wait for
      // their dismissal instead of recording behind the permission prompt.
      if (!_inForeground) {
        phase = 'foreground';
        _resumed ??= Completer<void>();
        await _resumed!.future.timeout(setupTimeout);
      }
      if (!_current(generation) || !_inForeground) return;
      _sessionTimer = Timer(sessionTimeout, () {
        if (_current(generation)) {
          unawaited(_finish(failure: SpeechInputFailure.timeout));
        }
      });
      phase = 'listen';
      await _engine
          .listen(
            localeId: locale,
            onResult: (text, isFinal) {
              if (!_current(generation)) return;
              if (text.trim().isNotEmpty) _partialText = text.trim();
              if (isFinal) {
                unawaited(_completeRecognition());
              } else {
                _notify();
              }
            },
            onStatus: (status) => _handleStatus(generation, status),
            onError: (failure) {
              if (!_current(generation)) return;
              log.w('Speech input: session=$generation failure=${failure.name} '
                  'state=${_state.name} hasText=${_partialText.isNotEmpty}');
              if (failure == SpeechInputFailure.noMatch &&
                  _partialText.isNotEmpty) {
                _awaitFinalResult(generation, retainRecognizedText: true);
              } else {
                unawaited(_finish(failure: failure));
              }
            },
          )
          .timeout(operationTimeout);
    } on TimeoutException {
      log.w('Speech input: session=$generation phase=$phase timed out');
      if (_current(generation)) {
        unawaited(_finish(failure: SpeechInputFailure.timeout));
      }
    } catch (error) {
      // Exception messages/details can contain platform-provided content.
      log.w('Speech input: session=$generation phase=$phase '
          'exception=${error.runtimeType}');
      if (_current(generation)) {
        unawaited(_finish(failure: SpeechInputFailure.unavailable));
      }
    }
  }

  static String? _selectLocale(String requested, List<String> available) {
    String normalize(String value) => value.replaceAll('_', '-').toLowerCase();
    final desired = normalize(requested);
    for (final locale in available) {
      if (normalize(locale) == desired) return locale;
    }
    final language = desired.split('-').first;
    for (final locale in available) {
      if (normalize(locale).split('-').first == language) return locale;
    }
    return null;
  }

  void _handleStatus(int generation, SpeechInputStatus status) {
    if (!_current(generation)) return;
    switch (status) {
      case SpeechInputStatus.listening:
        if (_state != SpeechInputState.processing) {
          _state = SpeechInputState.listening;
          _notify();
        }
      case SpeechInputStatus.notListening:
        _awaitFinalResult(generation);
      case SpeechInputStatus.done:
        if (_partialText.isEmpty) {
          unawaited(_finish(failure: SpeechInputFailure.noMatch));
        } else {
          // Android may finish after an intermediate result. Give a late
          // final correction precedence, then retain the editable query.
          _awaitFinalResult(generation, retainRecognizedText: true);
        }
    }
  }

  Future<void> _completeRecognition() => _finish(
        text: _partialText.isEmpty ? null : _partialText,
        failure: _partialText.isEmpty ? SpeechInputFailure.noMatch : null,
      );

  void _awaitFinalResult(int generation, {bool retainRecognizedText = false}) {
    _state = SpeechInputState.processing;
    if (retainRecognizedText) {
      _finalTimer?.cancel();
      _finalTimer = null;
    }
    _finalTimer ??= Timer(finalResultTimeout, () {
      if (_current(generation)) {
        unawaited(retainRecognizedText
            ? _completeRecognition()
            : _finish(failure: SpeechInputFailure.timeout));
      }
    });
    _notify();
  }

  Future<void> stop() {
    if (_state != SpeechInputState.listening) return Future.value();
    final generation = _generation;
    _awaitFinalResult(generation);
    return _stopping = _stopEngine(generation);
  }

  Future<void> _stopEngine(int generation) async {
    try {
      await _engine.stop().timeout(operationTimeout);
    } catch (_) {
      if (_current(generation)) {
        unawaited(_finish(failure: SpeechInputFailure.audio));
      }
    }
  }

  Future<void> cancel() => _finish();

  Future<void> _finish({String? text, SpeechInputFailure? failure}) {
    if (_cleanup != null) return _cleanup!;
    final result = _result;
    if (result == null) return Future.value();
    ++_generation;
    _result = null;
    _sessionTimer?.cancel();
    _finalTimer?.cancel();
    _sessionTimer = null;
    _finalTimer = null;
    _resumed?.complete();
    _resumed = null;
    // A technical failure must not submit an unfinished query automatically,
    // but the dialog can offer the recognized text after cleanup completes.
    // Explicit cancellation still discards it.
    _partialText = text ?? (failure == null ? '' : _partialText);
    _state = SpeechInputState.cancelling;
    // Wait for an in-flight listen before releasing it. A double tap must not
    // start another session while platform setup/cleanup is still running.
    final preparation = _preparation;
    _cleanup = _release(preparation, result, text, failure);
    _notify();
    return _cleanup!;
  }

  Future<void> _release(Future<void>? preparation, Completer<String?> result,
      String? text, SpeechInputFailure? failure) async {
    await preparation;
    // The plugin schedules its final-result timer after stop returns. Cancel
    // only afterwards so that timer cannot leak into the next session.
    await _stopping;
    try {
      await _engine.cancel().timeout(operationTimeout);
    } catch (error) {
      log.w('Speech input: phase=cancel exception=${error.runtimeType}');
      failure ??= SpeechInputFailure.audio;
      text = null;
    }
    _preparation = null;
    _requestingPermission = false;
    _stopping = null;
    _cleanup = null;
    _failure = failure;
    _state = failure == null ? SpeechInputState.ready : SpeechInputState.error;
    log.d('Speech input: completed failure=${failure?.name ?? 'none'} '
        'hasText=${_partialText.isNotEmpty} accepted=${text != null}');
    result.complete(text);
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      _resumed?.complete();
      _resumed = null;
    } else if (state != AppLifecycleState.inactive || !_requestingPermission) {
      unawaited(cancel());
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    unawaited(cancel());
    super.dispose();
  }
}
