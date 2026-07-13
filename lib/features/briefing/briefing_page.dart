import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/discover_controller.dart';
import '../../data/feed_controller.dart';
import '../../data/news_feed_controller.dart' show sourcesProvider;
import '../../models/article.dart';
import '../../models/briefing.dart';
import '../../models/cluster.dart';
import '../../models/stats.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../../utils/link_out.dart';
import '../feed/widgets/card_extras.dart';
import '../feed/widgets/signal_badges.dart';
import '../shell/app_drawer.dart';

/// Briefing — the daily command center. Segmented digest of everything the
/// engine produced today:
///   The Brief       — AI daily summary + numbered top stories
///   Ingestion pulse — live corpus numbers (articles, breaking, sources)
///   Latest          — freshest stories straight from ingestion
///   Trending        — ranked topics across the corpus
///   Developing      — breaking / high-impact stories moving right now
///   From the sources— which publishers filed what today
///   Clustering      — the top multi-source story clusters
class BriefingPage extends ConsumerWidget {
  const BriefingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final briefing = ref.watch(briefingProvider);
    final feed = ref.watch(feedControllerProvider).valueOrNull ?? const <Article>[];
    final stats = ref.watch(statsProvider).valueOrNull;
    final trending = ref.watch(trendingProvider).valueOrNull ?? const <TrendingTopic>[];
    final clusters = ref.watch(clustersProvider).valueOrNull ?? const <StoryCluster>[];
    final sources = ref.watch(sourcesProvider).valueOrNull ?? const <String>[];

