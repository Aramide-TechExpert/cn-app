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
import '../feed/widgets/card_extras.dart';
import '../feed/widgets/signal_badges.dart';
import '../shell/app_drawer.dart';

/// Clusters — THE core surface of the project. Everything on this page is a
/// clustering product, nothing else:
///   Full Coverage    — the same story from many sources
///   Developing Now   — the clusters that moved in the last hours
///   Trending         — ranked by volume × source spread
///   Connected        — related developments forming one narrative
///   By Category      — coverage rails per news desk
///   Coverage Engine  — which sources power the clusters
class ClustersPage extends ConsumerStatefulWidget {
  const ClustersPage({super.key});

  @override
  ConsumerState<ClustersPage> createState() => _ClustersPageState();
}

/// Layout of the Full Coverage section — same idea as Home's view switcher.
enum _ClusterView { mixed, grid, list }

class _ClustersPageState extends ConsumerState<ClustersPage> {
  _ClusterView _view = _ClusterView.mixed;
  String? _since; // '1h' | '6h' | '24h' | null = any time

  static IconData _viewIcon(_ClusterView v) => switch (v) {
        _ClusterView.mixed => Icons.dashboard_outlined,
        _ClusterView.grid => Icons.grid_view,
        _ClusterView.list => Icons.view_headline,
      };

