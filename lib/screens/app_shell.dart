import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/documents_provider.dart';
import '../widgets/hex_logo.dart';
import 'chat_screen.dart';
import 'dashboard_screen.dart';
import 'documents_screen.dart';
import 'settings_screen.dart';

class _NavDest {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  const _NavDest(this.label, this.icon, this.selectedIcon, this.page);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = <_NavDest>[
    _NavDest('Dashboard', Icons.dashboard_outlined,
        Icons.dashboard_rounded, DashboardScreen()),
    _NavDest('Chat', Icons.chat_bubble_outline,
        Icons.chat_bubble_rounded, ChatScreen()),
    _NavDest('Documents', Icons.folder_outlined,
        Icons.folder_rounded, DocumentsScreen()),
    _NavDest('Settings', Icons.settings_outlined,
        Icons.settings_rounded, SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 800;
        final body = IndexedStack(
          index: _index,
          children: _destinations.map((d) => d.page).toList(),
        );

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                _SideRail(
                  index: _index,
                  destinations: _destinations,
                  onSelect: (i) => setState(() => _index = i),
                  extended: c.maxWidth >= 1100,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.index,
    required this.destinations,
    required this.onSelect,
    required this.extended,
  });

  final int index;
  final List<_NavDest> destinations;
  final ValueChanged<int> onSelect;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final railWidth = extended ? 240.0 : 88.0;

    return Container(
      width: railWidth,
      color: Theme.of(context).navigationRailTheme.backgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 20 : 0),
            child: extended
                ? const HexLogo(size: 44, label: 'NEXUS AI')
                : const HexLogo(size: 44),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onSelect,
              extended: extended,
              minExtendedWidth: railWidth,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          Consumer<DocumentsProvider>(
            builder: (_, docs, __) {
              if (!docs.isBusy) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(12),
                child: extended
                    ? Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Indexing ${docs.inProgressCount} doc(s)…',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Tooltip(
                        message: 'Indexing ${docs.inProgressCount}…',
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: scheme.primary,
                          ),
                        ),
                      ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
