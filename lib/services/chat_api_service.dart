import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/source_citation.dart';
import 'api_client.dart';

class ChatResponse {
  final String answer;
  final List<SourceCitation> sources;
  final String? conversationId;

  const ChatResponse({
    required this.answer,
    required this.sources,
    this.conversationId,
  });
}

/// Thin client for the FastAPI RAG backend.
class ChatApiService {
  ChatApiService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<ChatResponse> sendMessage({
    required String message,
    String? conversationId,
    List<Map<String, String>> history = const [],
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final res = await _api.client
        .post(
          _api.uri('/chat'),
          headers: _api.jsonHeaders,
          body: jsonEncode({
            'message': message,
            'conversation_id': conversationId,
            'history': history,
          }),
        )
        .timeout(timeout);

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw UnauthorizedException();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException(
        'Chat request failed (${res.statusCode}): ${res.body}',
      );
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rawSources = (json['sources'] as List?) ?? const [];
    return ChatResponse(
      answer: (json['answer'] ?? '').toString(),
      conversationId: json['conversation_id']?.toString(),
      sources: rawSources
          .whereType<Map>()
          .map((m) => SourceCitation.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }

  /// Streams an assistant reply token-by-token using ndjson.
  Stream<ChatStreamEvent> streamMessage({
    required String message,
    String? conversationId,
    List<Map<String, String>> history = const [],
  }) async* {
    final req = http.Request('POST', _api.uri('/chat/stream'));
    _api.jsonHeaders.forEach((k, v) => req.headers[k] = v);
    req.body = jsonEncode({
      'message': message,
      'conversation_id': conversationId,
      'history': history,
    });

    final streamed = await _api.client.send(req);
    if (streamed.statusCode == 401 || streamed.statusCode == 403) {
      throw UnauthorizedException();
    }
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw HttpException('Stream failed (${streamed.statusCode}): $body');
    }

    String buffer = '';
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final nl = buffer.indexOf('\n');
        if (nl < 0) break;
        final line = buffer.substring(0, nl).trim();
        buffer = buffer.substring(nl + 1);
        if (line.isEmpty) continue;
        try {
          final m = jsonDecode(line) as Map<String, dynamic>;
          final type = (m['type'] ?? '').toString();
          if (type == 'meta') {
            final rawSources = (m['sources'] as List?) ?? const [];
            yield ChatStreamEvent.meta(
              conversationId: m['conversation_id']?.toString(),
              sources: rawSources
                  .whereType<Map>()
                  .map((s) => SourceCitation.fromJson(
                      Map<String, dynamic>.from(s)))
                  .toList(),
            );
          } else if (type == 'token') {
            yield ChatStreamEvent.token((m['value'] ?? '').toString());
          } else if (type == 'error') {
            yield ChatStreamEvent.error((m['value'] ?? '').toString());
          } else if (type == 'done') {
            yield ChatStreamEvent.done();
          }
        } catch (_) {
          // ignore malformed line
        }
      }
    }
  }
}

enum ChatStreamType { meta, token, error, done }

class ChatStreamEvent {
  final ChatStreamType type;
  final String? token;
  final String? errorMessage;
  final String? conversationId;
  final List<SourceCitation> sources;

  const ChatStreamEvent._(
    this.type, {
    this.token,
    this.errorMessage,
    this.conversationId,
    this.sources = const [],
  });

  factory ChatStreamEvent.meta({
    String? conversationId,
    List<SourceCitation> sources = const [],
  }) =>
      ChatStreamEvent._(ChatStreamType.meta,
          conversationId: conversationId, sources: sources);
  factory ChatStreamEvent.token(String value) =>
      ChatStreamEvent._(ChatStreamType.token, token: value);
  factory ChatStreamEvent.error(String msg) =>
      ChatStreamEvent._(ChatStreamType.error, errorMessage: msg);
  factory ChatStreamEvent.done() => const ChatStreamEvent._(ChatStreamType.done);
}

/// Legacy alias kept so other services that imported `HttpException` from here
/// still work without modification.
class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}
