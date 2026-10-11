import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small, independent local state. Nothing is loaded during app startup.
class AppReviewStore {
  AppReviewStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  Future<void> _updates = Future<void>.value();

  static const fileName = 'app_review.json';
  static const requiredTrips = 3;

  /// Read-only snapshot; opening diagnostics never creates or resets state.
  Future<({int completedTrips, bool requestAttempted})>
      readDiagnostics() async {
    final directory = await _directoryProvider();
    // Atomic file replacement gives a complete persisted snapshot, even while
    // the serialized update queue is waiting for the native review to finish.
    final state = await _read(File('${directory.path}/$fileName'));
    return (
      completedTrips: state.completedTrips,
      requestAttempted: state.requestAttempted
    );
  }

  Future<_ReviewState> _read(File file) async => await file.exists()
      ? _ReviewState.fromJson(jsonDecode(await file.readAsString()))
      : const _ReviewState(0, false);

  Future<bool> recordCompletedTrip() => _serialize((file, state) async {
        final count = state.completedTrips < requiredTrips
            ? state.completedTrips + 1
            : requiredTrips;
        if (count != state.completedTrips) {
          await _write(file, _ReviewState(count, state.requestAttempted));
        }
        return count >= requiredTrips && !state.requestAttempted;
      });

  /// Reserve durably before handing off to the native API. Recheck after I/O
  /// so a background transition or new task cannot launch a delayed dialog.
  Future<void> requestOnce({
    required bool Function() canRequest,
    required Future<void> Function() request,
  }) =>
      _serialize((file, state) async {
        if (state.completedTrips < requiredTrips ||
            state.requestAttempted ||
            !canRequest()) return;
        await _write(file, _ReviewState(state.completedTrips, true));
        if (!canRequest()) {
          await _write(file, state);
          return;
        }
        // No await between the last eligibility check and native handoff.
        // A silent dialog suppression or native failure still consumes the try.
        await request();
      });

  Future<T> _serialize<T>(
      Future<T> Function(File file, _ReviewState state) action) {
    final operation = _updates.then((_) async {
      final directory = await _directoryProvider();
      final file = File('${directory.path}/$fileName');
      final state = await _read(file);
      return action(file, state);
    });
    // One failed write must not permanently poison subsequent operations.
    _updates =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<void> _write(File file, _ReviewState state) async {
    final temporary = File('${file.path}.tmp');
    await temporary.create(recursive: true);
    await temporary.writeAsString(
        jsonEncode({
          'schema': 2,
          'completedTrips': state.completedTrips,
          'requestAttempted': state.requestAttempted,
        }),
        flush: true);
    await temporary.rename(file.path);
  }
}

class _ReviewState {
  const _ReviewState(this.completedTrips, this.requestAttempted);

  final int completedTrips;
  final bool requestAttempted;

  factory _ReviewState.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        (value['schema'] != 1 && value['schema'] != 2) ||
        value['completedTrips'] is! int ||
        (value['completedTrips'] as int) < 0 ||
        (value['completedTrips'] as int) > AppReviewStore.requiredTrips ||
        value['requestAttempted'] is! bool) {
      // Never turn corrupt/unknown state into permission to ask again.
      throw const FormatException('Invalid app review state');
    }
    // Unreleased schema 1 also set this flag for merely opening the store.
    // It cannot prove an automatic attempt. Keep trips, retire that ambiguous
    // flag once; schema 2 records native automatic handoffs exclusively.
    return _ReviewState(value['completedTrips'] as int,
        value['schema'] == 2 && value['requestAttempted'] as bool);
  }
}
