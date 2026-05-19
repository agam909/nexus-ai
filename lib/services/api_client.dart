import 'package:http/http.dart' as http;

/// Single source of truth for the API base URL + JWT token.
///
/// All API services share one instance, so `setToken()` immediately authenticates
/// every subsequent request across the app.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? _token;

  http.Client get client => _client;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void setToken(String? token) {
    _token = (token != null && token.isNotEmpty) ? token : null;
  }

  /// Headers map you can spread into a request:
  ///   `headers: { ...api.jsonHeaders, 'X-Whatever': '1' }`
  Map<String, String> get jsonHeaders => {
        'Content-Type': 'application/json',
        if (isAuthenticated) 'Authorization': 'Bearer $_token',
      };

  Map<String, String> get authOnlyHeaders =>
      isAuthenticated ? {'Authorization': 'Bearer $_token'} : const {};

  Uri uri(String path) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  void dispose() => _client.close();
}

/// Thrown by services when the backend returns 401/403.
/// Higher-level providers can catch this and force-logout.
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Session expired. Please sign in again.']);
  @override
  String toString() => message;
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Helper to throw the right exception for non-2xx responses.
Never throwForResponse(http.Response res, {String prefix = 'Request failed'}) {
  if (res.statusCode == 401 || res.statusCode == 403) {
    throw UnauthorizedException();
  }
  String detail = res.body;
  try {
    // Most FastAPI errors come back as { "detail": "..." }
    final m = res.body.isNotEmpty ? res.body : '';
    if (m.contains('"detail"')) detail = m;
  } catch (_) {}
  throw ApiException(res.statusCode, '$prefix (${res.statusCode}): $detail');
}
