import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:munich_ways/api/api_exception.dart';
import 'package:munich_ways/routing/route_error_message.dart';

void main() {
  test('shows a helpful message for a failed network request', () {
    final error = ClientException(
      'SocketException: Failed host lookup: brouter.de (OS Error)',
    );

    expect(routeErrorMessage(error), routeConnectionErrorMessage);
    expect(routeErrorMessage(error), isNot(contains('brouter')));
    expect(routeErrorMessage(error), isNot(contains('OS Error')));
  });

  test('shows the connection message when routing times out', () {
    expect(
      routeErrorMessage(TimeoutException('Route request timed out')),
      routeConnectionErrorMessage,
    );
  });

  test('does not expose unexpected technical errors', () {
    expect(
      routeErrorMessage(StateError('internal routing details')),
      routeGenericErrorMessage,
    );
  });

  test('keeps the actionable BRouter overload message', () {
    const message =
        'BRouter ist momentan ausgelastet. '
        'Bitte versuche die Route in Kürze erneut.';

    expect(routeErrorMessage(ApiException(message)), message);
  });
}
