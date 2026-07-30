import 'dart:async';

import 'package:http/http.dart';
import 'package:munich_ways/api/api_exception.dart';

const routeConnectionErrorMessage =
    'Keine Internetverbindung. Bitte überprüfe deine Verbindung und versuche '
    'es erneut.';

const routeGenericErrorMessage =
    'Die Route konnte nicht berechnet werden. Bitte versuche es später erneut.';

String routeErrorMessage(Object error) {
  if (error is ClientException || error is TimeoutException) {
    return routeConnectionErrorMessage;
  }

  if (error is ApiException &&
      error.message.startsWith('BRouter ist momentan ausgelastet.')) {
    return error.message;
  }

  return routeGenericErrorMessage;
}
