import 'dart:convert';

import '../models/auth_user.dart';
import 'api_client.dart';

class AuthResult {
  final String token;
  final AuthUser user;
  const AuthResult({required this.token, required this.user});
}

class AuthService {
  AuthService(this._api);
  final ApiClient _api;

  Future<AuthResult> signup({
    required String email,
    required String password,
    String? name,
  }) async {
    final res = await _api.client.post(
      _api.uri('/auth/signup'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (name != null && name.isNotEmpty) 'name': name,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _friendly(res.statusCode, res.body, fallback: 'Signup failed');
    }
    return _parseAuth(res.body);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.client.post(
      _api.uri('/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _friendly(res.statusCode, res.body, fallback: 'Login failed');
    }
    return _parseAuth(res.body);
  }

  /// Validates that the persisted token still works (used on app launch).
  Future<AuthUser> me() async {
    final res = await _api.client
        .get(_api.uri('/auth/me'), headers: _api.authOnlyHeaders);
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw UnauthorizedException();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _friendly(res.statusCode, res.body, fallback: 'Session check failed');
    }
    return AuthUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  AuthResult _parseAuth(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return AuthResult(
      token: (j['access_token'] ?? '').toString(),
      user: AuthUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
    );
  }

  Exception _friendly(int code, String body, {required String fallback}) {
    String detail = fallback;
    try {
      final m = jsonDecode(body);
      if (m is Map && m['detail'] != null) detail = m['detail'].toString();
    } catch (_) {}
    if (code == 401) return ApiException(code, 'Invalid email or password.');
    if (code == 409) return ApiException(code, detail);
    if (code == 422) return ApiException(code, 'Please check your input and try again.');
    return ApiException(code, detail);
  }
}
