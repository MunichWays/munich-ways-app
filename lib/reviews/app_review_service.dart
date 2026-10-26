import 'dart:io';

import 'package:in_app_review/in_app_review.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/reviews/app_review_store.dart';
import 'package:munich_ways/reviews/app_review_diagnostics.dart';
import 'package:url_launcher/url_launcher.dart';

final appReviewService = AppReviewService();

abstract class AppReviewPlatform {
  Future<bool> isAvailable();
  Future<void> requestReview();
  Future<void> openStoreListing();
}

class NativeAppReviewPlatform implements AppReviewPlatform {
  static const appStoreId = '1534934984';
  static final androidUrl = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.munichways.app');
  static final iosUrl =
      Uri.parse('https://apps.apple.com/app/id$appStoreId?action=write-review');

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();

  @override
  Future<void> openStoreListing() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('No mobile app store');
    }
    final url = Platform.isIOS
        ? iosUrl
        : Uri.parse('market://details?id=com.munichways.app');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open app store');
    }
  }

  static Future<bool> openWebListing() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    return launchUrl(Platform.isIOS ? iosUrl : androidUrl,
        mode: LaunchMode.externalApplication);
  }
}

/// Optional store interaction must never block navigation or app startup.
class AppReviewService {
  AppReviewService({
    AppReviewStore? store,
    AppReviewPlatform? platform,
    Future<bool> Function()? openWebListing,
  })  : _store = store ?? AppReviewStore(),
        _platform = platform ?? NativeAppReviewPlatform(),
        _openWebListing =
            openWebListing ?? NativeAppReviewPlatform.openWebListing;

  final AppReviewStore _store;
  final AppReviewPlatform _platform;
  final Future<bool> Function() _openWebListing;
  Future<bool>? _openingStore;
  bool? _lastStoreAvailable;
  String? _lastFailureType;
  final _diagnosticEvents = <({DateTime time, ReviewDiagnosticEvent event})>[];

  void recordDiagnosticEvent(ReviewDiagnosticEvent event) {
    _diagnosticEvents.add((time: DateTime.now().toUtc(), event: event));
    if (_diagnosticEvents.length > 20) _diagnosticEvents.removeAt(0);
  }

  Future<AppReviewDiagnostics> readDiagnostics() async {
    int? trips;
    bool? attempted;
    String? storageError;
    try {
      final state =
          await _store.readDiagnostics().timeout(const Duration(seconds: 5));
      trips = state.completedTrips;
      attempted = state.requestAttempted;
    } catch (error) {
      storageError = error.runtimeType.toString();
    }
    return AppReviewDiagnostics(
      completedTrips: trips,
      requestAttempted: attempted,
      storageError: storageError,
      storeAvailable: _lastStoreAvailable,
      failureType: _lastFailureType,
      events: List.unmodifiable(_diagnosticEvents),
    );
  }

  Future<bool> recordCompletedTrip() async {
    try {
      final eligible = await _store.recordCompletedTrip();
      recordDiagnosticEvent(ReviewDiagnosticEvent.tripRecorded);
      return eligible;
    } catch (error, stackTrace) {
      _lastFailureType = error.runtimeType.toString();
      recordDiagnosticEvent(ReviewDiagnosticEvent.storageFailed);
      log.w('Saving completed trip for review failed',
          error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> requestAutomaticReview(
      {required bool Function() canRequest}) async {
    try {
      if (!canRequest()) {
        recordDiagnosticEvent(ReviewDiagnosticEvent.interfaceBusy);
        return;
      }
      recordDiagnosticEvent(ReviewDiagnosticEvent.checkingStore);
      _lastStoreAvailable = null;
      _lastFailureType = null;
      _lastStoreAvailable =
          await _platform.isAvailable().timeout(const Duration(seconds: 5));
      if (!_lastStoreAvailable!) {
        recordDiagnosticEvent(ReviewDiagnosticEvent.storeUnavailable);
        return;
      }
      if (!canRequest()) {
        recordDiagnosticEvent(ReviewDiagnosticEvent.interfaceBusy);
        return;
      }
      var handedOff = false;
      await _store.requestIfEligible(
        canRequest: canRequest,
        request: () {
          handedOff = true;
          recordDiagnosticEvent(ReviewDiagnosticEvent.nativeHandoff);
          return _platform.requestReview().timeout(const Duration(seconds: 30));
        },
      );
      recordDiagnosticEvent(handedOff
          ? ReviewDiagnosticEvent.nativeCompleted
          : ReviewDiagnosticEvent.requestSkipped);
    } catch (error, stackTrace) {
      _lastFailureType = error.runtimeType.toString();
      recordDiagnosticEvent(ReviewDiagnosticEvent.requestFailed);
      // No error dialog and no automatic store redirect.
      log.w('Automatic app review request skipped or failed',
          error: error, stackTrace: stackTrace);
    }
  }

  Future<bool> openStoreListing() => _openingStore ??=
      _openStoreListing().whenComplete(() => _openingStore = null);

  Future<bool> _openStoreListing() async {
    var opened = false;
    try {
      await _platform.openStoreListing().timeout(const Duration(seconds: 5));
      opened = true;
    } catch (_) {
      try {
        opened = await _openWebListing().timeout(const Duration(seconds: 5));
      } catch (error, stackTrace) {
        log.w('Opening app store failed', error: error, stackTrace: stackTrace);
      }
    }
    return opened;
  }
}
