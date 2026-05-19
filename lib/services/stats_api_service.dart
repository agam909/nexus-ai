import 'dart:async';
import 'dart:convert';

import 'api_client.dart';
import 'chat_api_service.dart' show HttpException;

class BackendStats {
  final int documents;
  final int chunks;
  final int conversations;
  final int messages;
  final String model;

  const BackendStats({
    required this.documents,
    required this.chunks,
    required this.conversations,
    required this.messages,
    required this.model,
  });

  factory BackendStats.fromJson(Map<String, dynamic> j) => BackendStats(
        documents: (j['documents'] ?? 0) as int,
        chunks: (j['chunks'] ?? 0) as int,
        conversations: (j['conversations'] ?? 0) as int,
        messages: (j['messages'] ?? 0) as int,
        model: (j['model'] ?? 'unknown').toString(),
      );

  static const empty = BackendStats(
    documents: 0,
    chunks: 0,
    conversations: 0,
    messages: 0,
    model: '—',
  );
}

class HealthInfo {
  final bool ok;
  final bool groqConfigured;
  final String model;
  const HealthInfo({
    required this.ok,
    required this.groqConfigured,
    required this.model,
  });
  static const offline =
      HealthInfo(ok: false, groqConfigured: false, model: '—');
}

class StatsApiService {
  StatsApiService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<BackendStats> fetchStats({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final res = await _api.client
        .get(_api.uri('/stats'), headers: _api.authOnlyHeaders)
        .timeout(timeout);
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw UnauthorizedException();
    }
    if (res.statusCode != 200) {
      throw HttpException('Stats failed (${res.statusCode}): ${res.body}');
    }
    return BackendStats.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  /// Public endpoint - no auth required.
  Future<HealthInfo> health({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final res = await _api.client.get(_api.uri('/health')).timeout(timeout);
      if (res.statusCode != 200) return HealthInfo.offline;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return HealthInfo(
        ok: (j['status'] ?? '') == 'ok',
        groqConfigured: (j['groq_configured'] ?? false) as bool,
        model: (j['model'] ?? '—').toString(),
      );
    } catch (_) {
      return HealthInfo.offline;
    }
  }
}
