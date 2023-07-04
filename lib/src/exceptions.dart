import 'dart:convert';

import 'package:http/http.dart';

/// This exception is thrown if the server sends a request with an unexpected
/// status code or missing/invalid headers.
class ProtocolException implements Exception {
  final String message;
  final int? statusCode;

  ProtocolException(this.message, [this.statusCode]);

  factory ProtocolException.rsp({
    required Response response,
    String message = "Unexpected response from server",
  }) {
    final errMsg = getMessage(response);
    final hasErrMessage = errMsg.isNotEmpty;
    return ProtocolException(
      hasErrMessage ? errMsg : message,
      response.statusCode,
    );
  }

  static String getMessage(Response r) {
    final body = r.body;
    if (body.isEmpty) return "";
    final jsonBody = jsonDecode(body) as Map;
    final message = jsonBody["message"] as String?;
    final hasMessage = message != null && message.isNotEmpty;
    return hasMessage ? message : "";
  }

  String toString() => "HTTP Error: ($statusCode) $message";
}
