import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;

/// Shared HTTP client for the whole app.
///
/// In debug builds it accepts user-installed CA certificates so HTTPS traffic
/// can be inspected with HTTP Toolkit / mitmproxy — Dart's dart:io ignores
/// Android's networkSecurityConfig. Release builds keep strict verification.
final http.Client appHttpClient = _createClient();

http.Client _createClient() {
  if (kDebugMode) {
    final inner = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    return io_client.IOClient(inner);
  }
  return http.Client();
}
