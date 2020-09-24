import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';

class TestUtils {
  static Future<String> readStringFromFile(String filePath) async {
    File file = await getFile(filePath);
    return file.readAsString(encoding: utf8);
  }

  /// running tests via cmdline `flutter test` uses a different path as running it via the IDE Android Studio
  static Future<File> getFile(String filePath) async {
    File file = File(filePath);
    if (!await file.exists()) {
      file = File("../$filePath");
    }
    return file;
  }

  static Future<Uint8List> readBytesFromFile(String filePath) async {
    File file = await getFile(filePath);
    return file.readAsBytesSync();
  }

  /// Get HTTP response with content of given file as body
  static Future<Response> readResponseFromFile(String filePath, int statusCode,
      {BaseRequest request,
      Map<String, String> headers = const {},
      bool isRedirect = false,
      bool persistentConnection = true,
      String reasonPhrase}) async {
    return Response.bytes(await readBytesFromFile(filePath), statusCode,
        request: request,
        headers: headers,
        isRedirect: isRedirect,
        persistentConnection: persistentConnection,
        reasonPhrase: reasonPhrase);
  }
}
