import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/discover_controller.dart';
import '../../data/source_signals.dart';
import '../../models/cluster.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../discover/markets_weather_section.dart';
import '../feed/widgets/rail_card.dart';
import '../feed/widgets/signal_badges.dart';
import '../shell/app_drawer.dart';

/// Clusters — multi-source "full coverage" stories, plus trending topics, topic
/// rails and market/weather widgets. (Replaces the old Watch tab.)
class ClustersPage extends ConsumerWidget {
  const ClustersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final clusters = ref.watch(clustersProvider);
    final trending = ref.watch(trendingProvider);
    final topTopics =
        trending.valueOrNull?.take(3).toList() ?? const <TrendingTopic>[];

    return Scaffold(
      backgroundColor: c.bg,
      drawer: const AppDrawer(),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(clustersProvider);
          ref.invalidate(trendingProvider);
          ref.invalidate(widgetsDataProvider);
        },
        child: CustomScrollView(
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
              title:
                  Text('Clusters', style: AppText.title.copyWith(color: c.text)),
            ),

            // Intro — explains what a cluster is (the core value).
            SliverToBoxAdapter(
              child: clusters.maybeWhen(
                data: (list) => _ClustersIntro(count: list.length),
                orElse: () => const SizedBox.shrink(),
              ),
            ),

            // Three clustering lenses, each its own section with its own card
            // treatment: Full Coverage (same story, many sources) → Trending
            // (highest-volume topics, ranked) → Connected (related
            // developments forming one narrative).
            clusters.when(
              loading: () => const SliverToBoxAdapter(child: _InlineLoader()),
              error: (_, __) => const SliverToBoxAdapter(
                  child: _InlineNote("Couldn't load clusters.")),
              data: (list) {
                if (list.isEmpty) {
                  return const SliverToBoxAdapter(
                      child: _InlineNote(
                          'No multi-source stories are clustered right now.'));
                }
                List<StoryCluster> byKind(String k) {
                  final xs = list.where((c) => c.kind == k).toList()
                    ..sort((a, b) =>
                        b.sourceCount.compareTo(a.sourceCount) != 0
                            ? b.sourceCount.compareTo(a.sourceCount)
                            : b.lastUpdated.compareTo(a.lastUpdated));
                  return xs;
                }

                final story = byKind('story');
                final trending = byKind('trending')
                  ..sort((a, b) => b.articleIds.length
                      .compareTo(a.articleIds.length)); // trend = volume
                final related = byKind('related');

                final children = <Widget>[
                  // ── Full coverage: hero → standard → compact rhythm.
                  for (var i = 0; i < story.length; i++)
                    if (i == 0 && story[i].image != null)
                      _HeroClusterCard(cluster: story[i])
                    else if (i > 0 && i % 3 == 0)
                      _CompactClusterCard(cluster: story[i])
                    else
                      _ClusterCard(cluster: story[i]),

                  // ── Trending across sources: ranked full-width rows.
                  if (trending.isNotEmpty) ...[
                    const _SectionHeader('Trending across sources'),
                    for (var i = 0; i < trending.length; i++)
                      _TrendingClusterCard(cluster: trending[i], rank: i + 1),
                  ],

                  // ── Connected coverage: standard/compact alternation.
                  if (related.isNotEmpty) ...[
                    const _SectionHeader('Connected coverage'),
                    for (var i = 0; i < related.length; i++)
                      if (i.isOdd)
                        _CompactClusterCard(cluster: related[i])
                      else
                        _ClusterCard(cluster: related[i]),
                  ],
                ];
                return SliverList.list(children: children);
              },
            ),

            // Trending topics (secondary).
            const SliverToBoxAdapter(child: _SectionHeader('Trending')),
            SliverToBoxAdapter(
              child: trending.when(
                loading: () => const _InlineLoader(),
                error: (_, __) => const _InlineNote('Trending unavailable.'),
                data: (topics) => topics.isEmpty
                    ? const _InlineNote('Nothing trending yet.')
                    : SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.lg),
                          itemCount: topics.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppSpace.sm),
                          itemBuilder: (_, i) => _TopicChip(topic: topics[i]),
                        ),
                      ),
              ),
            ),

            // Topic rails.
            ...topTopics.map(
              (t) => SliverToBoxAdapter(child: _TopicSection(topic: t)),
            ),

            // Markets + weather.
            const SliverToBoxAdapter(child: MarketsWeatherSection()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x2)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
      child: Text(label,
          style: AppText.headline.copyWith(color: context.colors.text)),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
}

