import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'reading_progress_models.dart';

class ReadingProgressPage {
  const ReadingProgressPage({
    required this.entries,
    required this.cursor,
    required this.hasMore,
  });
  final List<Map<String, dynamic>> entries;
  final int cursor;
  final bool hasMore;
}

class ReadingProgressAcknowledgement {
  const ReadingProgressAcknowledgement({
    required this.acknowledged,
    required this.entries,
  });
  final List<String> acknowledged;
  final List<Map<String, dynamic>> entries;
}

class ReadingProgressRemoteException implements Exception {
  const ReadingProgressRemoteException(this.statusCode);
  final int statusCode;
  @override
  String toString() => 'ReadingProgressRemoteException($statusCode)';
}

abstract class ReadingProgressRemote {
  Future<ReadingProgressPage> pull(String token, int after);
  Future<ReadingProgressAcknowledgement> push(
    String token,
    List<ReadingProgressOperation> operations,
  );
}

class HttpReadingProgressRemote implements ReadingProgressRemote {
  HttpReadingProgressRemote({required this.baseUrl, http.Client? client})
    : client = client ?? http.Client();
  final String baseUrl;
  final http.Client client;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    required String token,
    Object? body,
  }) async {
    final request =
        http.Request(
            method,
            Uri.parse('$baseUrl/api/mobile/reading-progress$path'),
          )
          ..followRedirects = false
          ..headers.addAll({
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          });
    if (body != null) request.body = jsonEncode(body);
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 15));
    final bytes = <int>[];
    await for (final part in response.stream.timeout(
      const Duration(seconds: 15),
    )) {
      bytes.addAll(part);
      if (bytes.length > 1048576) {
        throw const FormatException('Oversized reading response');
      }
    }
    if (response.statusCode != 200) {
      throw ReadingProgressRemoteException(response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid reading response');
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _entries(Object? value) {
    if (value is! List ||
        value.length > 500 ||
        value.any((entry) => entry is! Map<String, dynamic>)) {
      throw const FormatException('Invalid reading entries');
    }
    return value.cast<Map<String, dynamic>>();
  }

  @override
  Future<ReadingProgressPage> pull(String token, int after) async {
    final data = await _request('GET', '?after=$after&limit=500', token: token);
    final cursor = data['cursor'];
    if (cursor is! int || cursor < 0 || data['hasMore'] is! bool) {
      throw const FormatException('Invalid reading cursor');
    }
    return ReadingProgressPage(
      entries: _entries(data['entries']),
      cursor: cursor,
      hasMore: data['hasMore'] as bool,
    );
  }

  @override
  Future<ReadingProgressAcknowledgement> push(
    String token,
    List<ReadingProgressOperation> operations,
  ) async {
    if (operations.isEmpty || operations.length > 100) {
      throw ArgumentError('Expected 1 to 100 operations');
    }
    final data = await _request(
      'POST',
      '/batch',
      token: token,
      body: {
        'operations': operations
            .map((operation) => operation.toJson())
            .toList(),
      },
    );
    final acknowledged = data['acknowledged'];
    if (acknowledged is! List ||
        acknowledged.length > 100 ||
        acknowledged.any((id) => id is! String)) {
      throw const FormatException('Invalid reading acknowledgements');
    }
    return ReadingProgressAcknowledgement(
      acknowledged: acknowledged.cast<String>(),
      entries: _entries(data['entries']),
    );
  }
}
