import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Platform stand-in for route lifecycle tests running without a phone.
void stubWakelock() {
  const channel =
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler(channel,
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]));
  addTearDown(() => messenger.setMockMessageHandler(channel, null));
}