class _InlineNote extends StatelessWidget {
  const _InlineNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Text(text,
          style: AppText.body.copyWith(color: context.colors.textSecondary)),
    );
  }
}

class _TopicSection extends ConsumerWidget {
  const _TopicSection({required this.topic});
  final TrendingTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final articles = ref.watch(topicFeedProvider(topic.slug)).valueOrNull;
    if (articles == null) return const SizedBox.shrink();
    final items = articles.where((a) => a.hasImage).take(8).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final name = topic.topic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.lg, AppSpace.sm, AppSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Text(name,
                    style: AppText.headline.copyWith(color: c.text)),
              ),
              TextButton(
                onPressed: () => context.push(
                    '/topic/${topic.slug}?name=${Uri.encodeComponent(name)}'),
                child: Text('See all',
                    style: AppText.callout.copyWith(color: c.brand)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.lg),
            itemBuilder: (_, i) => RailCard(article: items[i]),
          ),
        ),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.topic});
  final TrendingTopic topic;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ActionChip(
      label: Text(topic.topic),
      labelStyle: AppText.callout.copyWith(color: c.text),
      backgroundColor: c.bgInset,
      side: BorderSide(color: c.border),
      shape: const RoundedRectangleBorder(),
      onPressed: () => context.push(
          '/topic/${topic.slug}?name=${Uri.encodeComponent(topic.topic)}'),
    );
  }
}

/// One-line intro under the app bar explaining what the page is.
class _ClustersIntro extends StatelessWidget {
  const _ClustersIntro({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, size: 16, color: c.brand),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              count > 0
                  ? '$count stories, each grouped across every source covering it'
                  : 'Stories grouped across every source covering them',
              style: AppText.caption.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({required this.cluster});
  final StoryCluster cluster;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tags = cluster.tags.take(3).toList();
    final shown = cluster.sources.take(3).toList();
    final extra = cluster.sources.length - shown.length;
    final category =
        cluster.categories.isNotEmpty ? cluster.categories.first : null;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Material(
        color: c.bgElevated,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/cluster/${cluster.id}'),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero image + a "FULL COVERAGE · N sources" ribbon.
                if (cluster.image != null)
                  Stack(children: [
                    AspectRatio(
                      aspectRatio: 2.3,
                      child: CachedNetworkImage(
                        imageUrl: cluster.image!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: c.bgInset),
                        errorWidget: (_, __, ___) => Container(color: c.bgInset),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpace.md,
                      bottom: AppSpace.md,
                      child: _CoverageRibbon(count: cluster.sourceCount),
                    ),
                  ]),
                Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (category != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.bgInset,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(categoryLabel(category).toUpperCase(),
                                style: AppText.micro.copyWith(
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3)),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        if (cluster.image == null) ...[
                          _CoverageRibbon(count: cluster.sourceCount, dark: false),
                          const SizedBox(width: AppSpace.sm),
                        ],
                        Text(timeAgo(cluster.lastUpdated),
                            style: AppText.caption.copyWith(color: c.textFaint)),
                      ]),
                      const SizedBox(height: AppSpace.sm),
                      Text(cluster.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.headline
                              .copyWith(color: c.text, height: 1.25)),
                      if (cluster.summary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(cluster.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body
                                .copyWith(color: c.textSecondary, height: 1.4)),
                      ],
                      // The coverage line — the actual sources on the story.
                      if (shown.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.md),
                        Row(children: [
                          for (final s in shown)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: SourceFavicon(
                                  url: null, source: s, size: 16),
                            ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              extra > 0
                                  ? '${shown.join(", ")} +$extra more'
                                  : shown.join(", "),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption
                                  .copyWith(color: c.textSecondary),
                            ),
                          ),
                        ]),
                      ],
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.md),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.bgInset,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(t,
                                    style: AppText.micro
                                        .copyWith(color: c.textSecondary)),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "FULL COVERAGE · N sources" ribbon — dark (on image) or brand (on card).
