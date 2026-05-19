import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_stats_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/documents_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/hex_logo.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: const HexLogo(size: 38, label: 'NEXUS AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.cyan,
            child: Text('AG',
                style: TextStyle(
                    color: AppColors.midnight,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Header(),
                SizedBox(height: 24),
                _StatsRow(),
                SizedBox(height: 28),
                _QuickActions(),
                SizedBox(height: 28),
                _RecentActivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, Agam',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your AI knowledge hub is ready. Ask anything or grow the brain.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Consumer2<DocumentsProvider, AppStatsProvider>(
      builder: (_, docs, stats, __) {
        final lastSync = docs.lastSync;
        final remoteDocs = stats.stats.documents;
        final chunks = stats.stats.chunks;
        final convs = stats.stats.conversations;
        final online = stats.backendOnline;
        return LayoutBuilder(
          builder: (_, c) {
            final cols = c.maxWidth >= 1100
                ? 4
                : (c.maxWidth >= 760
                    ? 3
                    : (c.maxWidth >= 480 ? 2 : 1));
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: cols == 1 ? 3.2 : 2.0,
              children: [
                _StatCard(
                  icon: Icons.menu_book_rounded,
                  label: 'Documents',
                  value: '$remoteDocs',
                  accent: AppColors.cyan,
                  numeric: true,
                ),
                _StatCard(
                  icon: Icons.bubble_chart_rounded,
                  label: 'Knowledge Chunks',
                  value: '$chunks',
                  accent: AppColors.cyberLime,
                  numeric: true,
                ),
                _StatCard(
                  icon: Icons.forum_rounded,
                  label: 'Conversations',
                  value: '$convs',
                  accent: AppColors.warning,
                  numeric: true,
                ),
                _StatCard(
                  icon: online
                      ? Icons.bolt_rounded
                      : Icons.cloud_off_rounded,
                  label: 'Backend',
                  value: online
                      ? (docs.isBusy ? 'Indexing…' : 'Online')
                      : 'Offline',
                  accent: online
                      ? (docs.isBusy ? AppColors.warning : AppColors.cyan)
                      : AppColors.danger,
                  pulse: docs.isBusy || !online,
                  subtitle: online
                      ? stats.health.model
                      : (lastSync == null
                          ? 'Start the FastAPI server'
                          : 'Last synced ${DateFormat('HH:mm').format(lastSync)}'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.pulse = false,
    this.numeric = false,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool pulse;
  final bool numeric;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.10),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const Spacer(),
                if (pulse) _PulseDot(color: accent),
              ],
            ),
            const SizedBox(height: 14),
            Text(label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 4),
            numeric
                ? _AnimatedCounter(
                    value: int.tryParse(value) ?? 0,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  )
                : Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnimatedCounter extends StatelessWidget {
  const _AnimatedCounter({required this.value, required this.style});
  final int value;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(v.round().toString(), style: style),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.5 + 0.5 * _c.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6 * _c.value),
              blurRadius: 8 * _c.value,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.forum_rounded,
            title: 'Start New Chat',
            subtitle: 'Ask the AI grounded in your docs',
            color: AppColors.cyan,
            onTap: () {
              // Lives inside AppShell IndexedStack; user can tap nav too.
              final scaffold = ScaffoldMessenger.of(context);
              scaffold.showSnackBar(
                const SnackBar(content: Text('Open the Chat tab to begin')),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionCard(
            icon: Icons.cloud_upload_rounded,
            title: 'Upload New Document',
            subtitle: 'Grow the AI brain instantly',
            color: AppColors.cyberLime,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Open the Documents tab to upload')),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chat = context.watch<ChatProvider>();
    final recent = chat.messages.where((m) => m.isUser).toList().reversed.take(6).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                const Text('Recent Activity',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No recent questions yet — head to Chat to ask one.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              ...recent.map(
                (m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_right_rounded,
                          color: scheme.primary, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(m.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14)),
                      ),
                      Text(DateFormat.jm().format(m.createdAt),
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
