import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../data/engagement_controller.dart';
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

    if (user == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(child: _SignedOut(onSignIn: () => context.push('/sign-in'))),
      );
    }

    final saved = ref.watch(savedArticlesProvider);
    final items = saved.valueOrNull;

    return Scaffold(
      backgroundColor: c.bg,
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.invalidate(savedArticlesProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar.large(
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              title: Text('Saved', style: AppText.title.copyWith(color: c.text)),
            ),
            if (items == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Empty(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, 0, AppSpace.lg, AppSpace.x3),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpace.lg),
                  itemBuilder: (_, i) {
                    final a = items[i];
                    final dbId = a.dbId;
                    if (dbId == null) return ArticleCard(article: a);
                    return Slidable(
                      key: ValueKey(dbId),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.3,
                        children: [
                          SlidableAction(
                            onPressed: (_) => ref
                                .read(engagementProvider.notifier)
                                .toggleBookmark(dbId),
                            backgroundColor: c.critical,
                            foregroundColor: Colors.white,
                            icon: Icons.bookmark_remove,
                            label: 'Remove',
                            borderRadius:
                                BorderRadius.circular(AppRadii.lg),
                          ),
                        ],
                      ),
                      child: ArticleCard(article: a),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 44, color: c.textFaint),
            const SizedBox(height: AppSpace.md),
            Text('Nothing saved yet',
                style: AppText.headline.copyWith(color: c.text)),
            const SizedBox(height: AppSpace.xs),
            Text('Tap the bookmark on any story to save it here.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: c.textSecondary)),
          ],
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
