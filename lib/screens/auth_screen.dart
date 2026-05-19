import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/hex_logo.dart';

enum _AuthMode { signIn, signUp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final pw = _password.text;
    final name = _name.text.trim();

    final ok = _mode == _AuthMode.signIn
        ? await auth.login(email: email, password: pw)
        : await auth.signup(email: email, password: pw, name: name);

    if (!mounted) return;
    if (!ok && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(auth.error!.replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSignUp = _mode == _AuthMode.signUp;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // ── glow background ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.7),
                  radius: 1.4,
                  colors: [
                    scheme.primary.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, 0.9),
                  radius: 1.2,
                  colors: [
                    AppColors.cyberLime.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── card ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(
                              child: HexLogo(size: 64, label: 'NEXUS'),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              isSignUp
                                  ? 'Create your account'
                                  : 'Welcome back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isSignUp
                                  ? 'Your private knowledge base, encrypted to your account.'
                                  : 'Sign in to access your knowledge base.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 28),

                            if (isSignUp) ...[
                              TextFormField(
                                controller: _name,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Display name (optional)',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return 'Email is required';
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(s)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: [
                                isSignUp
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) {
                                final s = v ?? '';
                                if (s.isEmpty) return 'Password is required';
                                if (isSignUp && s.length < 6) {
                                  return 'At least 6 characters';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) =>
                                  auth.isBusy ? null : _submit(),
                            ),

                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: auth.isBusy ? null : _submit,
                              child: auth.isBusy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                  : Text(isSignUp
                                      ? 'Create account'
                                      : 'Sign in'),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isSignUp
                                      ? 'Already have an account?'
                                      : "Don't have an account?",
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant),
                                ),
                                TextButton(
                                  onPressed: auth.isBusy ? null : _toggleMode,
                                  child:
                                      Text(isSignUp ? 'Sign in' : 'Sign up'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
