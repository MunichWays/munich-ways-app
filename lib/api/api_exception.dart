class ApiException implements Exception {
  final String message;

  ApiException([this.message = ""]);

  String toString() => "ApiException: $message";
}
