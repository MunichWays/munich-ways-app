import 'dart:async';

import 'package:munich_ways/reviews/app_review_service.dart';
import 'package:munich_ways/reviews/app_review_diagnostics.dart';

/// Owns only the optional post-navigation timer, never navigation state.
class AppReviewPromptController {
  AppReviewPromptController({
    required this.service,
    required this.canPrompt,
    this.delay = const Duration(seconds: 2),
  });

  final AppReviewService service;
  final bool Function() canPrompt;
  final Duration delay;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  /// Called exclusively by the orange Finish button after final arrival.
  Future<void> destinationFinished() async {
    cancel();
    if (_disposed) return;
    final generation = _generation;
    final eligible = await service.recordCompletedTrip();
    if (!eligible) return;
    if (!_canPrompt(generation)) {
      service.recordDiagnosticEvent(ReviewDiagnosticEvent.interfaceBusy);
      return;
    }
    service.recordDiagnosticEvent(ReviewDiagnosticEvent.promptScheduled);
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(service.requestAutomaticReview(
          canRequest: () => _canPrompt(generation)));
    });
  }

  bool _canPrompt(int generation) =>
      !_disposed && generation == _generation && canPrompt();

  void cancel() {
    if (_timer?.isActive == true) {
      service.recordDiagnosticEvent(ReviewDiagnosticEvent.promptCancelled);
    }
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
    _disposed = true;
  }
}
