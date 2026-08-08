import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/discover_controller.dart'
    show statsProvider, clustersProvider, widgetsDataProvider;
import '../../data/dismissed_controller.dart';
import '../../data/feed_controller.dart';
import '../../data/news_feed_controller.dart'
    show videoPoolProvider, sourcesProvider;
import '../../data/personalization_controller.dart';
import '../../data/settings_controller.dart';
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../utils/interleave.dart' show throttleVideoCards;
import '../../theme/tokens.dart';
import '../../utils/link_out.dart';
import '../discover/discover_page.dart' show FeedView;
import '../shell/app_drawer.dart';
import 'widgets/article_card.dart';
import 'widgets/card_extras.dart';
import 'widgets/card_variants.dart';
import 'widgets/magazine_card.dart';
import '../../utils/remote_settings.dart';
import '../shell/announcement_banner.dart';
import 'widgets/overlay_card.dart';
import 'widgets/rail_card.dart';
import 'widgets/spotlight_carousel.dart';
import 'widgets/stats_strip.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();
  // Layout of the "Latest" section — served CMS default, user-overridable.
  FeedView _view = switch (remote.defaultView) {
    'magazine' => FeedView.magazine,
    'grid' => FeedView.grid,
    'list' => FeedView.list,
    _ => FeedView.mixed,
  };
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Keep the header stats live — refetch on a cadence so they track each
    // ingestion cycle instead of showing the first load's numbers forever.
    _statsTimer =
        Timer.periodic(const Duration(minutes: 2), (_) => _refreshStats());
  }

  /// Refetch the header stat sources (corpus totals, sources, clusters, FX).
  void _refreshStats() {
    if (!mounted) return;
    ref.invalidate(statsProvider);
    ref.invalidate(sourcesProvider);
    ref.invalidate(clustersProvider);
    ref.invalidate(widgetsDataProvider);
  }

  static IconData _viewIcon(FeedView v) => switch (v) {
        FeedView.mixed => Icons.dashboard_outlined,
        FeedView.magazine => Icons.view_agenda_outlined,
        FeedView.grid => Icons.grid_view,
        FeedView.list => Icons.view_headline,
      };

  PopupMenuItem<FeedView> _viewItem(ClustezColors c, FeedView v, String label) {
    final sel = _view == v;
    return PopupMenuItem(
      value: v,
      child: Row(children: [
        Icon(_viewIcon(v), size: 18, color: sel ? c.brand : c.textSecondary),
        const SizedBox(width: AppSpace.md),
        Text(label,
            style: AppText.body.copyWith(
                color: sel ? c.brand : c.text,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );
  }

  PopupMenuItem<String> _timeItem(
      ClustezColors c, String value, String label, String? current) {
    final sel = (current ?? '') == value;
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(sel ? Icons.check : Icons.schedule,
            size: 18, color: sel ? c.brand : c.textSecondary),
        const SizedBox(width: AppSpace.md),
        Text(label,
            style: AppText.body.copyWith(
                color: sel ? c.brand : c.text,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
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
          // Drop "not interested" stories, and keep NASA's obscure
          // astronomy/space-object posts off Home (they read as noise here).
          final items = allItems
              .where((a) => !dismissed.contains(a.id))
              .where((a) => !a.source.toLowerCase().contains('nasa'))
              .toList();
          final withImage = items.where((a) => a.hasImage).toList();
          // CMS spotlight curation: admin-preferred sources fill the hero
          // first; automatic newest fills any remainder.
          final spotPins = remote.spotlightSources.toSet();
          final spotlight = spotPins.isEmpty
              ? withImage.take(5).toList()
              : [
                  ...withImage.where((a) => spotPins.contains(a.source)),
                  ...withImage.where((a) => !spotPins.contains(a.source)),
                ].take(5).toList();
          final rail = withImage.skip(remote.spotlightCount).take(remote.railCount).toList();
          // Shorts rail = the license-safe playable-video pool (DVIDS/NASA),
          // not a filter of the recent feed (which rarely has playable video,
          // so the rail kept vanishing). These all have a real video_url.
          final shorts = (ref.watch(videoPoolProvider).valueOrNull ??
                  const <Article>[])
              .take(remote.shortsCount)
              .toList();
          final used = {
            ...spotlight.map((a) => a.id),
            ...rail.map((a) => a.id),
            // Shorts are NOT excluded: horizontal news-video cards belong on
            // Home too (throttled below) — the 9:16 rail is a different
            // presentation of the clip, not a replacement.
          };
          // Everything else flows into the interleaved feed (magazine / overlay
          // / row) so the varied cards are the bulk of Home, not a grid block.
          final rest = items.where((a) => !used.contains(a.id)).toList();
          // Few video cards, not walls — ~1 per 10 items; the rest of the
          // playable-video articles render as normal image cards.
          final videoOk = throttleVideoCards(rest);

          return RefreshIndicator.adaptive(
            onRefresh: () async {
              _refreshStats();
              await controller.refresh();
            },
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  backgroundColor: c.bg,
                  surfaceTintColor: Colors.transparent,
                  pinned: true,
                  floating: true,
                  leading: Builder(
                    builder: (ctx) => IconButton(
                      icon: Icon(Icons.menu, color: c.text),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  title: Text('Top Stories',
                      style: AppText.title.copyWith(color: c.text)),
                  actions: [
                    // Time period (?since=) — same as the News Feed header.
                    PopupMenuButton<String>(
                      tooltip: 'Time period',
                      icon: Icon(Icons.history,
                          color: controller.since != null ? c.brand : c.text),
                      onSelected: (v) =>
                          controller.setSince(v.isEmpty ? null : v),
                      itemBuilder: (_) => [
                        _timeItem(c, '', 'Any time', controller.since),
                        _timeItem(c, '1h', 'Past hour', controller.since),
                        _timeItem(c, '24h', 'Past 24 hours', controller.since),
                        _timeItem(c, '7d', 'Past week', controller.since),
                      ],
                    ),
                    // View layout for the Latest section.
                    PopupMenuButton<FeedView>(
                      tooltip: 'View',
                      icon: Icon(_viewIcon(_view), color: c.text),
                      onSelected: (v) => setState(() => _view = v),
                      itemBuilder: (_) => [
                        _viewItem(c, FeedView.mixed, 'Mixed'),
                        _viewItem(c, FeedView.magazine, 'Magazine'),
                        _viewItem(c, FeedView.grid, 'Grid'),
                        _viewItem(c, FeedView.list, 'List'),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.search, color: c.text),
                      onPressed: () => context.push('/search'),
                    ),
                    const SizedBox(width: AppSpace.xs),
                  ],
                ),
                // Admin announcement (Clustez Control), when active.
                const SliverToBoxAdapter(child: AnnouncementBanner()),
                // News content analysis — swipeable stat text (ports the web
                // dashboard StatsRow) pinned at the top of Home, with an FX +
                // stocks strip directly below it.
                if (remote.statsStrip) ...[
                  const SliverToBoxAdapter(child: HomeStatsStrip()),
                  const SliverToBoxAdapter(child: HomeMarketsStrip()),
                ],
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
                      height: 268,
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
                  // Thin line between the stacked rails.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpace.md),
                      child: Divider(height: 1, thickness: 1, color: c.border),
                    ),
                  ),
                ],

                // Horizontal "Trending now" rail — compact cards with signals.
                if (rail.isNotEmpty) ...[
                  _railHeader(context, 'Trending now'),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 244,
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
                  // Thin line under Trending, then a little gap before Shorts.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpace.xs),
                      child: Divider(height: 1, thickness: 1, color: c.border),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: AppSpace.md)),
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
                        // Reel cards click through to the SOURCE story page
                        // (not the full-screen reel) — the preview loop is
                        // the in-app experience, the publisher has the full
                        // video.
                        itemBuilder: (_, i) => VerticalCard(
                          article: shorts[i],
                          width: 152,
                          onTap: () => openArticle(shorts[i].sourceUrl,
                              track: shorts[i]),
                        ),
                      ),
                    ),
                  ),
                  // Band: section break after the rails, into the main feed.
                  const SliverToBoxAdapter(child: BlockDivider()),
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

                // Main "Latest" feed — layout follows the view switcher.
                switch (_view) {
                  FeedView.list => SliverList.builder(
                      itemCount: rest.length + 1,
                      itemBuilder: (context, i) => i == rest.length
                          ? _feedLoader(controller.hasMore)
                          : ListCard(article: rest[i]),
                    ),
                  FeedView.magazine => SliverList.builder(
                      itemCount: rest.length + 1,
                      itemBuilder: (context, i) => i == rest.length
                          ? _feedLoader(controller.hasMore)
                          : MagazineCard(article: rest[i]),
                    ),
                  FeedView.grid => SliverPadding(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpace.lg,
                          crossAxisSpacing: AppSpace.lg,
                          childAspectRatio: 0.6,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => CompactCard(
                              article: rest[i], width: double.infinity),
                          childCount: rest.length,
                        ),
                      ),
                    ),
                  FeedView.mixed => SliverList.builder(
                      itemCount: rest.length + 1,
                      itemBuilder: (context, i) {
                        if (i == rest.length) {
                          return _feedLoader(controller.hasMore);
                        }
                        // Grey band ONLY between two stacked big image cards.
                        final next = i + 1 < rest.length ? rest[i + 1] : null;
                        final flushBelow = next != null &&
                            _isBigImageCardAt(i, rest[i],
                                videoOk: videoOk.contains(rest[i].id)) &&
                            _isBigImageCardAt(i + 1, next,
                                videoOk: videoOk.contains(next.id));
                        return _feedCard(i, rest[i],
                            flushBelow: flushBelow,
                            videoOk: videoOk.contains(rest[i].id));
                      },
                    ),
                },
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
Widget _feedLoader(bool hasMore) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
      child: hasMore
          ? const Center(child: CircularProgressIndicator.adaptive())
          : const SizedBox(height: AppSpace.lg),
    );

