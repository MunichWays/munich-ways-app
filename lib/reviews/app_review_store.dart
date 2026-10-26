import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Small, independent local state. Nothing is loaded during app startup.
class AppReviewStore {
  AppReviewStore({
    Future<Directory> Function()? directoryProvider,
    DateTime Function()? now,
    Future<String> Function()? versionProvider,
  })  : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory,
        _now = now ?? DateTime.now,
        _versionProvider = versionProvider ?? _appVersion;

  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() _now;
  final Future<String> Function() _versionProvider;
  Future<void> _updates = Future<void>.value();

  static const fileName = 'app_review.json';
  static const requiredTrips = 3;
  static const minimumInterval = Duration(days: 30);
  static const reviewYear = Duration(days: 365);
  static const maximumYearlyAttempts = 3;

  // Marketing version only: a new build of the same release is not a new
  // opportunity to request a review. No platform calls during app startup.
  static Future<String> _appVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  Future<String> _version() async {
    final version =
        await _versionProvider().timeout(const Duration(seconds: 5));
    if (version.trim().isEmpty) throw StateError('Missing app version');
    return version;
  }

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
      : const _ReviewState(0, []);

  Future<bool> recordCompletedTrip() => _serialize((file, state) async {
        final updated = _ReviewState(state.completedTrips + 1, state.attempts);
        await _write(file, updated);
        return updated.eligibleAt(_now().toUtc()) &&
            !updated.hasRequestedVersion(await _version());
      });

  /// Reserve durably before handing off to the native API. Recheck after I/O
  /// so a background transition or new task cannot launch a delayed dialog.
  Future<void> requestIfEligible({
    required bool Function() canRequest,
    required Future<void> Function() request,
  }) =>
      _serialize((file, state) async {
        if (!state.eligibleAt(_now().toUtc()) || !canRequest()) return;
        final version = await _version();
        if (state.hasRequestedVersion(version) || !canRequest()) return;
        final now = _now().toUtc();
        if (!state.eligibleAt(now)) return;
        await _write(
            file,
            _ReviewState(state.completedTrips, [
              ...state.attempts,
              _ReviewAttempt(now, version, state.completedTrips),
            ]));
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
      var state = await _read(file);
      if (state.legacyAttempted) {
        // Old releases stored neither the attempt date nor its version. Anchor
        // the consumed attempt once at migration, rather than guessing and
        // immediately asking again. Diagnostics alone never writes this state.
        final version = await _version();
        state = _ReviewState(state.completedTrips, [
          _ReviewAttempt(_now().toUtc(), version, state.completedTrips),
        ]);
        await _write(file, state);
      }
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
          'schema': 3,
          'completedTrips': state.completedTrips,
          'attempts':
              state.attempts.map((attempt) => attempt.toJson()).toList(),
        }),
        flush: true);
    await temporary.rename(file.path);
  }
}

class _ReviewState {
  const _ReviewState(this.completedTrips, this.attempts,
      {this.legacyAttempted = false});

  final int completedTrips;
  final List<_ReviewAttempt> attempts;
  final bool legacyAttempted;
  bool get requestAttempted => legacyAttempted || attempts.isNotEmpty;

  bool hasRequestedVersion(String version) =>
      attempts.any((attempt) => attempt.version == version);

  bool eligibleAt(DateTime now) {
    if (completedTrips < AppReviewStore.requiredTrips) return false;
    if (attempts.isEmpty) return true;
    final last = attempts.last;
    return completedTrips - last.completedTrips >=
            AppReviewStore.requiredTrips &&
        now.difference(last.at) >= AppReviewStore.minimumInterval &&
        attempts
                .where((a) => now.difference(a.at) < AppReviewStore.reviewYear)
                .length <
            AppReviewStore.maximumYearlyAttempts;
  }

  factory _ReviewState.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['completedTrips'] is! int ||
        (value['completedTrips'] as int) < 0) {
      // Never turn corrupt/unknown state into permission to ask again.
      throw const FormatException('Invalid app review state');
    }
    final trips = value['completedTrips'] as int;
    if ((value['schema'] == 1 || value['schema'] == 2) &&
        trips <= AppReviewStore.requiredTrips &&
        value['requestAttempted'] is bool) {
      // Schema 1 also marked manual store launches and cannot prove an attempt.
      return _ReviewState(trips, [],
          legacyAttempted:
              value['schema'] == 2 && value['requestAttempted'] == true);
    }
    if (value['schema'] != 3 || value['attempts'] is! List) {
      throw const FormatException('Invalid app review schema');
    }
    final attempts = (value['attempts'] as List)
        .map((entry) => _ReviewAttempt.fromJson(entry, trips))
        .toList();
    final versions = <String>{};
    for (var i = 0; i < attempts.length; i++) {
      final attempt = attempts[i];
      if (!versions.add(attempt.version) ||
          (i > 0 &&
              (attempt.at.isBefore(attempts[i - 1].at) ||
                  attempt.completedTrips < attempts[i - 1].completedTrips))) {
        throw const FormatException('Invalid app review history');
      }
    }
    return _ReviewState(trips, attempts);
  }
}

class _ReviewAttempt {
  const _ReviewAttempt(this.at, this.version, this.completedTrips);

  final DateTime at;
  final String version;
  final int completedTrips;

  Map<String, Object> toJson() => {
        'at': at.toIso8601String(),
        'version': version,
        'completedTrips': completedTrips,
      };

  factory _ReviewAttempt.fromJson(Object? value, int totalTrips) {
    if (value is! Map<String, dynamic> ||
        value['at'] is! String ||
        value['version'] is! String ||
        (value['version'] as String).trim().isEmpty ||
        value['completedTrips'] is! int ||
        (value['completedTrips'] as int) < 0 ||
        (value['completedTrips'] as int) > totalTrips) {
      throw const FormatException('Invalid app review attempt');
    }
    final at = DateTime.tryParse(value['at'] as String);
    if (at == null || !at.isUtc) {
      throw const FormatException('Invalid app review date');
    }
    return _ReviewAttempt(
        at, value['version'] as String, value['completedTrips'] as int);
  }
}
