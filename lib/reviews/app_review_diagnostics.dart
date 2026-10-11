enum ReviewDiagnosticEvent {
  tripRecorded,
  storageFailed,
  promptScheduled,
  promptCancelled,
  interfaceBusy,
  checkingStore,
  storeUnavailable,
  requestSkipped,
  nativeHandoff,
  nativeCompleted,
  requestFailed,
}

class AppReviewDiagnostics {
  const AppReviewDiagnostics({
    this.completedTrips,
    this.requestAttempted,
    this.storageError,
    this.storeAvailable,
    this.failureType,
    this.events = const [],
  });

  final int? completedTrips;
  final bool? requestAttempted;
  final String? storageError;
  final bool? storeAvailable;
  final String? failureType;
  final List<({DateTime time, ReviewDiagnosticEvent event})> events;
}
