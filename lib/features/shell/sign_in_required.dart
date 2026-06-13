import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Empty-state shown on signed-in-only surfaces (interests, watchlists, …)
/// when there's no session. Mirrors the web `SignInRequired`.
class SignInRequired extends StatelessWidget {
  const SignInRequired({super.key, required this.feature, required this.message});
  final String feature;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 40, color: c.textFaint),
            const SizedBox(height: AppSpace.md),
            Text('Sign in for $feature',
                textAlign: TextAlign.center,
                style: AppText.headline.copyWith(color: c.text)),
            const SizedBox(height: AppSpace.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: c.textSecondary)),
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              onPressed: () => context.push('/sign-in'),
              style: FilledButton.styleFrom(
                backgroundColor: c.brand,
                shape: const RoundedRectangleBorder(),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
