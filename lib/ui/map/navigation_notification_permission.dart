import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:munich_ways/common/logger_setup.dart';

/// Enables voice guidance only after a new, explicitly granted permission.
/// Already granted notifications must preserve a user's muted navigation.
class NavigationNotificationPermission {
  static const _channel =
      MethodChannel('com.munichways.app/notification_permission');
  bool _explained = false;

  Future<void> request({
    required Future<bool> Function() explain,
    required bool Function() isCurrent,
    required VoidCallback onGranted,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android || !isCurrent()) return;
    try {
      final granted = await _channel.invokeMethod<bool>('isGranted') ?? false;
      if (granted || !isCurrent()) return;

      if (!_explained) {
        final proceed = await explain();
        _explained = true;
        if (!proceed || !isCurrent()) return;
      }
      final newlyGranted =
          await _channel.invokeMethod<bool>('request') ?? false;
      if (newlyGranted && isCurrent()) onGranted();
    } on PlatformException catch (error, stackTrace) {
      log.w(
        'Requesting navigation notification permission failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
