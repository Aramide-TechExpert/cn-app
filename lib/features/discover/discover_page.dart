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
import '../feed/widgets/feed_pattern.dart';
import '../feed/widgets/card_extras.dart';
import '../feed/widgets/card_variants.dart';
import '../feed/widgets/magazine_card.dart';
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
  // Feed layout — its OWN served default (independent of Home's), user-overridable.
  FeedView _view = switch (remote.feedView) {
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

  PopupMenuItem<FeedView> _viewItem(NewsSignalColors c, FeedView v, String label) {
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
      NewsSignalColors c, String value, String label, String? current) {
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
                    final rows =
                        _interleaveVideos(planFeedRows(items), pool);
                    return SliverList.builder(
                      itemCount: rows.length + 1,
                      itemBuilder: (context, i) {
                        if (i == rows.length) return loader();
                        final row = rows[i];
                        return FadeSlideIn(
                          key: ValueKey(row.first.id),
                          child: row.length == 2
                              ? feedPairRow(context, row)
                              : newsFeedCard(i, row.first,
                                  // Grey band ONLY between two stacked big
                                  // image cards.
                                  flushBelow: newsFeedFlushBelow(rows, i),
                                  videoOk: _videoOk.contains(row.first.id)),
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
