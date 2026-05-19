import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_stats_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/conversations_provider.dart';
import 'providers/documents_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/app_shell.dart';
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        Provider<ChatApiService>(
          create: (_) => ChatApiService(baseUrl: apiBaseUrl),
        ),
        Provider<DocumentsApiService>(
          create: (_) => DocumentsApiService(baseUrl: apiBaseUrl),
        ),
        Provider<StatsApiService>(
          create: (_) => StatsApiService(baseUrl: apiBaseUrl),
        ),
        Provider<ConversationsApiService>(
          create: (_) => ConversationsApiService(baseUrl: apiBaseUrl),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (ctx) => ChatProvider(api: ctx.read<ChatApiService>()),
        ),
        ChangeNotifierProvider<DocumentsProvider>(
          create: (ctx) =>
              DocumentsProvider(api: ctx.read<DocumentsApiService>())..refresh(),
        ),
        ChangeNotifierProvider<ConversationsProvider>(
          create: (ctx) => ConversationsProvider(
              api: ctx.read<ConversationsApiService>())
            ..refresh(),
        ),
        ChangeNotifierProvider<AppStatsProvider>(
          create: (ctx) =>
              AppStatsProvider(api: ctx.read<StatsApiService>())
                ..refresh()
                ..startPolling(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, theme, __) => MaterialApp(
          title: 'Nexus AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          home: const AppShell(),
        ),
      ),
    );
  }
}
