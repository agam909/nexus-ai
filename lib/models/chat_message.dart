import 'source_citation.dart';

enum MessageRole { user, assistant, system }

enum MessageStatus { sending, sent, failed }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final List<SourceCitation> sources;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.sources = const [],
    this.status = MessageStatus.sent,
  });

  bool get isUser => role == MessageRole.user;

  ChatMessage copyWith({
    String? content,
    List<SourceCitation>? sources,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      sources: sources ?? this.sources,
      status: status ?? this.status,
    );
  }
}