Widget _feedCard(int i, Article a,
    {bool flushBelow = false, bool videoOk = false}) {
  // Real in-article video renders as the video card only when the throttle
  // allows it (~1 per 10 items) — news sources carry a LOT of video now,
  // and autoplay should be an accent, not the whole feed.
  if (a.hasPlayableVideo && a.hasImage && videoOk) {
    return VideoCard(article: a, flushBelow: flushBelow);
  }
  Widget overlay() => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: OverlayCard(article: a, flushBelow: flushBelow),
      );
  switch (i % 7) {
    case 0:
      return a.hasImage
          ? WideCard(article: a, flushBelow: flushBelow)
          : FeaturedCard(article: a);
    case 1:
      return a.hasImage
          ? DefaultCard(article: a, flushBelow: flushBelow)
          : ListCard(article: a);
    case 2:
      return ListCard(article: a);
    case 3:
      return a.hasImage ? overlay() : ArticleCard(article: a);
    case 4:
      return a.hasImage
          ? MagazineCard(article: a, flushBelow: flushBelow)
          : ListCard(article: a);
    case 5:
      return FeaturedCard(article: a);
    default:
      return ArticleCard(article: a);
  }
}

/// Whether the card at position [i] renders as a big full-bleed image card
/// (used to decide if a band-carrying card above it should drop to a thin line).
bool _isBigImageCardAt(int i, Article a, {bool videoOk = false}) {
  if (a.hasPlayableVideo && a.hasImage && videoOk) return true; // VideoCard
  switch (i % 7) {
    case 0: // Wide
    case 1: // Default
    case 3: // Overlay
    case 4: // Magazine
      return a.hasImage;
    default: // 2/5/6 → List / Featured / Article (compact or text)
      return false;
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