  PopupMenuItem<_ClusterView> _viewItem(
      NewsSignalColors c, _ClusterView v, String label) {
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

  PopupMenuItem<String> _timeItem(NewsSignalColors c, String value, String label) {
    final sel = (_since ?? '') == value;
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

  /// Client-side time window on last_updated (clusters are one small list —
  /// no need for a server param like the feed's ?since=).
  List<StoryCluster> _applySince(List<StoryCluster> list) {
    final hours = switch (_since) {
      '1h' => 1,
      '6h' => 6,
      '24h' => 24,
      _ => null,
    };
    if (hours == null) return list;
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(Duration(hours: hours))
        .toIso8601String();
    return list.where((c) => c.lastUpdated.compareTo(cutoff) >= 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final clusters = ref.watch(clustersProvider);

    return Scaffold(
      backgroundColor: c.bg,
      drawer: const AppDrawer(),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.invalidate(clustersProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Compact pinned+floating bar — same header behavior and top
            // rhythm as Home / News Feed (no oversized collapsing title).
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
                  Text('Clusters', style: AppText.title.copyWith(color: c.text)),
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'Time period',
                  icon: Icon(Icons.history,
                      color: _since != null ? c.brand : c.text),
                  onSelected: (v) =>
                      setState(() => _since = v.isEmpty ? null : v),
                  itemBuilder: (_) => [
                    _timeItem(c, '', 'Any time'),
                    _timeItem(c, '1h', 'Past hour'),
                    _timeItem(c, '6h', 'Past 6 hours'),
                    _timeItem(c, '24h', 'Past 24 hours'),
                  ],
                ),
                PopupMenuButton<_ClusterView>(
                  tooltip: 'View',
                  icon: Icon(_viewIcon(_view), color: c.text),
                  onSelected: (v) => setState(() => _view = v),
                  itemBuilder: (_) => [
                    _viewItem(c, _ClusterView.mixed, 'Mixed'),
                    _viewItem(c, _ClusterView.grid, 'Grid'),
                    _viewItem(c, _ClusterView.list, 'List'),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.search, color: c.text),
                  onPressed: () => context.push('/search'),
                ),
                const SizedBox(width: AppSpace.xs),
              ],
            ),
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
                final filtered = _applySince(list);
                if (filtered.isEmpty) {
                  return const SliverToBoxAdapter(
                      child: _InlineNote(
                          'No clusters updated in this time window — try a wider period.'));
                }
                return SliverList.list(
                    children: _buildSections(context, filtered));
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x2)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context, List<StoryCluster> list) {
    List<StoryCluster> byKind(String k) {
      final xs = list.where((c) => c.kind == k).toList()
        ..sort((a, b) => b.sourceCount.compareTo(a.sourceCount) != 0
            ? b.sourceCount.compareTo(a.sourceCount)
            : b.lastUpdated.compareTo(a.lastUpdated));
      return xs;
    }

    final story = byKind('story');
    final trending = byKind('trending')
      ..sort((a, b) =>
          b.articleIds.length.compareTo(a.articleIds.length)); // trend = volume
    final related = byKind('related');

    // Trending is a RANKING lens that intentionally overlaps the story lens,
    // so any surface mixing lenses must de-dup by title — story version wins.
    List<StoryCluster> dedupByTitle(Iterable<StoryCluster> xs) {
      final seen = <String>{};
      return [
        for (final c in xs)
          if (seen.add(c.title.trim().toLowerCase())) c,
      ];
    }

    // One de-duped view of all lenses for the aggregate surfaces, so a story
    // that is also trending isn't counted or rendered twice. Story-first, so
    // the Full-coverage version wins over its trending duplicate.
    final unique = dedupByTitle([...story, ...related, ...trending]);

    // Developing now — whatever moved most recently, across all lenses.
    final cutoff =
        DateTime.now().toUtc().subtract(const Duration(hours: 4)).toIso8601String();
    final developing = unique
        .where((c) => c.lastUpdated.compareTo(cutoff) >= 0)
        .toList()
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

    // Coverage by category — every category with ≥ 2 clusters gets a rail.
    final byCategory = <String, List<StoryCluster>>{};
    for (final cl in unique) {
      for (final cat in cl.categories) {
        (byCategory[cat] ??= []).add(cl);
      }
    }
    final categoryRails = byCategory.entries
        .where((e) => e.value.length >= 2)
        .toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Coverage engine — which sources appear across the most clusters.
    final sourceCounts = <String, int>{};
    for (final cl in unique) {
      for (final s in cl.sources.toSet()) {
        sourceCounts[s] = (sourceCounts[s] ?? 0) + 1;
      }
    }
    final topSources = sourceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final storiesLinked =
        unique.fold<int>(0, (sum, cl) => sum + cl.articleIds.length);

    // ── Full coverage layouts, driven by the header view switcher.
    //   mixed — hero → 2-up grid duo → cycle(left-thumb, standard, right-thumb)
    //   grid  — 2-up grid duos all the way down
    //   list  — dense thumb rows, alternating thumbnail side
    final fullCoverage = <Widget>[];
    switch (_view) {
      case _ClusterView.list:
        for (var i = 0; i < story.length; i++) {
          fullCoverage.add(
              _CompactClusterCard(cluster: story[i], thumbLeft: i.isEven));
          fullCoverage.add(i + 1 < story.length
              ? _hairline(context)
              : const BlockDivider());
        }
      case _ClusterView.grid:
        for (var i = 0; i < story.length; i += 2) {
          fullCoverage.add(_GridDuo(
              a: story[i], b: i + 1 < story.length ? story[i + 1] : null));
        }
        fullCoverage.add(const BlockDivider());
      case _ClusterView.mixed:
        if (story.isNotEmpty) {
          fullCoverage.add(story[0].image != null
              ? _HeroClusterCard(cluster: story[0])
              : _ClusterCard(cluster: story[0]));
          var i = 1;
          if (i + 1 < story.length) {
            // Grid duo directly after the big header card.
            fullCoverage.add(_GridDuo(a: story[i], b: story[i + 1]));
            i += 2;
            fullCoverage.add(const BlockDivider());
          } else {
            fullCoverage.add(const BlockDivider());
            if (i < story.length) {
              fullCoverage
                  .add(_CompactClusterCard(cluster: story[i], thumbLeft: true));
              fullCoverage.add(const BlockDivider());
              i += 1;
            }
          }
          // Remaining clusters cycle through the full-width variants.
          var slot = 0;
          while (i < story.length) {
            final cl = story[i];
            final last = i + 1 >= story.length;
            switch (slot % 3) {
              case 0:
                fullCoverage
                    .add(_CompactClusterCard(cluster: cl, thumbLeft: true));
                fullCoverage
                    .add(last ? const BlockDivider() : _hairline(context));
              case 1:
                fullCoverage.add(_ClusterCard(cluster: cl));
                fullCoverage.add(cl.image != null || last
                    ? const BlockDivider()
                    : _hairline(context));
              default:
                fullCoverage.add(_CompactClusterCard(cluster: cl));
                fullCoverage
                    .add(last ? const BlockDivider() : _hairline(context));
            }
            slot++;
            i++;
          }
        }
    }

    return <Widget>[
      // ── Thin stats strip: the clustering engine's live numbers.
      _ClusterStatsStrip(
        fullCoverage: story.length,
        trending: trending.length,
        connected: related.length,
        stories: storiesLinked,
        sources: sourceCounts.length,
      ),

      ...fullCoverage,

      // ── Developing now: what moved in the last hours.
      if (developing.isNotEmpty) ...[
        const _SectionHeader('Developing now'),
        for (var i = 0; i < developing.length && i < 5; i++) ...[
          _DevelopingRow(cluster: developing[i]),
          if (i < 4 && i + 1 < developing.length) _hairline(context),
        ],
        const BlockDivider(),
      ],

      // ── Trending across sources: ranked rows.
      if (trending.isNotEmpty) ...[
        const _SectionHeader('Trending across sources'),
        for (var i = 0; i < trending.length; i++) ...[
          _TrendingClusterCard(cluster: trending[i], rank: i + 1),
          if (i + 1 < trending.length) _hairline(context),
        ],
        const BlockDivider(),
      ],

      // ── Connected coverage: related developments, one narrative.
      if (related.isNotEmpty) ...[
        const _SectionHeader('Connected coverage'),
        for (var i = 0; i < related.length; i++) ...[
          if (i.isOdd)
            _CompactClusterCard(cluster: related[i], thumbLeft: true)
          else
            _ClusterCard(cluster: related[i]),
          if (i.isEven && related[i].image != null)
            const BlockDivider()
          else if (i + 1 < related.length)
            _hairline(context),
        ],
        if (related.length.isEven || related.last.image == null)
          const BlockDivider(),
      ],

      // ── Coverage by category: a rail per news desk.
      for (final entry in categoryRails) ...[
        _SectionHeader(
            '${categoryLabel(entry.key)} · ${entry.value.length} clusters'),
        _ClusterRail(clusters: entry.value),
        const BlockDivider(),
      ],

      // ── Coverage engine: the sources powering the clusters.
      if (topSources.isNotEmpty) ...[
        const _SectionHeader('Powering the coverage'),
        for (var i = 0; i < topSources.length && i < 8; i++) ...[
          _SourceLeaderRow(
            source: topSources[i].key,
            count: topSources[i].value,
            max: topSources.first.value,
          ),
          if (i < 7 && i + 1 < topSources.length) _hairline(context),
        ],
      ],
    ];
  }
}

Widget _hairline(BuildContext context) =>
    Divider(height: 1, thickness: 1, color: context.colors.border);

const _bodyPad =
    EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg);

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
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

