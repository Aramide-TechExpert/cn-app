import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../utils/remote_settings.dart';
import '../../data/dismissed_controller.dart';
import '../../data/news_feed_controller.dart';
import '../../data/source_signals.dart';
import '../../utils/interleave.dart' show throttleVideoCards;
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../feed/widgets/card_extras.dart';
import '../feed/widgets/card_variants.dart';
import '../feed/widgets/magazine_card.dart';
import '../feed/widgets/overlay_card.dart';
import '../../models/article.dart';
import '../shell/app_drawer.dart';

/// Feed layout the user can switch between (mirrors the web view options).
enum FeedView { mixed, magazine, grid, list }

/// News Feed — the filterable article stream (category · sort · impact),
/// mirroring the web feed. Full-width square cards.
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _scroll = ScrollController();
  // Feed layout — served CMS default (Features → Card style), user-overridable.
  FeedView _view = switch (remote.defaultView) {
    'magazine' => FeedView.magazine,
    'grid' => FeedView.grid,
    'list' => FeedView.list,
    _ => FeedView.mixed,
  };
  Set<String> _videoOk = const {}; // ids allowed to render as video cards

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
        ref.read(newsFeedControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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

  /// Opens the source picker sheet; applies the chosen source (or clears it).
  Future<void> _openSourcePicker() async {
    final notifier = ref.read(newsFeedControllerProvider.notifier);
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: context.colors.bgElevated,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SourcePickerSheet(current: notifier.filters.source),
    );
    if (picked == null) return; // dismissed → no change
    notifier.setFilters(
        notifier.filters.copyWith(source: picked.isEmpty ? null : picked));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Dynamic card rhythm — gives the feed *visibly* distinct card shapes instead
  /// of a flat column (mirrors the web mosaic/bucketed feed). A bold full-bleed
  /// Overlay hero leads, then a tight 4-card cadence interleaves a full-bleed
  /// Overlay, a panoramic Wide, and a big Magazine between standard Default
  /// cards — so variety is obvious every few cards, not once every 7.
  /// Video → VideoCard; image-less → Featured (with "why it matters") else List.
  Widget _cardFor(int i, Article a, {bool flushBelow = false}) {
    // Play icon ONLY for a real, captured, playable video — never the loose
    // hasVideo detector (which fires on ads / embeds / thumbnail players).
    // Throttled: news sources now carry lots of video, so only the ids in
    // _videoOk (≈1 per 10 items) promote — the rest render as image cards.
    if (a.hasPlayableVideo && a.hasImage && _videoOk.contains(a.id)) {
      return VideoCard(article: a, flushBelow: flushBelow);
    }
    if (!a.hasImage) {
      return (a.whyItMatters ?? '').isNotEmpty
          ? FeaturedCard(article: a)
          : ListCard(article: a);
    }
    if (i == 0) {
      return OverlayCard(
          article: a, height: 300, flushBelow: flushBelow); // bold full-bleed hero
    }
    switch (i % 6) {
      case 0:
        return WideCard(article: a, flushBelow: flushBelow); // panoramic 2:1
      case 2:
        return OverlayCard(article: a, flushBelow: flushBelow); // full-bleed
      case 3:
        return SplitCard(article: a, flushBelow: flushBelow); // image left
      case 4:
        return MagazineCard(article: a, flushBelow: flushBelow); // large image-top
      case 5:
        return SplitCard(
            article: a, imageRight: true, flushBelow: flushBelow); // image right
      default:
        return DefaultCard(article: a, flushBelow: flushBelow); // standard
    }
  }

  /// A row that renders as a big full-bleed image card (used to drop the band
  /// above it to a thin line when two such cards stack together).
  bool _isBigImageRow(Article a) => a.hasImage;

  /// Plan the feed into rows: mostly single full-width cards, with a periodic
  /// 2-up compact pair (two small cards side-by-side) to break the single-column
  /// rhythm — the structural variety that keeps the feed from reading as one
  /// repeated style. Pairs only group plain image cards (not video/text).
  List<List<Article>> _planRows(List<Article> items) {
    final rows = <List<Article>>[];
    var i = 0, r = 0;
    while (i < items.length) {
      final a = items[i];
      final next = i + 1 < items.length ? items[i + 1] : null;
      final pairable = r > 0 &&
          r % 4 == 1 &&
          a.hasImage &&
          !a.hasPlayableVideo &&
          next != null &&
          next.hasImage &&
          !next.hasPlayableVideo;
      if (pairable) {
        rows.add([a, next]);
        i += 2;
      } else {
        rows.add([a]);
        i += 1;
      }
      r++;
    }
    return rows;
  }

  /// Splice playable videos from the pool into the planned rows (~1 every 6
  /// rows, capped at the pool size), de-duped against what's already shown, so
  /// video is sprinkled through the feed instead of clustered.
  List<List<Article>> _interleaveVideos(
      List<List<Article>> rows, List<Article> pool) {
    if (pool.isEmpty) return rows;
    final seen = <String>{};
    for (final r in rows) {
      for (final a in r) {
        seen.add(a.id);
      }
    }
    final vids = pool.where((a) => !seen.contains(a.id)).toList();
    if (vids.isEmpty) return rows;
    final out = <List<Article>>[];
    var vi = 0;
    for (var i = 0; i < rows.length; i++) {
      out.add(rows[i]);
      if ((i + 1) % 10 == 0 && vi < vids.length) out.add([vids[vi++]]);
    }
    return out;
  }

  /// Render one planned row: a 2-up compact pair, or a single styled card.
  Widget _rowWidget(BuildContext context, int r, List<Article> row,
      {bool flushBelow = true}) {
    if (row.length == 2) {
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: CompactCard(article: row[0])),
              const SizedBox(width: AppSpace.md),
              Expanded(child: CompactCard(article: row[1])),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: context.colors.border),
      ]);
    }
    return _cardFor(r, row.first, flushBelow: flushBelow);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final notifier = ref.read(newsFeedControllerProvider.notifier);
    final feed = ref.watch(newsFeedControllerProvider);
    final dismissed = ref.watch(dismissedProvider);
    final filters = notifier.filters;

    void setFilters(NewsFilters f) {
      notifier.setFilters(f);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }

    return Scaffold(
      backgroundColor: c.bg,
      drawer: const AppDrawer(),
      body: RefreshIndicator.adaptive(
        onRefresh: notifier.refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.menu, color: c.text),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              title:
                  Text('News Feed', style: AppText.title.copyWith(color: c.text)),
              actions: [
                // Time period (ports the web "Any time" dropdown → ?since=).
                PopupMenuButton<String>(
                  tooltip: 'Time period',
                  icon: Icon(Icons.history,
                      color: filters.since != null ? c.brand : c.text),
                  onSelected: (v) =>
                      setFilters(filters.copyWith(since: v.isEmpty ? null : v)),
                  itemBuilder: (_) => [
                    _timeItem(c, '', 'Any time', filters.since),
                    _timeItem(c, '1h', 'Past hour', filters.since),
                    _timeItem(c, '24h', 'Past 24 hours', filters.since),
                    _timeItem(c, '7d', 'Past week', filters.since),
                  ],
                ),
                // View layout: Mixed · Magazine · Grid · List.
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(76),
                child: _FilterBar(
                    filters: filters,
                    onChanged: setFilters,
                    onOpenSources: _openSourcePicker),
              ),
            ),
            feed.when(
              loading: () => SliverPadding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                sliver: SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (_, __) => const SkeletonCard(),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.x2),
                    child: Text("Couldn't load the feed.\n$e",
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(color: c.textSecondary)),
                  ),
                ),
              ),
              data: (allItems) {
                final items = allItems
                    .where((a) => !dismissed.contains(a.id))
                    .toList();
                // Few inline video cards, not walls of them — except in the
                // dedicated Videos filter view, where video IS the content.
                _videoOk = filters.video
                    ? items.map((a) => a.id).toSet()
                    : throttleVideoCards(items);
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('No stories match these filters.',
                          style:
                              AppText.body.copyWith(color: c.textSecondary)),
                    ),
                  );
                }
                Widget loader() => Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpace.xl),
                      child: notifier.hasMore
                          ? const Center(
                              child: CircularProgressIndicator.adaptive())
                          : const SizedBox(height: AppSpace.lg),
                    );
                switch (_view) {
                  case FeedView.list:
                    return SliverList.builder(
                      itemCount: items.length + 1,
                      itemBuilder: (context, i) => i == items.length
                          ? loader()
                          : FadeSlideIn(
                              key: ValueKey(items[i].id),
                              child: ListCard(article: items[i])),
                    );
                  case FeedView.magazine:
                    return SliverList.builder(
                      itemCount: items.length + 1,
                      itemBuilder: (context, i) => i == items.length
                          ? loader()
                          : FadeSlideIn(
                              key: ValueKey(items[i].id),
                              child: MagazineCard(article: items[i])),
                    );
                  case FeedView.grid:
                    return SliverPadding(
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
                          (context, i) => FadeSlideIn(
                            key: ValueKey(items[i].id),
                            child: CompactCard(
                                article: items[i], width: double.infinity),
                          ),
                          childCount: items.length,
                        ),
                      ),
                    );
                  case FeedView.mixed:
                    // Weave a few license-safe videos into the feed (capped,
                    // ~1 per 6 cards). Skipped when the Videos filter is on.
                    final pool = filters.video
                        ? const <Article>[]
                        : (ref.watch(videoPoolProvider).valueOrNull ??
                            const <Article>[]);
                    final rows = _interleaveVideos(_planRows(items), pool);
                    return SliverList.builder(
                      itemCount: rows.length + 1,
                      itemBuilder: (context, i) {
                        if (i == rows.length) return loader();
                        final row = rows[i];
                        // Grey band ONLY between two stacked big image cards.
                        final next = i + 1 < rows.length ? rows[i + 1] : null;
                        final flushBelow = row.length == 1 &&
                            _isBigImageRow(row.first) &&
                            next != null &&
                            next.length == 1 &&
                            _isBigImageRow(next.first);
                        return FadeSlideIn(
                          key: ValueKey(row.first.id),
                          child: _rowWidget(context, i, row,
                              flushBelow: flushBelow),
                        );
                      },
                    );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky filter bar: category chips (row 1) + sort & impact (row 2).
