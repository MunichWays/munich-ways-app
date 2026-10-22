import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Owns the screen wake lock, independently of GPS, speech and camera follow.
/// Navigation state stays authoritative in the model and is read when work runs.
class NavigationScreenAwake with WidgetsBindingObserver {
  NavigationScreenAwake({
    required bool Function() navigationActive,
    Future<void> Function(bool)? setEnabled,
  })  : _navigationActive = navigationActive,
        _setEnabled = setEnabled ?? _toggle {
    WidgetsBinding.instance.addObserver(this);
  }

  final bool Function() _navigationActive;
  final Future<void> Function(bool) _setEnabled;
  Future<void> _work = Future<void>.value();
  int _revision = 0;
  bool? _lastApplied = false;
  bool _forceReapply = false;
  bool _disposed = false;

  static Future<void> _toggle(bool enabled) =>
      WakelockPlus.toggle(enable: enabled);

  Future<void> synchronize({bool force = false}) {
    final revision = ++_revision;
    _forceReapply = _forceReapply || force;
    // Serialize native calls and coalesce obsolete queued work. A late enable
    // must finish before the release requested by pause/end/disposal is sent.
    return _work = _work.then((_) async {
      if (revision != _revision) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final wanted = !_disposed &&
          _navigationActive() &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed);
      if (!_forceReapply && _lastApplied == wanted) return;
      _forceReapply = false;
      try {
        // The platform plugin checks the native flag, including when the OS
        // has released it since our previous request.
        await _setEnabled(wanted);
        _lastApplied = wanted;
      } catch (error, stackTrace) {
        _lastApplied = null;
        log.w('Updating navigation screen wake lock failed',
            error: error, stackTrace: stackTrace);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(synchronize(force: state == AppLifecycleState.resumed));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(synchronize());
  }
}
