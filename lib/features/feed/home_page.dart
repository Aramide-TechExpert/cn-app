import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/feed_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'widgets/article_card.dart';
import 'widgets/spotlight_carousel.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final feed = ref.watch(feedControllerProvider);
    final controller = ref.read(feedControllerProvider.notifier);

    return Scaffold(
      backgroundColor: c.bg,
      body: feed.when(
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: controller.refresh,
        ),
        data: (items) {
          // Top image stories become the swipeable spotlight; the rest list.
          final withImage = items.where((a) => a.hasImage).toList();
          final spotlight = withImage.take(5).toList();
          final spotIds = spotlight.map((a) => a.id).toSet();
          final rest = items.where((a) => !spotIds.contains(a.id)).toList();

          return RefreshIndicator.adaptive(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar.large(
                  backgroundColor: c.bg,
                  surfaceTintColor: Colors.transparent,
                  pinned: true,
                  title: Text('Top Stories',
                      style: AppText.title.copyWith(color: c.text)),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.search, color: c.text),
                      onPressed: () => context.push('/search'),
                    ),
                    const SizedBox(width: AppSpace.xs),
                  ],
                ),
                if (spotlight.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: SpotlightCarousel(articles: spotlight),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
                    child: Text('Latest',
                        style: AppText.headline.copyWith(color: c.text)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  sliver: SliverList.separated(
                    itemCount: rest.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpace.lg),
                    itemBuilder: (context, i) => _Reveal(
                      child: ArticleCard(article: rest[i]),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                    child: controller.hasMore
                        ? const Center(child: CircularProgressIndicator.adaptive())
                        : const SizedBox(height: AppSpace.x3),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One-shot fade + slide-up as an item scrolls into view (subtle native motion).
class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: child,
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Couldn't load the feed",
                textAlign: TextAlign.center,
                style: AppText.headline.copyWith(color: c.text)),
            const SizedBox(height: AppSpace.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: c.textSecondary)),
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: c.brand),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
