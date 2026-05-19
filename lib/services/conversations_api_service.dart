import 'dart:convert';

import '../models/source_citation.dart';
import 'api_client.dart';
import 'chat_api_service.dart' show HttpException;

class ConversationSummary {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  const ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> j) =>
      ConversationSummary(
        id: j['id'].toString(),
        title: (j['title'] ?? 'Untitled').toString(),
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        messageCount: (j['message_count'] ?? 0) as int,
      );
}

class StoredMessage {
  final String id;
  final String role;
  final String content;
  final List<SourceCitation> sources;
  final DateTime createdAt;
  const StoredMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.sources,
    required this.createdAt,
  });

  factory StoredMessage.fromJson(Map<String, dynamic> j) => StoredMessage(
        id: j['id'].toString(),
        role: (j['role'] ?? 'assistant').toString(),
        content: (j['content'] ?? '').toString(),
        sources: ((j['sources'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                SourceCitation.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class ConversationDetail {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<StoredMessage> messages;
  const ConversationDetail({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });
  factory ConversationDetail.fromJson(Map<String, dynamic> j) =>
      ConversationDetail(
        id: j['id'].toString(),
        title: (j['title'] ?? 'Untitled').toString(),
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        messages: ((j['messages'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => StoredMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class ConversationsApiService {
  ConversationsApiService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<ConversationSummary>> list({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final res = await _api.client
        .get(_api.uri('/conversations'), headers: _api.authOnlyHeaders)
        .timeout(timeout);
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw UnauthorizedException();
    }
    if (res.statusCode != 200) {
      throw HttpException(
          'Conversations failed (${res.statusCode}): ${res.body}');
    }
    final raw = jsonDecode(res.body) as List;
    return raw
        .whereType<Map>()
        .map((m) => ConversationSummary.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<ConversationDetail> get(String id) async {
    final res = await _api.client.get(
      _api.uri('/conversations/$id'),
      headers: _api.authOnlyHeaders,
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw UnauthorizedException();
    }
    if (res.statusCode != 200) {
      throw HttpException(
          'Conversation $id failed (${res.statusCode}): ${res.body}');
    }
    return ConversationDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<void> delete(String id) async {
    final res = await _api.client.delete(
      _api.uri('/conversations/$id'),
      headers: _api.authOnlyHeaders,
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw UnauthorizedException();
    }
    if (res.statusCode >= 300 && res.statusCode != 404) {
      throw HttpException(
          'Delete conversation failed (${res.statusCode}): ${res.body}');
    }
  }
}