/// Thin text stats strip — same style as the Home header strip.
class _ClusterStatsStrip extends StatelessWidget {
  const _ClusterStatsStrip({
    required this.fullCoverage,
    required this.trending,
    required this.connected,
    required this.stories,
    required this.sources,
  });
  final int fullCoverage;
  final int trending;
  final int connected;
  final int stories;
  final int sources;

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
      stat(fullCoverage, 'Full coverage', c.brand),
      stat(trending, 'Trending', c.accent),
      stat(connected, 'Connected', c.text),
      stat(stories, 'Stories linked', c.textSecondary),
      stat(sources, 'Sources', c.textSecondary),
    ];
    return SizedBox(
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
    );
  }
}

/// Overlapping stack of source favicons — each logo sits on the previous one
/// with a thin background ring so the overlap reads cleanly.
class _FaviconStack extends StatelessWidget {
  const _FaviconStack({
    required this.sources,
    this.size = 16,
    this.max = 4,
    this.light = false,
  });
  final List<String> sources;
  final double size;
  final int max;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = sources.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final step = size * 0.62;
    final ring = light ? Colors.white : c.bg;
    return SizedBox(
      width: size + step * (shown.length - 1) + 3,
      height: size + 3,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: i * step,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: ring,
                borderRadius: BorderRadius.circular(4.5),
              ),
              child: SourceFavicon(url: null, source: shown[i], size: size),
            ),
          ),
      ]),
    );
  }
}

