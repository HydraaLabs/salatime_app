// ignore_for_file: library_prefixes, empty_catches

import 'dart:convert';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:salatime/data/model/response/error_response_model.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as Http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/debug_http_client.dart';

class ApiClient extends GetxService {
  final String appBaseUrl;
  final SharedPreferences sharedPreferences;
  static const String noInternetMessage =
      'Connection to API server failed due to internet connection';
  final int timeoutInSeconds = 120;
  final Map<String, String> _mainHeaders = {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  // Shared client: in debug builds it accepts user-installed CA certificates
  // (see helper/debug_http_client.dart).
  late final Http.Client _httpClient = appHttpClient;
  BaseCacheManager? _cacheManager;
  BaseCacheManager get _resolvedCacheManager =>
      _cacheManager ??= DefaultCacheManager();

  static const Duration _staticResponseTtl = Duration(days: 7);
  static const List<String> _staticGetPrefixes = [
    '/api/chapters',
    '/api/verses/',
    '/api/juzes',
    '/api/translators',
    '/api/dua-list',
    '/api/dua-details/',
    '/api/dhikr-list',
    '/api/dhikr-details/',
    '/api/sifat-name-list',
    '/api/sifat-name-details/',
    '/api/haram-code-list',
    '/api/get-cities',
    '/api/reciters',
    '/api/reciter-sura/',
    '/api/wallpapers',
    '/api/wallpaper-category',
  ];

  bool _isStaticGet(String uri, Map<String, String> headers) {
    final hasAuthorization = headers.keys.any(
      (key) => key.toLowerCase() == 'authorization',
    );
    return !hasAuthorization &&
        _staticGetPrefixes.any((prefix) => uri.startsWith(prefix));
  }

  Future<Http.Response?> _cachedResponse(
    String cacheKey, {
    required bool allowExpired,
  }) async {
    try {
      final cached = await _resolvedCacheManager.getFileFromCache(cacheKey);
      if (cached == null ||
          (!allowExpired && cached.validTill.isBefore(DateTime.now()))) {
        return null;
      }
      return Http.Response.bytes(
        await cached.file.readAsBytes(),
        cached.statusCode,
        headers: const {'content-type': 'application/json; charset=UTF-8'},
      );
    } catch (_) {
      return null;
    }
  }

  ApiClient({required this.appBaseUrl, required this.sharedPreferences});
  Future<Response> getData(
    String uri, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final requestHeaders = headers ?? _mainHeaders;
    var endpoint = Uri.parse(appBaseUrl + uri);
    if (query != null && query.isNotEmpty) {
      endpoint = endpoint.replace(
        queryParameters: query.map((key, value) => MapEntry(key, '$value')),
      );
    }
    final cacheKey = endpoint.toString();
    final cacheable = _isStaticGet(uri, requestHeaders);

    try {
      if (kDebugMode) {
        print(appBaseUrl + uri);
      }

      if (cacheable) {
        final cached = await _cachedResponse(cacheKey, allowExpired: false);
        if (cached != null) return handleResponse(cached);
      }

      Http.Response response0 = await _httpClient
          .get(endpoint, headers: requestHeaders)
          .timeout(Duration(seconds: timeoutInSeconds));

      if (cacheable && response0.statusCode == 200) {
        await _resolvedCacheManager.putFile(
          cacheKey,
          response0.bodyBytes,
          key: cacheKey,
          eTag: response0.headers['etag'],
          maxAge: _staticResponseTtl,
          fileExtension: 'json',
        );
      }

      if (kDebugMode) {
        print(response0.statusCode);
      }
      Response response = handleResponse(response0);

      if (kDebugMode) {
        print(
          '====> API Response: [${response.statusCode}] $uri\n${response.body}',
        );
      }

      return response;
    } catch (e) {
      if (cacheable) {
        final stale = await _cachedResponse(cacheKey, allowExpired: true);
        if (stale != null) return handleResponse(stale);
      }
      return const Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    try {
      if (kDebugMode) {
        print('====> API Body: $body');
        print(appBaseUrl + uri);
      }

      Http.Response response0 = await _httpClient
          .post(
            Uri.parse(appBaseUrl + uri),
            body: jsonEncode(body),
            headers: headers ?? _mainHeaders,
          )
          .timeout(Duration(seconds: timeoutInSeconds));
      Response response = handleResponse(response0);
      if (kDebugMode) {
        print(response.body);
      }

      if (kDebugMode) {
        print(
          '====> API Response: [${response.statusCode}] $uri\n${response.body}',
        );
      }

      return response;
    } catch (e) {
      return const Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> putData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    try {
      if (kDebugMode) {
        print('====> API Body: $body');
      }

      Http.Response response0 = await _httpClient
          .put(
            Uri.parse(appBaseUrl + uri),
            body: jsonEncode(body),
            headers: headers ?? _mainHeaders,
          )
          .timeout(Duration(seconds: timeoutInSeconds));
      Response response = handleResponse(response0);

      if (kDebugMode) {
        print(
          '====> API Response: [${response.statusCode}] $uri\n${response.body}',
        );
      }

      return response;
    } catch (e) {
      return const Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> deleteData(
    String uri, {
    Map<String, String>? headers,
  }) async {
    try {
      Http.Response response0 = await _httpClient
          .delete(Uri.parse(appBaseUrl + uri), headers: headers ?? _mainHeaders)
          .timeout(Duration(seconds: timeoutInSeconds));
      Response response = handleResponse(response0);

      if (kDebugMode) {
        print(
          '====> API Response: [${response.statusCode}] $uri\n${response.body}',
        );
      }

      return response;
    } catch (e) {
      return const Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Response handleResponse(Http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {}
    Response response0 = Response(
      body: body ?? response.body,
      bodyString: response.body.toString(),
      headers: response.headers,
      statusCode: response.statusCode,
      statusText: response.reasonPhrase,
    );
    if (response0.statusCode != 200 &&
        response0.body != null &&
        response0.body is! String) {
      if (response0.body.toString().startsWith('{errors: [{code:')) {
        ErrorResponse errorResponse = ErrorResponse.fromJson(response0.body);
        response0 = Response(
          statusCode: response0.statusCode,
          body: response0.body,
          statusText: errorResponse.errors![0].message,
        );
      } else if (response0.body.toString().startsWith('{message')) {
        response0 = Response(
          statusCode: response0.statusCode,
          body: response0.body,
          statusText: response0.body['message'],
        );
      }
    } else if (response0.statusCode != 200 && response0.body == null) {
      response0 = const Response(statusCode: 0, statusText: noInternetMessage);
    }
    return response0;
  }
}
