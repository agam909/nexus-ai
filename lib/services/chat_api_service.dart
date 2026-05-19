import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/source_citation.dart';

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
///
/// Expected backend contract:
///   POST {baseUrl}/chat
///   Body: { "message": str, "conversation_id": str | null, "history": [...] }
///   Resp: { "answer": str, "sources": [{file_name, page, url?, snippet?}], "conversation_id": str }
class ChatApiService {
  ChatApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<ChatResponse> sendMessage({
    required String message,
    String? conversationId,
    List<Map<String, String>> history = const [],
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = Uri.parse('$baseUrl/chat');
    final res = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'conversation_id': conversationId,
            'history': history,
          }),
        )
        .timeout(timeout);

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
  /// The backend `/chat/stream` endpoint emits one JSON object per line:
  ///   {"type":"meta","conversation_id":...,"sources":[...]}
  ///   {"type":"token","value":"..."}
  ///   {"type":"done"}
  Stream<ChatStreamEvent> streamMessage({
    required String message,
    String? conversationId,
    List<Map<String, String>> history = const [],
  }) async* {
    final uri = Uri.parse('$baseUrl/chat/stream');
    final req = http.Request('POST', uri);
    req.headers['Content-Type'] = 'application/json';
    req.body = jsonEncode({
      'message': message,
      'conversation_id': conversationId,
      'history': history,
    });

    final streamed = await _client.send(req);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw HttpException(
        'Stream failed (${streamed.statusCode}): $body',
      );
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

  void dispose() => _client.close();
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

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}
