import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/dismissed_controller.dart';
import '../../data/news_feed_controller.dart';
import '../../data/source_signals.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../feed/widgets/card_extras.dart';
import '../feed/widgets/card_variants.dart';
import '../feed/widgets/magazine_card.dart';
import '../feed/widgets/overlay_card.dart';
import '../../models/article.dart';
import '../shell/app_drawer.dart';

/// News Feed — the filterable article stream (category · sort · impact),
/// mirroring the web feed. Full-width square cards.
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _scroll = ScrollController();
  bool _compact = false; // view mode: rich (image cards) vs compact (text list)

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

  /// Dynamic card rhythm — gives the feed visual variety instead of a flat
  /// column of identical cards (mirrors the web mosaic/bucketed feed). The hero
  /// leads, then a repeating cadence interleaves Magazine / Overlay / Wide
  /// feature cards between the Default run. Video → VideoCard; image-less →
  /// Featured (when it has a "why it matters") else the compact List card.
  Widget _cardFor(int i, Article a) {
    if (_compact) return ListCard(article: a);
    if (a.hasVideo && a.hasImage) return VideoCard(article: a);
    if (!a.hasImage) {
      return (a.whyItMatters ?? '').isNotEmpty
          ? FeaturedCard(article: a)
          : ListCard(article: a);
    }
    if (i == 0) return WideCard(article: a); // hero
    switch (i % 7) {
      case 2:
        return MagazineCard(article: a);
      case 4:
        return OverlayCard(article: a);
      case 6:
        return WideCard(article: a);
      default:
        return DefaultCard(article: a);
    }
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
                IconButton(
                  icon: Icon(
                      _compact
                          ? Icons.view_agenda_outlined
                          : Icons.view_headline,
                      color: c.text),
                  tooltip: _compact ? 'Rich view' : 'Compact view',
                  onPressed: () => setState(() => _compact = !_compact),
                ),
                IconButton(
                  icon: Icon(Icons.search, color: c.text),
                  onPressed: () => context.push('/search'),
                ),
                const SizedBox(width: AppSpace.xs),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(92),
                child: _FilterBar(filters: filters, onChanged: setFilters),
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
                return SliverList.builder(
                  itemCount: items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == items.length) {
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpace.xl),
                        child: notifier.hasMore
                            ? const Center(
                                child: CircularProgressIndicator.adaptive())
                            : const SizedBox(height: AppSpace.lg),
                      );
                    }
                    final a = items[i];
                    return FadeSlideIn(
                      key: ValueKey(a.id),
                      child: _cardFor(i, a),
                    );
                  },
                );
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
  const _FilterBar({required this.filters, required this.onChanged});
  final NewsFilters filters;
  final ValueChanged<NewsFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.bg,
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Categories.
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              children: [
                _Chip(
                  label: 'All',
                  selected: filters.category == null,
                  onTap: () => onChanged(filters.copyWith(category: null)),
                ),
                for (final (slug, label) in kNewsCategories)
                  _Chip(
                    label: label,
                    selected: filters.category == slug,
                    onTap: () => onChanged(filters.copyWith(category: slug)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Sort + impact.
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              children: [
                _Chip(
                  label: 'Latest',
                  icon: Icons.schedule,
                  selected: filters.sort == 'latest',
                  onTap: () => onChanged(filters.copyWith(sort: 'latest')),
                ),
                _Chip(
                  label: 'Trending',
                  icon: Icons.trending_up,
                  selected: filters.sort == 'trending',
                  onTap: () => onChanged(filters.copyWith(sort: 'trending')),
                ),
                Container(
                    width: 1,
                    height: 20,
                    margin:
                        const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                    color: c.border),
                _Chip(
                  label: 'Any impact',
                  selected: filters.impact == null,
                  onTap: () => onChanged(filters.copyWith(impact: null)),
                ),
                for (final lvl in const ['Critical', 'High', 'Medium', 'Low'])
                  _Chip(
                    label: lvl,
                    dotColor: c.impact(lvl),
                    selected: filters.impact == lvl,
                    onTap: () => onChanged(filters.copyWith(impact: lvl)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.sm),
      child: Material(
        color: selected ? c.brand : c.bgInset,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(border: Border.all(color: c.border)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: dotColor, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                ],
                if (icon != null) ...[
                  Icon(icon,
                      size: 13,
                      color: selected ? c.onBrand : c.textSecondary),
                  const SizedBox(width: 4),
                ],
                Text(label,
                    style: AppText.caption.copyWith(
                        color: selected ? c.onBrand : c.textSecondary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
