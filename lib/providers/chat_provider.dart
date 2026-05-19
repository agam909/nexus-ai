import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/source_citation.dart';
import '../services/chat_api_service.dart';
import '../services/conversations_api_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({required ChatApiService api}) : _api = api;

  final ChatApiService _api;
  final _uuid = const Uuid();

  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  String? _error;
  String? _conversationId;
  bool _streamingEnabled = true;
  StreamSubscription? _streamSub;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  String? get error => _error;
  bool get isEmpty => _messages.isEmpty;
  String? get conversationId => _conversationId;
  bool get streamingEnabled => _streamingEnabled;

  void setStreamingEnabled(bool v) {
    _streamingEnabled = v;
    notifyListeners();
  }

  /// Replaces the current chat with a saved server-side conversation.
  void loadConversation(ConversationDetail detail) {
    _streamSub?.cancel();
    _messages
      ..clear()
      ..addAll(detail.messages.map(
        (m) => ChatMessage(
          id: m.id,
          role: m.role == 'user' ? MessageRole.user : MessageRole.assistant,
          content: m.content,
          createdAt: m.createdAt,
          sources: m.sources,
          status: MessageStatus.sent,
        ),
      ));
    _conversationId = detail.id;
    _error = null;
    _isSending = false;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );
    _messages.add(userMsg);

    final placeholder = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    _messages.add(placeholder);

    _isSending = true;
    _error = null;
    notifyListeners();

    final history = _messages
        .where((m) =>
            m.id != placeholder.id &&
            m.id != userMsg.id &&
            m.status == MessageStatus.sent &&
            m.content.isNotEmpty)
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    if (_streamingEnabled) {
      await _runStreaming(trimmed, history, placeholder.id);
    } else {
      await _runOnce(trimmed, history, placeholder.id);
    }
  }

  Future<void> _runOnce(
      String text, List<Map<String, String>> history, String placeholderId) async {
    try {
      final res = await _api.sendMessage(
        message: text,
        conversationId: _conversationId,
        history: history,
      );
      _conversationId = res.conversationId ?? _conversationId;
      _replacePlaceholder(
        placeholderId,
        content: res.answer,
        sources: res.sources,
        status: MessageStatus.sent,
      );
    } catch (e) {
      _error = e.toString();
      _replacePlaceholder(
        placeholderId,
        content: 'Sorry, I could not reach the assistant.\n\n_${e}_',
        status: MessageStatus.failed,
      );
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> _runStreaming(
      String text, List<Map<String, String>> history, String placeholderId) async {
    final buffer = StringBuffer();
    List<SourceCitation> sources = const [];
    final completer = Completer<void>();
    _streamSub = _api
        .streamMessage(
          message: text,
          conversationId: _conversationId,
          history: history,
        )
        .listen(
      (ev) {
        switch (ev.type) {
          case ChatStreamType.meta:
            _conversationId = ev.conversationId ?? _conversationId;
            sources = ev.sources;
            _replacePlaceholder(placeholderId, sources: sources);
            break;
          case ChatStreamType.token:
            buffer.write(ev.token ?? '');
            _replacePlaceholder(
              placeholderId,
              content: buffer.toString(),
              status: MessageStatus.sending,
            );
            break;
          case ChatStreamType.error:
            _error = ev.errorMessage;
            break;
          case ChatStreamType.done:
            break;
        }
      },
      onError: (e) {
        _error = e.toString();
        _replacePlaceholder(
          placeholderId,
          content: buffer.isEmpty
              ? 'Sorry, I could not reach the assistant.\n\n_${e}_'
              : buffer.toString(),
          status: MessageStatus.failed,
        );
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        _replacePlaceholder(
          placeholderId,
          content: buffer.toString(),
          sources: sources,
          status: _error != null && buffer.isEmpty
              ? MessageStatus.failed
              : MessageStatus.sent,
        );
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );
    await completer.future;
    _isSending = false;
    notifyListeners();
  }

  void _replacePlaceholder(
    String placeholderId, {
    String? content,
    List<SourceCitation>? sources,
    MessageStatus? status,
  }) {
    final idx = _messages.indexWhere((m) => m.id == placeholderId);
    if (idx == -1) return;
    _messages[idx] = _messages[idx].copyWith(
      content: content,
      sources: sources,
      status: status,
    );
    notifyListeners();
  }

  void stop() {
    _streamSub?.cancel();
    _streamSub = null;
    _isSending = false;
    notifyListeners();
  }

  void retryLast() {
    final lastUser = _messages.lastWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => ChatMessage(
        id: '',
        role: MessageRole.user,
        content: '',
        createdAt: DateTime.now(),
      ),
    );
    if (lastUser.content.isNotEmpty) {
      // Drop trailing failed assistant + user, then resend
      while (_messages.isNotEmpty &&
          _messages.last.role == MessageRole.assistant &&
          _messages.last.status == MessageStatus.failed) {
        _messages.removeLast();
      }
      if (_messages.isNotEmpty && _messages.last.id == lastUser.id) {
        _messages.removeLast();
      }
      sendMessage(lastUser.content);
    }
  }

  void clear() {
    _streamSub?.cancel();
    _streamSub = null;
    _messages.clear();
    _conversationId = null;
    _error = null;
    _isSending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}
