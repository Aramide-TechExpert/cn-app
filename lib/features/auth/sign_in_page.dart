import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

enum _Mode { signIn, signUp }

class _SignInPageState extends ConsumerState<SignInPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.signIn;
  String? _busy; // 'email' | 'google'
  String? _error;
  String? _notice;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(String kind, Future<void> Function() action) async {
    setState(() {
      _busy = kind;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _submitEmail() {
    final auth = ref.read(authServiceProvider);
    return _run('email', () async {
      final email = _email.text.trim();
      final pw = _password.text;
      if (email.isEmpty || pw.isEmpty) {
        throw 'Enter your email and password.';
      }
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        throw 'That email address doesn’t look right.';
      }
      if (_mode == _Mode.signIn) {
        await auth.signInWithEmail(email, pw);
      } else {
        if (pw.length < 8) {
          throw 'Password needs at least 8 characters.';
        }
        final hasSession = await auth.signUpWithEmail(email, pw,
            displayName: _name.text.trim());
        if (!hasSession && mounted) {
          setState(() {
            _notice = 'Check your inbox to confirm your email, then sign in.';
            _mode = _Mode.signIn;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // On auth: brand-new accounts (email signup OR first Google sign-in,
    // detected by creation time) land in the setup wizard; returning
    // sign-ins just dismiss back to where they were.
    ref.listen(currentUserProvider, (_, user) {
      if (user == null) return;
      final created = DateTime.tryParse(user.createdAt);
      final isNew = created != null &&
          DateTime.now().toUtc().difference(created.toUtc()).inMinutes < 3;
      if (isNew) {
        context.go('/setup');
      } else if (context.canPop()) {
        context.pop();
      }
    });

    final disabled = _busy != null;
    final isSignIn = _mode == _Mode.signIn;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.x2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => context.canPop() ? context.pop() : null,
                  icon: Icon(Icons.close, color: c.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text('CLUSTEZ',
                  style: AppText.micro
                      .copyWith(color: c.brand, letterSpacing: 1.2)),
              const SizedBox(height: AppSpace.xs),
              Text(isSignIn ? 'Welcome back' : 'Create account',
                  style: AppText.display.copyWith(color: c.text)),
              const SizedBox(height: AppSpace.xs),
              Text('Sync your saved stories, interests, and briefing across devices.',
                  style: AppText.body.copyWith(color: c.textSecondary)),
              const SizedBox(height: AppSpace.xl),
              if (!isSignIn) ...[
                _Field(
                  controller: _name,
                  hint: 'Your name',
                  keyboardType: TextInputType.name,
                  enabled: !disabled,
                ),
                const SizedBox(height: AppSpace.md),
              ],
              _Field(
                controller: _email,
                hint: 'Email',
                keyboardType: TextInputType.emailAddress,
                enabled: !disabled,
              ),
              const SizedBox(height: AppSpace.md),
              _Field(
                controller: _password,
                hint: isSignIn ? 'Password' : 'Password (8+ characters)',
                obscure: !_showPassword,
                enabled: !disabled,
                onSubmitted: (_) => _submitEmail(),
                suffix: IconButton(
                  icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: c.textFaint),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(_error!, style: AppText.caption.copyWith(color: c.critical)),
              ],
              if (_notice != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(_notice!, style: AppText.caption.copyWith(color: c.success)),
              ],
              const SizedBox(height: AppSpace.lg),
              FilledButton(
                onPressed: disabled ? null : _submitEmail,
                style: FilledButton.styleFrom(
                  backgroundColor: c.brand,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _busy == 'email'
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isSignIn ? 'Sign in' : 'Create account'),
              ),
              const SizedBox(height: AppSpace.md),
              TextButton(
                onPressed: disabled
                    ? null
                    : () => setState(() {
                          _mode = isSignIn ? _Mode.signUp : _Mode.signIn;
                          _error = null;
                          _notice = null;
                        }),
                child: Text(
                  isSignIn
                      ? 'New here? Create an account'
                      : 'Already have an account? Sign in',
                  style: AppText.callout.copyWith(color: c.brand),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(children: [
                Expanded(child: Divider(color: c.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  child: Text('or continue with',
                      style: AppText.caption.copyWith(color: c.textFaint)),
                ),
                Expanded(child: Divider(color: c.border)),
              ]),
              const SizedBox(height: AppSpace.lg),
              OutlinedButton.icon(
                onPressed: disabled
                    ? null
                    : () => _run('google',
                        ref.read(authServiceProvider).signInWithGoogle),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: c.border),
                ),
                icon: _busy == 'google'
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.g_mobiledata, size: 26, color: c.text),
                label: Text('Continue with Google',
                    style: AppText.body
                        .copyWith(color: c.text, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                'You can keep reading without an account — sign in only to save and sync.',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: c.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: !obscure,
      onSubmitted: onSubmitted,
      style: TextStyle(color: c.text, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textFaint),
        suffixIcon: suffix,
        filled: true,
        fillColor: c.bgInset,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: c.brand),
        ),
      ),
    );
  }
}
