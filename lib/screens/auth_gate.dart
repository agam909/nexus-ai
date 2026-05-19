import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/hex_logo.dart';
import 'app_shell.dart';
import 'auth_screen.dart';

/// Boots the auth state, then routes to either the auth screen or the main app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.status == AuthStatus.unknown) {
        auth.bootstrap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    Widget child;
    switch (auth.status) {
      case AuthStatus.unknown:
        child = const _Splash(key: ValueKey('splash'));
        break;
      case AuthStatus.unauthenticated:
        child = const AuthScreen(key: ValueKey('auth'));
        break;
      case AuthStatus.authenticated:
        child = const AppShell(key: ValueKey('app'));
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HexLogo(size: 80, label: 'NEXUS'),
            const SizedBox(height: 32),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
