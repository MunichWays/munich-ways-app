import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/reviews/app_review_prompt_controller.dart';
import 'package:munich_ways/reviews/app_review_service.dart';

class FakeReviewService extends AppReviewService {
  int completedTrips = 0;
  int requests = 0;
  bool attempted = false;
  Completer<bool>? recording;

  @override
  Future<bool> recordCompletedTrip() async {
    completedTrips++;
    if (recording != null) return recording!.future;
    return completedTrips >= 3 && !attempted;
  }

  @override
  Future<void> requestAutomaticReview(
      {required bool Function() canRequest}) async {
    if (canRequest() && !attempted) {
      requests++;
      attempted = true;
    }
  }
}

void main() {
  late FakeReviewService service;
  late AppReviewPromptController controller;
  var idle = true;
  Future<void> finish() => controller.destinationFinished();

  setUp(() {
    idle = true;
    service = FakeReviewService();
    controller =
        AppReviewPromptController(service: service, canPrompt: () => idle);
  });
  tearDown(() => controller.dispose());

  testWidgets('third orange Finish button press requests a review once',
      (tester) async {
    expect(service.completedTrips, 0);
    await finish();
    await tester.pump(const Duration(seconds: 3));
    await finish();
    await tester.pump(const Duration(seconds: 3));
    expect(service.requests, 0);
    await finish();
    await tester.pump(const Duration(milliseconds: 1999));
    expect(service.requests, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(service.requests, 1);
    await finish();
    await tester.pump(const Duration(seconds: 3));
    expect(service.requests, 1);
  });

  testWidgets('interaction/background cancels without replay on resume',
      (tester) async {
    service.completedTrips = 2;
    await finish();
    controller.cancel();
    await tester.pump(const Duration(seconds: 3));
    expect(service.requests, 0);
    await finish();
    await tester.pump(const Duration(seconds: 2));
    expect(service.requests, 1);
  });

  testWidgets('busy UI at expiry skips request and later finish recovers',
      (tester) async {
    service.completedTrips = 2;
    await finish();
    idle = false;
    await tester.pump(const Duration(seconds: 2));
    idle = true;
    await tester.pump(const Duration(seconds: 10));
    expect(service.requests, 0);
    await finish();
    await tester.pump(const Duration(seconds: 2));
    expect(service.requests, 1);
  });

  testWidgets('interaction during persistence cannot schedule a stale timer',
      (tester) async {
    service.recording = Completer<bool>();
    final completion = finish();
    controller.cancel();
    service.recording!.complete(true);
    await completion;
    await tester.pump(const Duration(seconds: 3));
    expect(service.requests, 0);
  });

  testWidgets('disposal cancels timer and pending persistence', (tester) async {
    service.completedTrips = 2;
    await finish();
    controller.dispose();
    await tester.pump(const Duration(seconds: 3));
    expect(service.requests, 0);
    controller =
        AppReviewPromptController(service: service, canPrompt: () => true);
    service.recording = Completer<bool>();
    final completion = finish();
    controller.dispose();
    service.recording!.complete(true);
    await completion;
    await tester.pump(const Duration(seconds: 3));
    expect(service.requests, 0);
  });
}
