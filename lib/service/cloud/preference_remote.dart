import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'preference_schema.dart';
import 'preference_sync_engine.dart';

class HttpPreferenceRemote implements PreferenceRemote {
  HttpPreferenceRemote({
    required this.baseUrl,
    required this.tokenFor,
    this.onUnauthorized,
    http.Client? client,
  }) : client = client ?? http.Client();
  final String baseUrl;
  final Future<String?> Function(String account) tokenFor;
  final http.Client client;
  final Future<void> Function(String account, String token)? onUnauthorized;
  Future<CloudDocument> _request(
    String account, {
    int? version,
    Document? preferences,
  }) async {
    final token = await tokenFor(account);
    if (token == null) throw StateError('No authenticated session');
    final uri = Uri.parse('$baseUrl/api/mobile/preferences');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final request = http.Request(version == null ? 'GET' : 'PUT', uri)
      ..headers.addAll(headers)
      ..followRedirects = false;
    if (version != null) {
      request.body = jsonEncode({
        'version': version,
        'preferences': PreferenceSchema.clean(preferences),
      });
    }
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 15));
    final bytes = <int>[];
    await for (final part in response.stream.timeout(
      const Duration(seconds: 15),
    )) {
      bytes.addAll(part);
      if (bytes.length > 65536) {
        throw const FormatException('Oversized preference response');
      }
    }
    if (response.statusCode == 401) {
      // Only the owner can clear the exact session used by this request.
      // A late response for another account/token must never sign out its successor.
      await onUnauthorized?.call(account, token);
    }
    if (response.statusCode != 200 && response.statusCode != 409) {
      throw StateError('Preference request rejected');
    }
    final json = jsonDecode(utf8.decode(bytes));
    final data = json is Map ? json['data'] : null;
    if (data is! Map ||
        data['version'] is! int ||
        data['version'] < 0 ||
        data['preferences'] is! Map) {
      throw const FormatException('Invalid preference document');
    }
    final doc = CloudDocument(
      data['version'],
      PreferenceSchema.clean(data['preferences']),
    );
    if (response.statusCode == 409) throw PreferenceConflict(doc);
    return doc;
  }

  @override
  Future<CloudDocument> get(String account) => _request(account);
  @override
  Future<CloudDocument> put(
    String account,
    int version,
    Document preferences,
  ) => _request(account, version: version, preferences: preferences);
}