class _FilterBar extends StatelessWidget {
  const _FilterBar(
      {required this.filters,
      required this.onChanged,
      required this.onOpenSources});
  final NewsFilters filters;
  final ValueChanged<NewsFilters> onChanged;
  final VoidCallback onOpenSources;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Categories.
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              children: [
                _Chip(
                  label: 'All',
                  selected: filters.category == null,
                  onTap: () => onChanged(filters.copyWith(category: null)),
                ),
                for (final (slug, label) in kNewsCategories) ...[
                  const _VLine(),
                  _Chip(
                    label: label,
                    selected: filters.category == slug,
                    onTap: () => onChanged(filters.copyWith(category: slug)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 5),
          // Deeper hairline between the two filter rows.
          Divider(
              height: 1,
              thickness: 1,
              color:
                  Color.alphaBlend(c.textFaint.withValues(alpha: 0.5), c.border)),
          const SizedBox(height: 5),
          // Sort + impact.
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              children: [
                _Chip(
                  label: filters.source ?? 'Sources',
                  icon: Icons.rss_feed,
                  selected: filters.source != null,
                  onTap: onOpenSources,
                ),
                const _VLine(),
                _Chip(
                  label: 'Videos',
                  icon: Icons.play_circle_outline,
                  selected: filters.video,
                  onTap: () =>
                      onChanged(filters.copyWith(video: !filters.video)),
                ),
                const _VLine(),
                _Chip(
                  label: 'Latest',
                  icon: Icons.schedule,
                  selected: filters.sort == 'latest',
                  onTap: () => onChanged(filters.copyWith(sort: 'latest')),
                ),
                const _VLine(),
                _Chip(
                  label: 'Trending',
                  icon: Icons.trending_up,
                  selected: filters.sort == 'trending',
                  onTap: () => onChanged(filters.copyWith(sort: 'trending')),
                ),
                const _VLine(),
                _Chip(
                  label: 'Any impact',
                  selected: filters.impact == null,
                  onTap: () => onChanged(filters.copyWith(impact: null)),
                ),
                for (final lvl in const ['Critical', 'High', 'Medium', 'Low']) ...[
                  const _VLine(),
                  _Chip(
                    label: lvl,
                    dotColor: c.impact(lvl),
                    selected: filters.impact == lvl,
                    onTap: () => onChanged(filters.copyWith(impact: lvl)),
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

/// Thin vertical hairline between filters.
class _VLine extends StatelessWidget {
  const _VLine();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(width: 1, height: 15, color: context.colors.border),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dotColor,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Minimal text filter (no box/tab): active = brand + bold, else faded.
    final fg = selected ? c.brand : c.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 5),
            ],
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: AppText.body.copyWith(
                    color: fg,
                    fontSize: 13.5,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet source picker. Pops with '' for "All sources", a source name,
/// or null when dismissed. Sources come from [sourcesProvider].
class _SourcePickerSheet extends ConsumerWidget {
  const _SourcePickerSheet({required this.current});
  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sources = ref.watch(sourcesProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
              child: Row(
                children: [
                  Text('Filter by source',
                      style: AppText.bodyStrong.copyWith(color: c.text)),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Flexible(
              child: sources.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpace.xl),
                    child: Center(child: CircularProgressIndicator.adaptive())),
                error: (e, _) => Padding(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    child: Text("Couldn't load sources.",
                        style:
                            AppText.body.copyWith(color: c.textSecondary))),
                data: (list) => ListView(
                  shrinkWrap: true,
                  children: [
                    _SourceRow(
                      label: 'All sources',
                      selected: current == null,
                      onTap: () => Navigator.pop(context, ''),
                    ),
                    for (final s in list)
                      _SourceRow(
                        label: s,
                        selected: current == s,
                        onTap: () => Navigator.pop(context, s),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      dense: true,
      title: Text(label,
          style: AppText.body.copyWith(
              color: selected ? c.brand : c.text,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      trailing: selected ? Icon(Icons.check, size: 18, color: c.brand) : null,
      onTap: onTap,
    );
  }
}
