import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/strings.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(backendProvider).auth.signIn();
    } on SignInCancelledException {
      // uživatel okno zavřel – bez hlášení
    } on NotAllowlistedException {
      _error = S.notAllowlisted;
    } catch (e) {
      _error = '${S.signInFailed}\n$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final demo = ref.watch(backendProvider).isDemo;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(Icons.forum_rounded, size: 44, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    S.appName,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    S.tagline,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _signIn,
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(demo ? Icons.play_arrow_rounded : Icons.login_rounded),
                      label: Text(demo ? S.enterDemo : S.signInGoogle),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  if (demo) ...[
                    const SizedBox(height: 16),
                    Text(
                      S.demoBanner,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
