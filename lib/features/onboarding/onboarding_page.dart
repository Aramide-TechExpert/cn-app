import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../data/personalization_controller.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// First-run welcome — value prop + a quick interest pick (or a sign-in nudge).
/// Reached from the Home first-run banner; not a router gate (can't soft-lock).
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final cats = ref.watch(categoriesProvider);
    final followed =
        ref.watch(interestsControllerProvider).valueOrNull ?? const <String>{};

    void finish() {
      ref.read(settingsControllerProvider.notifier).markFirstRunSeen();
      context.go('/');
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.x2, AppSpace.lg, AppSpace.lg),
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          c.brand,
                          Color.lerp(c.brand, Colors.black, 0.3)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('C',
                        style: AppText.title
                            .copyWith(color: c.onBrand, fontSize: 26)),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text('Welcome to News Loop',
                      style: AppText.display.copyWith(color: c.text)),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                      'The biggest stories, clustered from many sources and '
                      'scored for impact and trust. We always link you to the '
                      'original publisher.',
                      style: AppText.body
                          .copyWith(color: c.textSecondary, height: 1.5)),
                  const SizedBox(height: AppSpace.xl),
                  if (user == null)
                    _SignInCard(onSignIn: () => context.push('/sign-in'))
                  else ...[
                    Text('Follow a few topics',
                        style: AppText.headline
                            .copyWith(color: c.text, fontSize: 16)),
                    const SizedBox(height: AppSpace.sm),
                    cats.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppSpace.lg),
                        child:
                            Center(child: CircularProgressIndicator.adaptive()),
                      ),
                      error: (_, __) => Text("Couldn't load topics.",
                          style: AppText.body.copyWith(color: c.textSecondary)),
                      data: (list) => Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: list.map((cat) {
                          final on = followed.contains(cat.slug);
                          return InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(interestsControllerProvider.notifier)
                                  .toggle(cat.slug);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.lg,
                                  vertical: AppSpace.sm),
                              decoration: BoxDecoration(
                                color: on ? c.brand : c.bgInset,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (on) ...[
                                      const Icon(Icons.check,
                                          size: 15, color: Colors.white),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(cat.name,
                                        style: AppText.callout.copyWith(
                                            color: on ? c.onBrand : c.text,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(children: [
                if (user != null) ...[
                  // Signed in — offer the full setup wizard.
                  OutlinedButton(
                    onPressed: () => context.push('/setup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.brand,
                      side: BorderSide(color: c.border),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Full setup (profile, sources, alerts)'),
                  ),
                  const SizedBox(height: AppSpace.sm),
                ],
                FilledButton(
                  onPressed: finish,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.brand,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  child: Text(user == null ? 'Browse for now' : 'Get started'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.brand.withValues(alpha: 0.14), c.bgInset],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personalize your feed',
              style: AppText.headline.copyWith(color: c.text, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Sign in to follow topics, save stories, and sync across devices.',
              style: AppText.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpace.md),
          FilledButton(
            onPressed: onSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: c.brand,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Sign in or create account'),
          ),
        ],
      ),
    );
  }
}