/// Shared source line: names (+N more) on the left, the overlapping favicon
/// stack pinned to the right, optional time between them.
class _SourceLogoLine extends StatelessWidget {
  const _SourceLogoLine({
    required this.sources,
    this.light = false,
    this.trailing,
  });
  final List<String> sources;
  final bool light;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = sources.take(4).toList();
    final extra = sources.length - shown.length;
    final textColor = light
        ? Colors.white.withValues(alpha: 0.85)
        : c.textSecondary;
    return Row(children: [
      Expanded(
        child: Text(
          extra > 0 ? '${shown.join(", ")} +$extra more' : shown.join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption.copyWith(color: textColor),
        ),
      ),
      if (trailing != null) ...[
        Text(trailing!,
            style: AppText.caption.copyWith(
                color: light
                    ? Colors.white.withValues(alpha: 0.7)
                    : c.textFaint)),
        const SizedBox(width: AppSpace.sm),
      ],
      _FaviconStack(sources: sources, light: light),
    ]);
  }
}

/// STANDARD — full-width edge-to-edge card (like the Home/Feed image cards):
/// full-bleed 16:9 image with coverage ribbon, then the padded text block.
class _ClusterCard extends StatelessWidget {
  const _ClusterCard({required this.cluster});
  final StoryCluster cluster;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tags = cluster.tags.take(3).toList();
    final category =
        cluster.categories.isNotEmpty ? cluster.categories.first : null;

    return InkWell(
      onTap: () => context.push('/cluster/${cluster.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cluster.image != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                CachedNetworkImage(
                  imageUrl: cluster.image!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: c.bgInset),
                  errorWidget: (_, __, ___) => Container(color: c.bgInset),
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
            ),
          Padding(
            padding: _bodyPad,
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
                if (cluster.sources.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  _SourceLogoLine(sources: cluster.sources),
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
    );
  }
}

/// "N sources" ribbon — dark (on image) or brand-tinted (on card body).
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

/// HERO — the most-covered story: full-bleed edge-to-edge image, title +
/// summary overlaid, "TOP COVERAGE" ribbon and the logo line at the bottom.
class _HeroClusterCard extends StatelessWidget {
  const _HeroClusterCard({required this.cluster});
  final StoryCluster cluster;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
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
            left: AppSpace.lg,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                if (cluster.sources.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  _SourceLogoLine(
                      sources: cluster.sources,
                      light: true,
                      trailing: timeAgo(cluster.lastUpdated)),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// COMPACT — dense edge-to-edge row (feed-style). Thumbnail sits right by
/// default; [thumbLeft] flips it for the left-thumbnail variant.
class _CompactClusterCard extends StatelessWidget {
  const _CompactClusterCard({required this.cluster, this.thumbLeft = false});
  final StoryCluster cluster;
  final bool thumbLeft;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final thumb = cluster.image == null
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 92,
              height: 92,
              child: CachedNetworkImage(
                imageUrl: cluster.image!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: c.bgInset),
                errorWidget: (_, __, ___) => Container(color: c.bgInset),
              ),
            ),
          );
    return InkWell(
      onTap: () => context.push('/cluster/${cluster.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumb != null && thumbLeft) ...[
              thumb,
              const SizedBox(width: AppSpace.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _CoverageRibbon(count: cluster.sourceCount, dark: false),
                    const SizedBox(width: AppSpace.sm),
                    Text(timeAgo(cluster.lastUpdated),
                        style: AppText.caption.copyWith(color: c.textFaint)),
                  ]),
                  const SizedBox(height: AppSpace.sm),
                  Text(cluster.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong
                          .copyWith(color: c.text, height: 1.3)),
                  if (cluster.sources.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _SourceLogoLine(sources: cluster.sources),
                  ],
                ],
              ),
            ),
            if (thumb != null && !thumbLeft) ...[
              const SizedBox(width: AppSpace.md),
              thumb,
            ],
          ],
        ),
      ),
    );
  }
}

