import 'dart:convert';

import 'package:http/http.dart';

extension JsonBody on Response {
  dynamic jsonBody() {
    // Use utf8 encoding instead of latin1 which is used by body
    // see https://github.com/dart-lang/http/issues/367
    String jsonBody = Utf8Decoder().convert(this.bodyBytes);
    return json.decode(jsonBody);
  }
}
