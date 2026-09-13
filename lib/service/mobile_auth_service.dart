import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:zabi/util/app_constants.dart';

class MobileUser {
  const MobileUser({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.hasPassword,
    this.providers = const [],
  });
  final String id;
  final String name;
  final String email;
  final bool emailVerified;
  final bool hasPassword;
  final List<String> providers;
  factory MobileUser.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty || json['email'] is! String || json['name'] is! String) {
      throw const MobileAuthException('auth_service_unavailable');
    }
    return MobileUser(
      id: id,
      name: json['name'],
      email: json['email'],
      emailVerified: json['email_verified'] == true,
      hasPassword: json['has_password'] == true,
      providers: json['providers'] is List
          ? (json['providers'] as List)
                .whereType<String>()
                .where((p) => p == 'google' || p == 'apple')
                .toList()
          : const [],
    );
  }
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'email_verified': emailVerified,
    'has_password': hasPassword,
    'providers': providers,
  };
}

class MobileAuthException implements Exception {
  const MobileAuthException(this.messageKey);
  final String messageKey;
  // Never stringify server bodies, passwords or identity tokens in logs.
  @override
  String toString() => 'MobileAuthException($messageKey)';
}

abstract class AuthSessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAuthSessionStore implements AuthSessionStore {
  const SecureAuthSessionStore();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'salatime_auth',
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MobileAuthConfiguration {
  const MobileAuthConfiguration({
    this.available = false,
    this.email = false,
    this.verification = false,
    this.passwordReset = false,
    this.google = false,
    this.apple = false,
    this.googleServerClientId,
    this.googleIosClientId,
    this.appleClientId,
    this.appleRedirectUri,
  });
  final bool available, email, verification, passwordReset, google, apple;
  final String? googleServerClientId, googleIosClientId, appleClientId;
  final Uri? appleRedirectUri;
  factory MobileAuthConfiguration.fromJson(Map<String, dynamic> data) {
    Map<dynamic, dynamic> provider(String key) =>
        data[key] is Map ? data[key] as Map : {};
    final google = provider('google'), apple = provider('apple');
    String? nonempty(Object? value) =>
        value is String && value.trim().isNotEmpty ? value.trim() : null;
    final googleId = nonempty(google['server_client_id']);
    final iosId = nonempty(google['ios_client_id']);
    final appleId = nonempty(apple['client_id']);
    final redirect = Uri.tryParse(nonempty(apple['redirect_uri']) ?? '');
    final onAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final onIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    // iOS also requires URL schemes / Sign in with Apple signing entitlement.
    const googleIosReady = bool.fromEnvironment('SALATIME_GOOGLE_IOS_ENABLED');
    const appleIosReady = bool.fromEnvironment('SALATIME_APPLE_IOS_ENABLED');
    final secureRedirect =
        redirect != null &&
        redirect.scheme == 'https' &&
        redirect.host.isNotEmpty;
    return MobileAuthConfiguration(
      available: data['enabled'] == true,
      verification: provider('email')['verification_enabled'] == true,
      passwordReset: provider('email')['password_reset_enabled'] == true,
      email: provider('email')['enabled'] == true,
      google:
          google['enabled'] == true &&
          googleId != null &&
          (onAndroid || (onIos && googleIosReady && iosId != null)),
      apple:
          apple['enabled'] == true &&
          ((onAndroid && appleId != null && secureRedirect) ||
              (onIos && appleIosReady)),
      googleServerClientId: googleId,
      googleIosClientId: iosId,
      appleClientId: appleId,
      appleRedirectUri: secureRedirect ? redirect : null,
    );
  }
}

abstract class MobileIdentityProvider {
  Future<Map<String, String>> google(MobileAuthConfiguration config);
  Future<Map<String, String>> apple(
    MobileAuthConfiguration config,
    Map<String, dynamic> challenge,
  );
}

class NativeMobileIdentityProvider implements MobileIdentityProvider {
  static Future<void>? _googleInitialization;
  @override
  Future<Map<String, String>> google(MobileAuthConfiguration config) async {
    try {
      _googleInitialization ??= GoogleSignIn.instance.initialize(
        serverClientId: config.googleServerClientId,
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? config.googleIosClientId
            : null,
      );
      await _googleInitialization;
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const MobileAuthException('auth_provider_unavailable');
      }
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const MobileAuthException('auth_provider_unavailable');
      }
      return {'id_token': token};
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const MobileAuthException('auth_cancelled');
      }
      throw const MobileAuthException('auth_provider_unavailable');
    }
  }

  @override
  Future<Map<String, String>> apple(
    MobileAuthConfiguration config,
    Map<String, dynamic> challenge,
  ) async {
    try {
      final nonce = challenge['nonce'],
          state = challenge['state'],
          id = challenge['challenge_id'];
      if (nonce is! String ||
          state is! String ||
          id is! String ||
          nonce.isEmpty ||
          state.isEmpty) {
        throw const MobileAuthException('auth_service_unavailable');
      }
      if (!await SignInWithApple.isAvailable()) {
        throw const MobileAuthException('auth_provider_unavailable');
      }
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(nonce)).toString(),
        state: state,
        webAuthenticationOptions:
            defaultTargetPlatform == TargetPlatform.android
            ? WebAuthenticationOptions(
                clientId: config.appleClientId!,
                redirectUri: config.appleRedirectUri!,
              )
            : null,
      );
      if (credential.identityToken == null ||
          (credential.state != null && credential.state != state)) {
        throw const MobileAuthException('auth_provider_unavailable');
      }
      return {
        'identity_token': credential.identityToken!,
        'authorization_code': credential.authorizationCode,
        'nonce': nonce,
        'state': state,
        'challenge_id': id,
        'name': [
          credential.givenName,
          credential.familyName,
        ].whereType<String>().join(' ').trim(),
      };
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const MobileAuthException('auth_cancelled');
      }
      throw const MobileAuthException('auth_provider_unavailable');
    } on SignInWithAppleException {
      throw const MobileAuthException('auth_provider_unavailable');
    }
  }
}