    return Scaffold(
      backgroundColor: c.bg,
      drawer: const AppDrawer(),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(briefingProvider);
          ref.invalidate(statsProvider);
          ref.invalidate(trendingProvider);
          ref.invalidate(clustersProvider);
          await ref.read(feedControllerProvider.notifier).refresh();
        },
        child: CustomScrollView(
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
              title:
                  Text('Briefing', style: AppText.title.copyWith(color: c.text)),
              actions: [
                IconButton(
                  icon: Icon(Icons.search, color: c.text),
                  onPressed: () => context.push('/search'),
                ),
                const SizedBox(width: AppSpace.xs),
              ],
            ),
            SliverList.list(
              children: _buildSections(
                context, briefing, feed, stats, trending, clusters, sources),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x2)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    AsyncValue<DailyBriefing?> briefing,
    List<Article> feed,
    CorpusStats? stats,
    List<TrendingTopic> trending,
    List<StoryCluster> clusters,
    List<String> sources,
  ) {
    final c = context.colors;
    final b = briefing.valueOrNull;

    // Latest — the freshest articles straight from ingestion.
    final latest = feed.take(6).toList();

    // Developing — breaking or high-impact stories moving right now.
    final developing = feed
        .where((a) => a.isBreaking || a.impact == 'Critical' || a.impact == 'High')
        .take(5)
        .toList();

    // From the sources — who filed what today, busiest desks first.
    final bySource = <String, List<Article>>{};
    for (final a in feed) {
      (bySource[a.source] ??= []).add(a);
    }
    final sourceDigest = bySource.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Clustering — top full-coverage clusters, story lens first.
    final topClusters = [
      ...clusters.where((cl) => cl.kind == 'story'),
      ...clusters.where((cl) => cl.kind != 'story'),
    ].take(4).toList();

    return <Widget>[
      // ── Masthead: date + AI brief.
      Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (b?.date.isNotEmpty ?? false)
                  ? b!.date.toUpperCase()
                  : _todayLabel(),
              style: AppText.micro.copyWith(color: c.brand, letterSpacing: 1.2),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(b?.title ?? 'Your daily briefing',
                style: AppText.display.copyWith(color: c.text)),
            if ((b?.summary ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: c.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THE BRIEF',
                        style: AppText.micro
                            .copyWith(color: c.brand, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text(b!.summary,
                        style:
                            AppText.body.copyWith(color: c.text, height: 1.5)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),

      // ── Ingestion pulse: the engine's live numbers.
      if (stats != null)
        _PulseStrip(
          total: stats.total,
          breaking: stats.breaking,
          highImpact: stats.critical + stats.high,
          sources: sources.length,
          clusters: clusters.length,
        )
      else
        const SizedBox(height: AppSpace.md),

      // ── Top stories (the AI briefing's numbered picks).
      if ((b?.topStories ?? const []).isNotEmpty) ...[
        const _SectionHeader('Top stories'),
        for (var i = 0; i < b!.topStories.length; i++) ...[
          _NumberedStory(story: b.topStories[i]),
          if (i + 1 < b.topStories.length) _hairline(context),
        ],
        const BlockDivider(),
      ],

      // ── Latest: fresh off this ingestion.
      if (latest.isNotEmpty) ...[
        const _SectionHeader('Latest', sub: 'fresh from ingestion'),
        for (var i = 0; i < latest.length; i++) ...[
          _TimelineRow(article: latest[i]),
          if (i + 1 < latest.length) _hairline(context),
        ],
        const BlockDivider(),
      ],

      // ── Trending: ranked topics across the corpus.
      if (trending.isNotEmpty) ...[
        const _SectionHeader('Trending'),
        for (var i = 0; i < trending.length && i < 6; i++) ...[
          _TrendRow(topic: trending[i], rank: i + 1),
          if (i < 5 && i + 1 < trending.length) _hairline(context),
        ],
        if ((b?.trendingTopics ?? const []).isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in b!.trendingTopics)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.bgInset,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(t,
                        style:
                            AppText.caption.copyWith(color: c.textSecondary)),
                  ),
              ],
            ),
          ),
        const BlockDivider(),
      ],

      // ── Developing: breaking / high-impact right now.
      if (developing.isNotEmpty) ...[
        const _SectionHeader('Developing'),
        for (var i = 0; i < developing.length; i++) ...[
          _DevelopingRow(article: developing[i]),
          if (i + 1 < developing.length) _hairline(context),
        ],
        const BlockDivider(),
      ],

      // ── From the sources: who filed what today.
      if (sourceDigest.isNotEmpty) ...[
        const _SectionHeader('From the sources'),
        for (var i = 0; i < sourceDigest.length && i < 8; i++) ...[
          _SourceDigestRow(
            source: sourceDigest[i].key,
            articles: sourceDigest[i].value,
          ),
          if (i < 7 && i + 1 < sourceDigest.length) _hairline(context),
        ],
        const BlockDivider(),
      ],

      // ── Clustering: the top multi-source stories.
      if (topClusters.isNotEmpty) ...[
        const _SectionHeader('Clustering'),
        for (var i = 0; i < topClusters.length; i++) ...[
          _ClusterDigestRow(cluster: topClusters[i]),
          if (i + 1 < topClusters.length) _hairline(context),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
          child: OutlinedButton.icon(
            onPressed: () => context.go('/clusters'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.brand,
              side: BorderSide(color: c.border),
              minimumSize: const Size.fromHeight(44),
            ),
            icon: const Icon(Icons.account_tree_outlined, size: 18),
            label: const Text('All clusters'),
          ),
        ),
      ],

      // ── Market signals (AI briefing tail).
      if ((b?.marketSignals ?? '').isNotEmpty) ...[
        const _SectionHeader('Market signals'),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.lg),
            color: c.bgInset,
            child: Text(b!.marketSignals,
                style: AppText.body
                    .copyWith(color: c.textSecondary, height: 1.5)),
          ),
        ),
      ],
    ];
  }

  static String _todayLabel() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.day}, ${now.year}'.toUpperCase();
  }
}

Widget _hairline(BuildContext context) =>
    Divider(height: 1, thickness: 1, color: context.colors.border);

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.sub});
  final String label;
  final String? sub;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label, style: AppText.headline.copyWith(color: c.text)),
          if (sub != null) ...[
            const SizedBox(width: AppSpace.sm),
            Text(sub!, style: AppText.caption.copyWith(color: c.textFaint)),
          ],
        ],
      ),
    );
  }
}

/// Thin live-numbers strip (same style as Home/Clusters).
class _PulseStrip extends StatelessWidget {
  const _PulseStrip({
    required this.total,
    required this.breaking,
    required this.highImpact,
    required this.sources,
    required this.clusters,
  });
  final int total;
  final int breaking;
  final int highImpact;
  final int sources;
  final int clusters;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget stat(int value, String label, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$value',
                style: AppText.caption.copyWith(
                    color: color, fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(width: 4),
            Text(label,
                style: AppText.caption
                    .copyWith(color: c.textSecondary, fontSize: 13.5)),
          ],
        );
    final items = <Widget>[
      stat(total, 'Stories ingested', c.brand),
      stat(breaking, 'Breaking', c.breaking),
      stat(highImpact, 'High impact', c.accent),
      stat(sources, 'Sources', c.textSecondary),
      stat(clusters, 'Clusters', c.textSecondary),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg),
      child: SizedBox(
        height: 30,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          itemCount: items.length,
          separatorBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: VerticalDivider(width: 1, thickness: 1, color: c.border),
          ),
          itemBuilder: (_, i) => Center(child: items[i]),
        ),
      ),
    );
  }
}