/// GRID DUO — two half-width grid cards side by side, padded like the feed's
/// grid view. [b] may be null for an odd trailing cluster.
class _GridDuo extends StatelessWidget {
  const _GridDuo({required this.a, this.b});
  final StoryCluster a;
  final StoryCluster? b;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _GridClusterCard(cluster: a)),
          const SizedBox(width: AppSpace.lg),
          Expanded(
              child: b != null
                  ? _GridClusterCard(cluster: b!)
                  : const SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// Half-width grid card: image, title, source count + favicon stack right.
class _GridClusterCard extends StatelessWidget {
  const _GridClusterCard({required this.cluster});
  final StoryCluster cluster;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => context.push('/cluster/${cluster.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: cluster.image != null
                  ? CachedNetworkImage(
                      imageUrl: cluster.image!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: c.bgInset),
                      errorWidget: (_, __, ___) => Container(color: c.bgInset),
                    )
                  : Container(
                      color: c.bgInset,
                      alignment: Alignment.center,
                      child: Icon(Icons.account_tree,
                          color: c.textFaint, size: 28),
                    ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(cluster.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.callout
                  .copyWith(color: c.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text('${cluster.sourceCount} sources',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: c.textSecondary)),
            ),
            _FaviconStack(sources: cluster.sources, size: 14, max: 3),
          ]),
        ],
      ),
    );
  }
}

/// TRENDING — ranked edge-to-edge row: big rank numeral, volume + logo line.
class _TrendingClusterCard extends StatelessWidget {
  const _TrendingClusterCard({required this.cluster, required this.rank});
  final StoryCluster cluster;
  final int rank;

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
                            color: c.accent, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(timeAgo(cluster.lastUpdated),
                        style: AppText.caption.copyWith(color: c.textFaint)),
                  ]),
                  const SizedBox(height: 6),
                  Text(cluster.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong
                          .copyWith(color: c.text, height: 1.3)),
                  if (cluster.sources.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _SourceLogoLine(sources: cluster.sources),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DEVELOPING — pulse row for clusters that updated in the last hours.
class _DevelopingRow extends StatelessWidget {
  const _DevelopingRow({required this.cluster});
  final StoryCluster cluster;

  static String _lensLabel(String kind) => switch (kind) {
        'trending' => 'Trending',
        'related' => 'Connected',
        _ => 'Full coverage',
      };

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
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.breaking,
                  shape: BoxShape.circle,
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
                  Text(
                      '${_lensLabel(cluster.kind)} · ${cluster.sourceCount} sources · updated ${timeAgo(cluster.lastUpdated)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption
                          .copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            if (cluster.sources.isNotEmpty) ...[
              const SizedBox(width: AppSpace.md),
              _FaviconStack(sources: cluster.sources, size: 15, max: 3),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal rail of mini cluster cards for a category desk.
class _ClusterRail extends StatelessWidget {
  const _ClusterRail({required this.clusters});
  final List<StoryCluster> clusters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
        itemCount: clusters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
        itemBuilder: (_, i) => _ClusterRailCard(cluster: clusters[i]),
      ),
    );
  }
}

class _ClusterRailCard extends StatelessWidget {
  const _ClusterRailCard({required this.cluster});
  final StoryCluster cluster;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => context.push('/cluster/${cluster.id}'),
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 10,
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
                            color: c.textFaint, size: 28),
                      ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(cluster.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.callout
                    .copyWith(color: c.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text('${cluster.sourceCount} sources',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppText.caption.copyWith(color: c.textSecondary)),
              ),
              _FaviconStack(sources: cluster.sources, size: 13, max: 3),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Source leaderboard row — logo, name, coverage bar, cluster count.
class _SourceLeaderRow extends StatelessWidget {
  const _SourceLeaderRow(
      {required this.source, required this.count, required this.max});
  final String source;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fraction = max > 0 ? count / max : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.md),
      child: Row(children: [
        SourceFavicon(url: null, source: source, size: 20),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(color: c.text)),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 3,
                  backgroundColor: c.bgInset,
                  valueColor: AlwaysStoppedAnimation(c.brand),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Text('$count ${count == 1 ? "cluster" : "clusters"}',
            style: AppText.caption.copyWith(color: c.textSecondary)),
      ]),
    );
  }
}
