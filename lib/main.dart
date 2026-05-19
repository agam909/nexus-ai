import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_stats_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/conversations_provider.dart';
import 'providers/documents_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/chat_api_service.dart';
import 'services/conversations_api_service.dart';
import 'services/documents_api_service.dart';
import 'services/stats_api_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = ThemeProvider();
  await theme.load();
  runApp(NexusApp(themeProvider: theme));
}

class NexusApp extends StatelessWidget {
  const NexusApp({super.key, required this.themeProvider});

  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    );

    // ── Singletons ──
    final api = ApiClient(baseUrl: apiBaseUrl);
    final authService = AuthService(api);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        Provider<ApiClient>.value(value: api),
        Provider<AuthService>.value(value: authService),

        Provider<ChatApiService>(create: (_) => ChatApiService(api: api)),
        Provider<DocumentsApiService>(
            create: (_) => DocumentsApiService(api: api)),
        Provider<StatsApiService>(create: (_) => StatsApiService(api: api)),
        Provider<ConversationsApiService>(
            create: (_) => ConversationsApiService(api: api)),

        ChangeNotifierProvider<AuthProvider>(
          create: (_) =>
              AuthProvider(api: api, authService: authService),
        ),

        // Domain providers — refreshed reactively when auth changes.
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (ctx) => ChatProvider(api: ctx.read<ChatApiService>()),
          update: (_, __, prev) => prev!,
        ),
        ChangeNotifierProxyProvider<AuthProvider, DocumentsProvider>(
          create: (ctx) =>
              DocumentsProvider(api: ctx.read<DocumentsApiService>()),
          update: (ctx, auth, prev) {
            final p = prev ??
                DocumentsProvider(api: ctx.read<DocumentsApiService>());
            if (auth.isAuthenticated) {
              // small post-frame to avoid build-cycle setState
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => p.refresh());
            } else {
              p.clearLocal();
            }
            return p;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ConversationsProvider>(
          create: (ctx) => ConversationsProvider(
              api: ctx.read<ConversationsApiService>()),
          update: (ctx, auth, prev) {
            final p = prev ??
                ConversationsProvider(
                    api: ctx.read<ConversationsApiService>());
            if (auth.isAuthenticated) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => p.refresh());
            } else {
              p.clearLocal();
            }
            return p;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AppStatsProvider>(
          create: (ctx) =>
              AppStatsProvider(api: ctx.read<StatsApiService>()),
          update: (ctx, auth, prev) {
            final p = prev ??
                AppStatsProvider(api: ctx.read<StatsApiService>());
            if (auth.isAuthenticated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                p.refresh();
                p.startPolling();
              });
            } else {
              p.stopPolling();
              p.clearLocal();
            }
            return p;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, theme, __) => MaterialApp(
          title: 'Nexus AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          home: const AuthGate(),
        ),
      ),
    );
  }
}