/// Numbered AI-briefing pick — edge-to-edge row.
class _NumberedStory extends StatelessWidget {
  const _NumberedStory({required this.story});
  final BriefingTopStory story;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
            child: Text('${story.number}',
                style:
                    AppText.bodyStrong.copyWith(color: c.brand, fontSize: 13)),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(story.title,
                    style:
                        AppText.bodyStrong.copyWith(color: c.text, height: 1.3)),
                if (story.summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(story.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body
                          .copyWith(color: c.textSecondary, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Latest row — time column, favicon + source, title.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => openArticle(article.sourceUrl, track: article),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 42,
              child: Text(timeAgo(article.publishedAt),
                  style: AppText.caption
                      .copyWith(color: c.brand, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong
                          .copyWith(color: c.text, height: 1.3)),
                  const SizedBox(height: 4),
                  Row(children: [
                    SourceFavicon(
                        url: article.sourceUrl,
                        source: article.source,
                        size: 13),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(article.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption
                              .copyWith(color: c.textSecondary)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trending topic row — rank numeral + topic + story count.
class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.topic, required this.rank});
  final TrendingTopic topic;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => context.push(
          '/topic/${topic.slug}?name=${Uri.encodeComponent(topic.topic)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(children: [
          SizedBox(
            width: 30,
            child: Text('$rank',
                style: AppText.display.copyWith(
                    color: rank == 1 ? c.accent : c.textFaint,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.0)),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(topic.topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong.copyWith(color: c.text)),
          ),
          Icon(Icons.trending_up, size: 13, color: c.accent),
          const SizedBox(width: 4),
          Text('${topic.count} stories',
              style: AppText.caption
                  .copyWith(color: c.accent, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// Developing row — red pulse + impact/breaking label.
class _DevelopingRow extends StatelessWidget {
  const _DevelopingRow({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = article.isBreaking ? 'BREAKING' : article.impact.toUpperCase();
    return InkWell(
      onTap: () => openArticle(article.sourceUrl, track: article),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: c.breaking, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong
                          .copyWith(color: c.text, height: 1.3)),
                  const SizedBox(height: 4),
                  Text(
                      '$label · ${article.source} · ${timeAgo(article.publishedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppText.caption.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            if (article.hasImage) ...[
              const SizedBox(width: AppSpace.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CachedNetworkImage(
                    imageUrl: article.image,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: c.bgInset),
                    errorWidget: (_, __, ___) => Container(color: c.bgInset),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Source digest row — favicon, source + count, its latest headline.
class _SourceDigestRow extends StatelessWidget {
  const _SourceDigestRow({required this.source, required this.articles});
  final String source;
  final List<Article> articles;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final latest = articles.first;
    return InkWell(
      onTap: () => openArticle(latest.sourceUrl, track: latest),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SourceFavicon(url: latest.sourceUrl, source: source, size: 20),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong.copyWith(color: c.text)),
                    ),
                    Text(
                        '${articles.length} ${articles.length == 1 ? "story" : "stories"}',
                        style: AppText.caption
                            .copyWith(color: c.textSecondary)),
                  ]),
                  const SizedBox(height: 3),
                  Text(latest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppText.caption.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cluster digest row — thumb, title, coverage line.
class _ClusterDigestRow extends StatelessWidget {
  const _ClusterDigestRow({required this.cluster});
  final StoryCluster cluster;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => context.push('/cluster/${cluster.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 56,
                child: cluster.image != null
                    ? CachedNetworkImage(
                        imageUrl: cluster.image!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: c.bgInset),
                        errorWidget: (_, __, ___) =>
                            Container(color: c.bgInset),
                      )
                    : Container(
                        color: c.bgInset,
                        alignment: Alignment.center,
                        child: Icon(Icons.account_tree,
                            color: c.textFaint, size: 22),
                      ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cluster.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong
                          .copyWith(color: c.text, height: 1.3)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.account_tree, size: 12, color: c.brand),
                    const SizedBox(width: 4),
                    Text(
                        '${cluster.sourceCount} sources · ${cluster.articleIds.length} stories',
                        style: AppText.caption.copyWith(
                            color: c.brand, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(timeAgo(cluster.lastUpdated),
                        style:
                            AppText.caption.copyWith(color: c.textFaint)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
