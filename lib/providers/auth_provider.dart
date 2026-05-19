import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required ApiClient api, required AuthService authService})
      : _api = api,
        _auth = authService;

  static const _kToken = 'nexus.auth.token';
  static const _kUser = 'nexus.auth.user';

  final ApiClient _api;
  final AuthService _auth;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get error => _error;
  bool get isBusy => _busy;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Called once on app boot. Loads persisted token, then validates it with /auth/me.
  /// If valid → authenticated. Otherwise → unauthenticated (no error UI).
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final cachedUser = prefs.getString(_kUser);

    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _api.setToken(token);

    // Restore cached user immediately so UI renders fast,
    // then verify with the backend in the background.
    if (cachedUser != null && cachedUser.isNotEmpty) {
      try {
        _user = AuthUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(cachedUser) as Map),
        );
      } catch (_) {}
    }

    try {
      final fresh = await _auth.me();
      _user = fresh;
      await _persistUser(fresh);
      _status = AuthStatus.authenticated;
    } catch (_) {
      // Token invalid / network — treat as logged out.
      await _clearStorage();
      _api.setToken(null);
      _user = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> signup({
    required String email,
    required String password,
    String? name,
  }) async {
    return _runAuth(() => _auth.signup(
          email: email.trim().toLowerCase(),
          password: password,
          name: name?.trim(),
        ));
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    return _runAuth(() => _auth.login(
          email: email.trim().toLowerCase(),
          password: password,
        ));
  }

  Future<void> logout() async {
    await _clearStorage();
    _api.setToken(null);
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  /// Called by API services when they hit a 401.
  Future<void> handleUnauthorized() async {
    if (_status != AuthStatus.unauthenticated) {
      await logout();
    }
  }

  // ─── internals ───────────────────────────────────────────

  Future<bool> _runAuth(Future<AuthResult> Function() op) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final result = await op();
      _api.setToken(result.token);
      _user = result.user;
      _status = AuthStatus.authenticated;
      await _persistToken(result.token);
      await _persistUser(result.user);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  Future<void> _persistUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }
}
