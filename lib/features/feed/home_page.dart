import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/dismissed_controller.dart';
import '../../data/feed_controller.dart';
import '../../data/personalization_controller.dart';
import '../../data/reading_history.dart';
import '../../data/settings_controller.dart';
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../shell/app_drawer.dart';
import 'widgets/article_card.dart';
import 'widgets/bento_mosaic.dart';
import 'widgets/card_variants.dart';
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
    // Personalized rail — articles from the user's followed categories.
    final forYou = ref.watch(forYouFeedProvider).valueOrNull ?? const <Article>[];
    final firstRun = !ref.watch(settingsControllerProvider).firstRunSeen;
    final dismissed = ref.watch(dismissedProvider);

    return Scaffold(
      backgroundColor: c.bg,
      drawer: const AppDrawer(),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) =>
            _ErrorView(message: e.toString(), onRetry: controller.refresh),
        data: (allItems) {
          // Drop "not interested" stories everywhere on Home.
          final items =
              allItems.where((a) => !dismissed.contains(a.id)).toList();
          final withImage = items.where((a) => a.hasImage).toList();
          final spotlight = withImage.take(5).toList();
          final rail = withImage.skip(5).take(6).toList();
          // Bento mosaic — a compact 2-up grid of "Top stories" (web bento feel)
          // in a fitted slot below the rails.
          final bento = withImage.skip(11).take(4).toList();
          // Shorts rail is sourced strictly from real in-article video
          // (flagged at ingest) — not arbitrary articles.
          final shorts =
              withImage.where((a) => a.hasPlayableVideo).take(10).toList();
          final used = {
            ...spotlight.map((a) => a.id),
            ...rail.map((a) => a.id),
            ...bento.map((a) => a.id),
            ...shorts.map((a) => a.id),
          };
          // Everything else flows into the interleaved feed (magazine / overlay
          // / row) so the varied cards are the bulk of Home, not a grid block.
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
                  leading: Builder(
                    builder: (ctx) => IconButton(
                      icon: Icon(Icons.menu, color: c.text),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  title: Text('Top Stories',
                      style: AppText.title.copyWith(color: c.text)),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.view_carousel_outlined, color: c.text),
                      tooltip: 'Stack',
                      onPressed: () => context.push('/stack'),
                    ),
                    IconButton(
                      icon: Icon(Icons.search, color: c.text),
                      onPressed: () => context.push('/search'),
                    ),
                    const SizedBox(width: AppSpace.xs),
                  ],
                ),
                // First-run welcome banner (dismissible — never gates the app).
                if (firstRun)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(
                          AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
                      padding: const EdgeInsets.all(AppSpace.lg),
                      color: c.brandSoft,
                      child: Row(children: [
                        Icon(Icons.auto_awesome, color: c.brand, size: 20),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome to Clustez',
                                  style:
                                      AppText.bodyStrong.copyWith(color: c.text)),
                              Text('Personalize your feed in a few taps',
                                  style: AppText.caption
                                      .copyWith(color: c.textSecondary)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/onboarding'),
                          child: Text('Set up',
                              style: AppText.callout.copyWith(color: c.brand)),
                        ),
                        InkResponse(
                          onTap: () => ref
                              .read(settingsControllerProvider.notifier)
                              .markFirstRunSeen(),
                          child: Icon(Icons.close, size: 18, color: c.textFaint),
                        ),
                      ]),
                    ),
                  ),

                if (spotlight.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: SpotlightCarousel(articles: spotlight),
                    ),
                  ),

                // For You — personalized rail from followed interests.
                if (forYou.isNotEmpty) ...[
                  _railHeader(context, 'For You'),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 224,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                        itemCount: forYou.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpace.lg),
                        itemBuilder: (_, i) => RailCard(article: forYou[i]),
                      ),
                    ),
                  ),
                ],

                // Continue reading (local history).
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<List<Article>>(
                    valueListenable: ReadingHistory.items,
                    builder: (context, history, _) {
                      final items =
                          history.where((a) => a.hasImage).take(10).toList();
                      if (items.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpace.lg,
                                AppSpace.sm, AppSpace.lg, AppSpace.md),
                            child: Text('Continue reading',
                                style:
                                    AppText.headline.copyWith(color: c.text)),
                          ),
                          SizedBox(
                            height: 232,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.lg),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: AppSpace.lg),
                              itemBuilder: (_, i) => RailCard(article: items[i]),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Horizontal "Trending now" rail — compact cards with signals.
                if (rail.isNotEmpty) ...[
                  _railHeader(context, 'Trending now'),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 198,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                        itemCount: rail.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpace.lg),
                        itemBuilder: (_, i) =>
                            CompactCard(article: rail[i], width: 220),
                      ),
                    ),
                  ),
                ],

                // Horizontal "Shorts" rail — 9:16 reels cards.
                if (shorts.isNotEmpty) ...[
                  _railHeader(context, 'Shorts'),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 278,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                        itemCount: shorts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpace.md),
                        itemBuilder: (_, i) =>
                            VerticalCard(article: shorts[i], width: 152),
                      ),
                    ),
                  ),
                ],

                // Bento mosaic — "Top stories" 2-up grid block.
                if (bento.length >= 2) ...[
                  _railHeader(context, 'Top stories'),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
                      child: BentoMosaic(articles: bento),
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

                // Main feed — frequent magazine / overlay features interleaved
                // with rows so all card styles show as you scroll.
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
                    return _feedCard(i, rest[i]);
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

/// Section header for a horizontal rail.
Widget _railHeader(BuildContext context, String title) => SliverToBoxAdapter(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
        child: Text(title,
            style: AppText.headline.copyWith(color: context.colors.text)),
      ),
    );

/// Cycles the "Latest" feed through every full-width variant so each card style
/// surfaces as you scroll. Falls back to a text variant when an article has no
/// image (so image-led variants never render an empty box).
Widget _feedCard(int i, Article a) {
  // Real in-article video (flagged at ingest) always renders as the video
  // card — the variant is driven by content, never by position.
  if (a.hasPlayableVideo && a.hasImage) return VideoCard(article: a);
  Widget overlay() => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: OverlayCard(article: a),
      );
  switch (i % 7) {
    case 0:
      return a.hasImage ? WideCard(article: a) : FeaturedCard(article: a);
    case 1:
      return a.hasImage ? DefaultCard(article: a) : ListCard(article: a);
    case 2:
      return ListCard(article: a);
    case 3:
      return a.hasImage ? overlay() : ArticleCard(article: a);
    case 4:
      return a.hasImage ? MagazineCard(article: a) : ListCard(article: a);
    case 5:
      return FeaturedCard(article: a);
    default:
      return ArticleCard(article: a);
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