class MobileAuthService {
  MobileAuthService({
    http.Client? client,
    AuthSessionStore? storage,
    MobileIdentityProvider? identityProvider,
    String? apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const SecureAuthSessionStore(),
       _identity = identityProvider ?? NativeMobileIdentityProvider(),
       baseUrl =
           (apiBaseUrl ??
                   const String.fromEnvironment(
                     'SALATIME_ACCOUNT_API_URL',
                     defaultValue: AppConstants.BASE_URL,
                   ))
               .replaceFirst(RegExp(r'/+$'), '') {
    final uri = Uri.parse(baseUrl);
    final localDebug =
        kDebugMode && ['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host);
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'https' && !(localDebug && uri.scheme == 'http'))) {
      throw ArgumentError('Account API requires HTTPS');
    }
  }
  static final instance = MobileAuthService();
  final http.Client _client;
  final AuthSessionStore _storage;
  final MobileIdentityProvider _identity;
  final String baseUrl;
  final user = Rxn<MobileUser>();
  final configuration = const MobileAuthConfiguration().obs;
  final initializationError = RxnString();
  Future<void>? _initialization;
  String? _token;
  int _sessionGeneration = 0;
  Future<void> _storageQueue = Future.value();
  String get storageKey =>
      'session_v1_${sha256.convert(utf8.encode(baseUrl)).toString()}';
  Future<String?> accessToken() async => _token;

  Future<void> initialize() => _initialization ??= _initialize().whenComplete(
    () {
      // A transient Keychain/Keystore failure must not poison the Retry action.
      // Keep successful initialization cached so opening Account never restores
      // a previous session over a newer login/logout.
      if (initializationError.value != null) _initialization = null;
    },
  );
  Future<void> _initialize() async {
    final generation = _sessionGeneration;
    initializationError.value = null;
    try {
      final raw = await _storage.read(storageKey);
      if (generation != _sessionGeneration) return;
      if (raw != null) {
        final saved = jsonDecode(raw);
        if (saved is! Map ||
            !_validToken(saved['token']) ||
            saved['user'] is! Map) {
          await _queueStorage(() async {
            if (generation == _sessionGeneration) {
              await _storage.delete(storageKey);
            }
          });
        } else {
          final restored = MobileUser.fromJson(
            Map<String, dynamic>.from(saved['user'] as Map),
          );
          _token = saved['token'] as String;
          user.value = restored;
          try {
            await refreshUser();
          } on MobileAuthException {
            /* Keep offline profile unless session was revoked. */
          }
        }
      }
    } catch (_) {
      if (generation != _sessionGeneration) return;
      _token = null;
      user.value = null;
      initializationError.value = 'auth_secure_storage_error';
    }
  }

  Future<void> loadConfiguration() async {
    try {
      configuration.value = MobileAuthConfiguration.fromJson(
        await _request('GET', '/config'),
      );
    } on MobileAuthException {
      configuration.value = const MobileAuthConfiguration();
      rethrow;
    }
  }

  static bool validEmail(String value) =>
      value.trim().length <= 254 &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  static bool validPassword(String value) =>
      value.runes.length >= 12 &&
      value.runes.length <= 128 &&
      utf8.encode(value).length <= 72 &&
      RegExp(r'\p{L}', unicode: true).hasMatch(value) &&
      RegExp(r'\p{N}', unicode: true).hasMatch(value);
  static String? passwordError(String value) => utf8.encode(value).length > 72
      ? 'auth_password_too_long'
      : validPassword(value)
      ? null
      : 'auth_password_requirements';
  static String normalizeCode(String value) => String.fromCharCodes(
    value.trim().runes.map((rune) {
      for (final start in [0x0660, 0x06F0, 0x09E6, 0x0966]) {
        if (rune >= start && rune <= start + 9) return 48 + rune - start;
      }
      return rune;
    }),
  );
  static bool validCode(String value) =>
      RegExp(r'^\d{6}$').hasMatch(normalizeCode(value));
  static bool _validToken(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= 8192 &&
      !RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(value);
  void _validateEmail(String email) {
    if (!validEmail(email)) {
      throw const MobileAuthException('auth_invalid_email');
    }
  }

  Future<void> login({required String email, required String password}) async {
    final generation = _sessionGeneration;
    _validateEmail(email);
    if (password.isEmpty || password.length > 128) {
      throw const MobileAuthException('auth_invalid_credentials');
    }
    await _establish(
      await _request(
        'POST',
        '/login',
        body: {
          'email': email.trim(),
          'password': password,
          'device_name': 'SalaTime ${defaultTargetPlatform.name}',
        },
      ),
      expectedGeneration: generation,
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final generation = _sessionGeneration;
    _validateEmail(email);
    if (name.trim().isEmpty || name.trim().runes.length > 100) {
      throw const MobileAuthException('auth_invalid_name');
    }
    if (!validPassword(password)) {
      throw MobileAuthException(passwordError(password)!);
    }
    await _establish(
      await _request(
        'POST',
        '/register',
        body: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'password_confirmation': password,
          'device_name': 'SalaTime ${defaultTargetPlatform.name}',
        },
      ),
      expectedGeneration: generation,
    );
  }

  Future<void> signInWithGoogle({bool link = false}) async {
    final generation = _sessionGeneration;
    final token = _token;
    if (link && token == null) {
      throw const MobileAuthException('auth_session_expired');
    }
    if (!configuration.value.google) {
      throw const MobileAuthException('auth_provider_unavailable');
    }
    final identity = await _identity.google(configuration.value);
    _checkProviderSession(generation, token);
    await _establish(
      await _request(
        'POST',
        link ? '/link/google' : '/google',
        authenticated: link,
        authorizationToken: link ? token : null,
        body: {
          ...identity,
          'device_name': 'SalaTime ${defaultTargetPlatform.name}',
        },
      ),
      expectedGeneration: generation,
    );
  }

  Future<void> signInWithApple({bool link = false}) async {
    final generation = _sessionGeneration;
    final token = _token;
    if (link && token == null) {
      throw const MobileAuthException('auth_session_expired');
    }
    if (!configuration.value.apple) {
      throw const MobileAuthException('auth_provider_unavailable');
    }
    final challenge = await _request(
      'GET',
      '/challenge?provider=apple&platform=${defaultTargetPlatform.name}',
    );
    _checkProviderSession(generation, token);
    final identity = await _identity.apple(configuration.value, challenge);
    _checkProviderSession(generation, token);
    await _establish(
      await _request(
        'POST',
        link ? '/link/apple' : '/apple',
        authenticated: link,
        authorizationToken: link ? token : null,
        body: {
          ...identity,
          'device_name': 'SalaTime ${defaultTargetPlatform.name}',
        },
      ),
      expectedGeneration: generation,
    );
  }

  void _checkProviderSession(int generation, String? token) {
    if (generation != _sessionGeneration || token != _token) {
      throw const MobileAuthException('auth_cancelled');
    }
  }

  Future<void> forgotPassword(String email) async {
    _validateEmail(email);
    await _request('POST', '/forgot-password', body: {'email': email.trim()});
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    _validateEmail(email);
    if (!validCode(code)) throw const MobileAuthException('auth_invalid_code');
    if (!validPassword(password)) {
      throw MobileAuthException(passwordError(password)!);
    }
    await _request(
      'POST',
      '/reset-password',
      body: {
        'email': email.trim(),
        'token': normalizeCode(code),
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  Future<void> resendVerification() async =>
      _request('POST', '/resend-verification', authenticated: true);
  Future<void> verifyEmail(String code) async {
    final generation = _sessionGeneration;
    final token = _token;
    if (!validCode(code)) throw const MobileAuthException('auth_invalid_code');
    await _request(
      'POST',
      '/verify-email',
      authenticated: true,
      authorizationToken: token,
      body: {'token': normalizeCode(code)},
    );
    _checkProviderSession(generation, token);
    await refreshUser();
  }

  Future<void> refreshUser() async {
    final generation = _sessionGeneration;
    final token = _token;
    if (token == null) return;
    final data = await _request('GET', '/me', authenticated: true);
    if (generation != _sessionGeneration || token != _token) return;
    if (data['user'] is! Map) {
      throw const MobileAuthException('auth_service_unavailable');
    }
    final profile = MobileUser.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
    await _persist(token, profile);
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await _request('POST', '/logout', authenticated: true);
      }
    } finally {
      await clearSession();
    }
  }

  Future<void> deleteAccount({String? password}) async {
    await _request(
      'DELETE',
      '/account',
      authenticated: true,
      body: {'password': ?password},
    );
    await clearSession();
  }

  Future<void> clearSession({String? expectedToken}) async {
    // Check and clear together before yielding: a late rejected request must
    // never invalidate a replacement session or a newer in-flight login.
    if (expectedToken != null && expectedToken != _token) return;
    _sessionGeneration++;
    _token = null;
    user.value = null;
    await _queueStorage(() async {
      try {
        await _storage.delete(storageKey);
      } catch (_) {
        throw const MobileAuthException('auth_secure_storage_error');
      }
    });
  }

  Future<void> _queueStorage(Future<void> Function() mutation) {
    final next = _storageQueue.then((_) => mutation());
    _storageQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _establish(
    Map<String, dynamic> data, {
    required int expectedGeneration,
  }) async {
    if (!_validToken(data['token']) || data['user'] is! Map) {
      throw const MobileAuthException('auth_service_unavailable');
    }
    final profile = MobileUser.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
    final token = data['token'] as String;
    if (expectedGeneration != _sessionGeneration) {
      await _discardCandidate(token);
      throw const MobileAuthException('auth_cancelled');
    }
    _sessionGeneration++;
    try {
      await _persist(token, profile);
    } on MobileAuthException {
      await _discardCandidate(token);
      rethrow;
    }
  }

  Future<void> _discardCandidate(String token) async {
    try {
      await _request(
        'POST',
        '/logout',
        authenticated: true,
        authorizationToken: token,
      );
    } on MobileAuthException {
      /* The server expiry bounds an unreachable session. */
    }
  }

  Future<void> _persist(String token, MobileUser profile) async {
    final generation = _sessionGeneration;
    await _queueStorage(() async {
      if (generation != _sessionGeneration) return;
      try {
        await _storage.write(
          storageKey,
          jsonEncode({'token': token, 'user': profile.toJson()}),
        );
      } catch (_) {
        throw const MobileAuthException('auth_secure_storage_error');
      }
      // A logout that starts while secure storage is writing wins. Its queued
      // deletion runs after this write; an old refresh cannot revive the user.
      if (generation != _sessionGeneration) return;
      _token = token;
      user.value = profile;
      initializationError.value = null;
    });
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
    String? authorizationToken,
  }) async {
    final token = authorizationToken ?? _token;
    if (authenticated && token == null) {
      throw const MobileAuthException('auth_session_expired');
    }
    try {
      final request = http.Request(
        method,
        Uri.parse('$baseUrl/api/mobile/auth$path'),
      );
      request.followRedirects = false;
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Accept-Language': Get.locale?.languageCode ?? 'en',
        if (authenticated) 'Authorization': 'Bearer $token',
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
      if (response.bodyBytes.length > 1024 * 1024) {
        throw const MobileAuthException('auth_service_unavailable');
      }
      Map<String, dynamic> json = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) json = Map<String, dynamic>.from(decoded);
      } catch (_) {
        /* Handle status below. */
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json['data'];
        return data is Map ? Map<String, dynamic>.from(data) : {};
      }
      if (response.statusCode == 401 && authenticated) {
        if (_token == token) await clearSession();
        throw const MobileAuthException('auth_session_expired');
      }
      if (response.statusCode == 429) {
        throw const MobileAuthException('auth_too_many_attempts');
      }
      final code =
          json['code'] ?? (json['error'] is Map ? json['error']['code'] : null);
      if (code == 'reauthentication_required' || code == 'reauth_required') {
        throw const MobileAuthException('auth_reauthenticate');
      }
      if (code == 'account_link_required') {
        throw const MobileAuthException('auth_link_required');
      }
      if (code == 'identity_already_linked') {
        throw const MobileAuthException('auth_link_conflict');
      }
      if (code == 'email_not_verified' ||
          code == 'email_verification_required') {
        throw const MobileAuthException('auth_verify_first');
      }
      if (response.statusCode == 401) {
        throw const MobileAuthException('auth_invalid_credentials');
      }
      if (response.statusCode == 422 || response.statusCode == 409) {
        if (path == '/login' || path == '/account') {
          throw const MobileAuthException('auth_invalid_credentials');
        }
        if (path == '/verify-email' || path == '/reset-password') {
          throw const MobileAuthException('auth_code_expired');
        }
        throw const MobileAuthException('auth_check_details');
      }
      throw const MobileAuthException('auth_service_unavailable');
    } on MobileAuthException {
      rethrow;
    } catch (_) {
      throw const MobileAuthException('auth_network_error');
    }
  }
}
