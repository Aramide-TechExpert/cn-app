import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../data/saved_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../feed/widgets/article_card.dart';

class SavedPage extends ConsumerWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: user == null
            ? _SignedOut(onSignIn: () => context.push('/sign-in'))
            : _SavedList(),
      ),
    );
  }
}

class _SavedList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final saved = ref.watch(savedArticlesProvider);

    return RefreshIndicator(
      color: c.brand,
      onRefresh: () async => ref.invalidate(savedArticlesProvider),
      child: saved.when(
        loading: () => Center(child: CircularProgressIndicator(color: c.brand)),
        error: (_, __) => ListView(children: [
          const SizedBox(height: AppSpace.x4),
          Center(
            child: Text("Couldn't load saved stories.",
                style: AppText.body.copyWith(color: c.textSecondary)),
          ),
        ]),
        data: (items) => items.isEmpty
            ? ListView(children: [
                const SizedBox(height: AppSpace.x4),
                Icon(Icons.bookmark_border,
                    size: 44, color: c.textFaint),
                const SizedBox(height: AppSpace.md),
                Center(
                  child: Text('Nothing saved yet',
                      style: AppText.headline.copyWith(color: c.text)),
                ),
                const SizedBox(height: AppSpace.xs),
                Center(
                  child: Text('Tap the bookmark on any story to save it here.',
                      style: AppText.body.copyWith(color: c.textSecondary)),
                ),
              ])
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.x3),
                itemCount: items.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpace.lg),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: Text('Saved',
                          style: AppText.display.copyWith(color: c.text)),
                    );
                  }
                  return ArticleCard(article: items[i - 1]);
                },
              ),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 44, color: c.brand),
            const SizedBox(height: AppSpace.lg),
            Text('Sign in to save stories',
                style: AppText.title.copyWith(color: c.text)),
            const SizedBox(height: AppSpace.sm),
            Text('Your bookmarks sync across devices.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: c.textSecondary)),
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              onPressed: onSignIn,
              style: FilledButton.styleFrom(
                backgroundColor: c.brand,
                minimumSize: const Size(220, 50),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
