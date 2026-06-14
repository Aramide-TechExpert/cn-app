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
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    color: c.brand,
                    child: Text('C',
                        style: AppText.title.copyWith(color: c.onBrand)),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text('Welcome to Clustez',
                      style: AppText.display.copyWith(color: c.text)),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                      'News with signals — impact, trust, and multi-source '
                      'clusters — that links out to the original publishers.',
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
                          return Material(
                            color: on ? c.brand : c.bgInset,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(interestsControllerProvider.notifier)
                                    .toggle(cat.slug);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.lg, vertical: AppSpace.sm),
                                decoration:
                                    BoxDecoration(border: Border.all(color: c.border)),
                                child: Text(cat.name,
                                    style: AppText.callout.copyWith(
                                        color: on ? c.onBrand : c.text,
                                        fontWeight: FontWeight.w600)),
                              ),
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
              child: FilledButton(
                onPressed: finish,
                style: FilledButton.styleFrom(
                  backgroundColor: c.brand,
                  minimumSize: const Size.fromHeight(52),
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text(user == null ? 'Browse for now' : 'Get started'),
              ),
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
      decoration: BoxDecoration(color: c.bgInset),
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
              shape: const RoundedRectangleBorder(),
            ),
            child: const Text('Sign in or create account'),
          ),
        ],
      ),
    );
  }
}