class _CoverageRibbon extends StatelessWidget {
  const _CoverageRibbon({required this.count, this.dark = true});
  final int count;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = dark ? Colors.white : c.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? Colors.black.withValues(alpha: 0.55) : c.brandSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_tree, size: 12, color: fg),
        const SizedBox(width: 5),
        Text('$count ${count == 1 ? "source" : "sources"}',
            style: AppText.micro.copyWith(color: fg, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// HERO — the most-covered story: full-bleed image, title + summary overlaid,
/// "TOP COVERAGE" ribbon and the source line pinned to the bottom.
class _HeroClusterCard extends StatelessWidget {
  const _HeroClusterCard({required this.cluster});
  final StoryCluster cluster;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = cluster.sources.take(3).toList();
    final extra = cluster.sources.length - shown.length;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/cluster/${cluster.id}'),
          child: AspectRatio(
            aspectRatio: 0.95,
            child: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(
                imageUrl: cluster.image!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: c.bgInset),
                errorWidget: (_, __, ___) => Container(color: c.bgInset),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black26, Colors.transparent, Colors.black87],
                    stops: [0.0, 0.35, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: AppSpace.md,
                left: AppSpace.md,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.brand,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.workspace_premium,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('TOP COVERAGE · ${cluster.sourceCount} SOURCES',
                        style: AppText.micro.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4)),
                  ]),
                ),
              ),
              Positioned(
                left: AppSpace.lg,
                right: AppSpace.lg,
                bottom: AppSpace.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cluster.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title.copyWith(
                            color: Colors.white, height: 1.2, fontSize: 21)),
                    if (cluster.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(cluster.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.35)),
                    ],
                    if (shown.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.md),
                      Row(children: [
                        for (final s in shown)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child:
                                SourceFavicon(url: null, source: s, size: 16),
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            extra > 0
                                ? '${shown.join(", ")} +$extra more'
                                : shown.join(", "),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ),
                        Text(timeAgo(cluster.lastUpdated),
                            style: AppText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.7))),
                      ]),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// COMPACT — dense horizontal row: thumbnail right, sources ribbon + title left.
class _CompactClusterCard extends StatelessWidget {
  const _CompactClusterCard({required this.cluster});
  final StoryCluster cluster;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Material(
        color: c.bgElevated,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/cluster/${cluster.id}'),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _CoverageRibbon(
                              count: cluster.sourceCount, dark: false),
                          const SizedBox(width: AppSpace.sm),
                          Text(timeAgo(cluster.lastUpdated),
                              style: AppText.caption
                                  .copyWith(color: c.textFaint)),
                        ]),
                        const SizedBox(height: AppSpace.sm),
                        Text(cluster.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyStrong
                                .copyWith(color: c.text, height: 1.3)),
                        if (cluster.sources.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(cluster.sources.take(4).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption
                                  .copyWith(color: c.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  if (cluster.image != null) ...[
                    const SizedBox(width: AppSpace.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 92,
                        height: 92,
                        child: CachedNetworkImage(
                          imageUrl: cluster.image!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: c.bgInset),
                          errorWidget: (_, __, ___) =>
                              Container(color: c.bgInset),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// TRENDING — ranked full-width row: big rank number, title, volume + sources.
class _TrendingClusterCard extends StatelessWidget {
  const _TrendingClusterCard({required this.cluster, required this.rank});
  final StoryCluster cluster;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Material(
        color: c.bgElevated,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/cluster/${cluster.id}'),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rank numeral — the "chart position" of the trend.
                  SizedBox(
                    width: 34,
                    child: Text('$rank',
                        style: AppText.display.copyWith(
                            color: rank == 1 ? c.accent : c.textFaint,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.0)),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.trending_up, size: 13, color: c.accent),
                          const SizedBox(width: 4),
                          Text(
                              '${cluster.articleIds.length} stories · ${cluster.sourceCount} sources',
                              style: AppText.caption.copyWith(
                                  color: c.accent,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(timeAgo(cluster.lastUpdated),
                              style: AppText.caption
                                  .copyWith(color: c.textFaint)),
                        ]),
                        const SizedBox(height: 6),
                        Text(cluster.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyStrong
                                .copyWith(color: c.text, height: 1.3)),
                        if (cluster.sources.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            for (final s in cluster.sources.take(4))
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: SourceFavicon(
                                    url: null, source: s, size: 14),
                              ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(cluster.sources.take(4).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.caption
                                      .copyWith(color: c.textSecondary)),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
