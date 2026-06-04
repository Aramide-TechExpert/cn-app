import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/feed_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'widgets/article_card.dart';
import 'widgets/magazine_card.dart';
import 'widgets/overlay_card.dart';
import 'widgets/rail_card.dart';
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
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) =>
            _ErrorView(message: e.toString(), onRetry: controller.refresh),
        data: (items) {
          final withImage = items.where((a) => a.hasImage).toList();
          final spotlight = withImage.take(4).toList();
          final rail = withImage.skip(4).take(8).toList();
          final used = {
            ...spotlight.map((a) => a.id),
            ...rail.map((a) => a.id),
          };
          final bento = items
              .where((a) => a.hasImage && !used.contains(a.id))
              .take(4)
              .toList();
          used.addAll(bento.map((a) => a.id));
          final rest = items.where((a) => !used.contains(a.id)).toList();

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

                // Horizontal "Trending now" rail.
                if (rail.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
                      child: Text('Trending now',
                          style: AppText.headline.copyWith(color: c.text)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 232,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                        itemCount: rail.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpace.lg),
                        itemBuilder: (_, i) => RailCard(article: rail[i]),
                      ),
                    ),
                  ),
                ],

                // Bento grid — "Top Stories" 2×2 of full-bleed features.
                if (bento.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
                      child: Text('Top stories',
                          style: AppText.headline.copyWith(color: c.text)),
                    ),
                  ),
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpace.md,
                        crossAxisSpacing: AppSpace.md,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: bento.length,
                      itemBuilder: (_, i) => ClipRect(
                        child: OverlayCard(
                            article: bento[i], height: double.infinity),
                      ),
                    ),
                  ),
                ],

                if (rest.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
                      child: Text('Latest',
                          style: AppText.headline.copyWith(color: c.text)),
                    ),
                  ),

                // Latest — interleaved magazine / overlay / row for rhythm.
                SliverList.builder(
                  itemCount: rest.length + 1,
                  itemBuilder: (context, i) {
                    if (i == rest.length) {
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpace.xl),
                        child: controller.hasMore
                            ? const Center(
                                child: CircularProgressIndicator.adaptive())
                            : const SizedBox(height: AppSpace.lg),
                      );
                    }
                    final a = rest[i];
                    if (i % 6 == 0 && a.hasImage) {
                      return MagazineCard(article: a);
                    }
                    if (i % 6 == 3 && a.hasImage) {
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpace.xs),
                        child: OverlayCard(article: a),
                      );
                    }
                    return ArticleCard(article: a);
                  },
                ),
              ],
            ),
          );
        },
      ),
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
