import 'dart:async';

/// Keeps a due warning pending while movement or a fresh GPS fix is missing.
/// The next location update can deliver it without starting another delay.
class OffRouteAnnouncement {
  Timer? _timer;
  bool Function()? _announceIfReady;

  void schedule(Duration delay, bool Function() announceIfReady) {
    cancel();
    _announceIfReady = announceIfReady;
    _timer = Timer(delay, _attempt);
  }

  void retryIfDue() {
    if (_timer?.isActive == false) _attempt();
  }

  void _attempt() {
    if (_announceIfReady?.call() == true) cancel();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _announceIfReady = null;
  }
}
