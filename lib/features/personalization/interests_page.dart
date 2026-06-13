import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_controller.dart';
import '../../data/personalization_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../shell/sign_in_required.dart';

/// Your interests — follow/unfollow categories (`user_interests`). Mirrors the
/// web /follow-interests page; writes go straight to Supabase under RLS.
class InterestsPage extends ConsumerWidget {
  const InterestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title:
            Text('Your interests', style: AppText.title.copyWith(color: c.text)),
      ),
      body: user == null
          ? const SignInRequired(
              feature: 'interests',
              message: 'Sign in to follow topics and tailor your feed.')
          : _Picker(),
    );
  }
}

class _Picker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final cats = ref.watch(categoriesProvider);
    final followed = ref.watch(interestsControllerProvider).valueOrNull ??
        const <String>{};

    return cats.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (_, __) => Center(
        child: Text("Couldn't load topics.",
            style: AppText.body.copyWith(color: c.textSecondary)),
      ),
      data: (list) => ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.x3),
        children: [
          Text('Tap to follow the topics you care about.',
              style: AppText.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpace.lg),
          Wrap(
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
                    decoration: BoxDecoration(border: Border.all(color: c.border)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(on ? Icons.check : Icons.add,
                          size: 15, color: on ? c.onBrand : c.textFaint),
                      const SizedBox(width: 5),
                      Text(cat.name,
                          style: AppText.callout.copyWith(
                              color: on ? c.onBrand : c.text,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('${followed.length} followed',
              style: AppText.caption.copyWith(color: c.textFaint)),
        ],
      ),
    );
  }
}
