import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_stats_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Profile'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.cyan,
                          child: Text('AG',
                              style: TextStyle(
                                  color: AppColors.midnight,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18)),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Agam',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text('AI Knowledge Operator',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        Consumer<AppStatsProvider>(
                          builder: (_, s, __) => Chip(
                            avatar: Icon(
                              s.backendOnline
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              size: 16,
                              color: s.backendOnline
                                  ? AppColors.cyan
                                  : AppColors.danger,
                            ),
                            label: Text(s.backendOnline ? 'Connected' : 'Offline'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Appearance'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(
                          theme.isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: scheme.primary,
                        ),
                        title: const Text('Dark Mode'),
                        subtitle: const Text(
                            'Corporate Midnight palette with Cyan accents'),
                        value: theme.isDark,
                        onChanged: (_) => theme.toggle(),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: Icon(Icons.notifications_active_rounded,
                            color: scheme.primary),
                        title: const Text('Indexing notifications'),
                        subtitle: const Text(
                            'Get a toast when a document finishes indexing'),
                        value: _notifications,
                        onChanged: (v) => setState(() => _notifications = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('AI Engine'),
                Consumer<AppStatsProvider>(
                  builder: (_, s, __) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.memory_rounded, color: scheme.primary),
                              const SizedBox(width: 10),
                              const Text('Active Model',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Refresh',
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: s.loading ? null : s.refresh,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.health.model,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.backendOnline
                                ? (s.health.groqConfigured
                                    ? 'Groq API key configured • LangChain RAG live'
                                    : 'Backend reachable but GROQ_API_KEY missing in backend/.env')
                                : 'Backend is not reachable. Run backend\\run.ps1',
                            style: TextStyle(
                                color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Chat'),
                Consumer<ChatProvider>(
                  builder: (_, chat, __) => Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Icon(Icons.bolt_rounded, color: scheme.primary),
                          title: const Text('Stream responses'),
                          subtitle: const Text(
                              'See answers token-by-token as they are generated'),
                          value: chat.streamingEnabled,
                          onChanged: chat.setStreamingEnabled,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.delete_sweep_rounded, color: scheme.error),
                          title: const Text('Clear all conversations'),
                          subtitle: const Text(
                              'Remove every saved chat from the backend'),
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete all conversations?'),
                                content: const Text(
                                    'This permanently removes every chat from the server. Your indexed documents stay.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: scheme.error),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            final convs = context.read<ConversationsProvider>();
                            for (final c in List.of(convs.items)) {
                              await convs.remove(c.id);
                            }
                            chat.clear();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('About'),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline_rounded,
                        color: scheme.primary),
                    title: const Text('Nexus AI'),
                    subtitle: const Text('Version 0.1.0 • RAG client'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
