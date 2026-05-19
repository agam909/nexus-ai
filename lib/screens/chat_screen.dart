import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/conversations_provider.dart';
import '../services/conversations_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        if (wide) {
          return Row(
            children: [
              const SizedBox(
                width: 280,
                child: _ConversationsPanel(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _ChatBody(scrollController: _scrollController, onAfterBuild: _scrollToBottom)),
            ],
          );
        }
        return Scaffold(
          drawer: const Drawer(width: 300, child: _ConversationsPanel()),
          body: _ChatBody(
            scrollController: _scrollController,
            onAfterBuild: _scrollToBottom,
            showMenuButton: true,
          ),
        );
      },
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.scrollController,
    required this.onAfterBuild,
    this.showMenuButton = false,
  });

  final ScrollController scrollController;
  final VoidCallback onAfterBuild;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: showMenuButton
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            : null,
        title: const _AppBarTitle(),
        actions: [
          Consumer<ChatProvider>(
            builder: (_, chat, __) => Row(
              children: [
                if (chat.isSending)
                  IconButton(
                    tooltip: 'Stop generating',
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: chat.stop,
                  ),
                IconButton(
                  tooltip: 'New chat',
                  icon: const Icon(Icons.edit_note_rounded),
                  onPressed: chat.isSending || chat.isEmpty
                      ? null
                      : () {
                          chat.clear();
                          context.read<ConversationsProvider>().setActive(null);
                        },
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (_, chat, __) {
                onAfterBuild();
                if (chat.isEmpty) return const _EmptyState();
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chat.messages.length,
                  itemBuilder: (_, i) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: MessageBubble(
                      key: ValueKey(chat.messages[i].id),
                      message: chat.messages[i],
                    ),
                  ),
                );
              },
            ),
          ),
          Consumer<ChatProvider>(
            builder: (_, chat, __) {
              if (chat.error == null) return const SizedBox.shrink();
              return Material(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: scheme.onErrorContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          chat.error!,
                          style: TextStyle(color: scheme.onErrorContainer),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: chat.retryLast,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Consumer<ChatProvider>(
            builder: (_, chat, __) => ChatInputBar(
              isSending: chat.isSending,
              onSend: chat.sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: scheme.primary.withValues(alpha: 0.15),
          child: Icon(Icons.auto_awesome, color: scheme.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nexus Assistant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.cyberLime,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'RAG ready • Streaming live',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  static const _suggestions = [
    'Summarize the most important document in my library',
    'What is our leave / refund / NDA policy?',
    'Compare the key points across my uploaded files',
    'Draft an executive summary using my knowledge base',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chat = context.read<ChatProvider>();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary.withValues(alpha: 0.4),
                        AppColors.cyberLime.withValues(alpha: 0.25),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.auto_awesome,
                      size: 44, color: scheme.onPrimary),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'How can I help today, Agam?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'I have access to every document you upload. Ask anything and I will ground the answer with sources.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: _suggestions.map((s) {
                  return _SuggestionTile(
                    text: s,
                    onTap: () => chat.sendMessage(s),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationsPanel extends StatelessWidget {
  const _ConversationsPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Conversations',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                Consumer<ConversationsProvider>(
                  builder: (_, c, __) => IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: c.loading ? null : c.refresh,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FilledButton.icon(
              onPressed: () {
                context.read<ChatProvider>().clear();
                context.read<ConversationsProvider>().setActive(null);
                Navigator.of(context).maybePop();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New chat'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<ConversationsProvider>(
              builder: (_, c, __) {
                if (c.loading && c.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (c.items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No conversations yet. Start a new chat to save it here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: c.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (_, i) {
                    final item = c.items[i];
                    final selected = item.id == c.activeId;
                    return _ConversationTile(
                      item: item,
                      selected: selected,
                      onTap: () async {
                        final detail = await c.fetch(item.id);
                        if (detail != null && context.mounted) {
                          context.read<ChatProvider>().loadConversation(detail);
                          Navigator.of(context).maybePop();
                        }
                      },
                      onDelete: () => c.remove(item.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });
  final ConversationSummary item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? scheme.primary : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.messageCount} msgs • ${DateFormat('dd MMM').format(item.updatedAt)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
