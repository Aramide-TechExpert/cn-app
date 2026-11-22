import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart' show currentUserProvider;
import '../../data/feed_controller.dart' show apiClientProvider;
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/interleave.dart' show throttleVideoCards;
import '../../utils/link_out.dart';
import '../../utils/source_regions.dart' show activeScopes;
import '../feed/widgets/card_extras.dart' show FadeSlideIn;
import '../feed/widgets/feed_pattern.dart';

/// Single-story push landing — renders the notified article as a Feed Overlay
/// hero (identical card template to the Feed tab), then More News in the same
/// Feed card rhythm. Lives as a TOP-LEVEL route (outside the shell) so it
/// never interferes with the Feed tab stack (router.dart /story/:id).
/// Layout matches the Feed page exactly: CustomScrollView + slivers + pinned AppBar.
class StoryPage extends ConsumerStatefulWidget {
  const StoryPage({super.key, required this.id, this.fallbackLink});

  /// external_id or db uuid — `GET /articles/:id` accepts both.
  final String id;

  /// Publisher URL from the push payload — used when the article has been
  /// purged before the user tapped.
  final String? fallbackLink;

  @override
  ConsumerState<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends ConsumerState<StoryPage> {
  final _scroll = ScrollController();
  Article? _article;
  ({String id, String title, int sources})? _cluster;
  List<Article> _more = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    Article? a;
    try {
      a = await ref.read(apiClientProvider).article(widget.id);
    } catch (_) {
      a = null;
    }
    if (!mounted) return;
    setState(() {
      _article = a;
      _loading = false;
    });
    final dbId = a?.dbId;
    if (dbId != null) {
      final cluster = await ref.read(apiClientProvider).clusterForArticle(dbId);
      if (mounted && cluster != null) setState(() => _cluster = cluster);
    }
    // More news: user's personalised feed, minus this story.
    try {
      final meta = ref.read(currentUserProvider)?.userMetadata;
      final scopeSegments =
          activeScopes(meta).map((s) => s.segment).toSet().toList();
      final favs = ((meta?['preferred_sources'] as List?) ?? const [])
          .cast<String>()
          .toList();
      final page = await ref.read(apiClientProvider).feed(
            limit: 14,
            region: scopeSegments.isEmpty ? 'Worldwide' : null,
            regions: scopeSegments,
            sources: favs,
          );
      if (!mounted) return;
      setState(() {
        _more = page.items
            .where((m) => m.id != a?.id)
            .take(10)
            .cast<Article>()
            .toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: RefreshIndicator.adaptive(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _article == null
                ? _missing(c)
                : _story(context, c, _article!),
      ),
    );
  }

  /// CustomScrollView matching the Feed page: pinned AppBar + hero + featured
  /// first more-news card + feed-rhythm more-news.
  Widget _story(BuildContext context, NewsSignalColors c, Article a) {
    final videoOk = throttleVideoCards([a, ..._more]);
    // First more-news card featured separately; rest follow feed rhythm.
    final firstMore = _more.isNotEmpty ? _more.first : null;
    final restMore = _more.length > 1
        ? _more.skip(1).cast<Article>().toList()
        : <Article>[];
    final restRows = planFeedRows(restMore);

    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverAppBar(
          pinned: true,
          floating: true,
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.text),
            onPressed: () => context.pop(),
          ),
          title: Text(a.source, style: AppText.title.copyWith(color: c.text)),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            // ── Main story — exact Feed Overlay hero (index 0) ─────────────────
            FadeSlideIn(
              child: newsFeedCard(0, a,
                  flushBelow: firstMore != null || _cluster != null,
                  videoOk: videoOk.contains(a.id)),
            ),

            // ── Full coverage ───────────────────────────────────────────────────
            if (_cluster != null) ...[
              const SizedBox(height: AppSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: _fullCoverage(c, _cluster!),
              ),
            ],

            // ── Featured first more-news card (full-width) ──────────────────────
            if (firstMore != null) ...[
              const SizedBox(height: AppSpace.md),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
                child: Text(
                  'RELATED',
                  style: AppText.caption.copyWith(
                      color: c.brand,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1),
                ),
              ),
              FadeSlideIn(
                child: newsFeedCard(0, firstMore,
                    flushBelow: restRows.isNotEmpty,
                    videoOk: videoOk.contains(firstMore.id)),
              ),
            ],
          ]),
        ),

        // ── Rest of more news — Feed card rhythm ────────────────────────────────
        if (restRows.isNotEmpty)
          SliverList.builder(
            itemCount: restRows.length,
            itemBuilder: (context, i) {
              final row = restRows[i];
              return FadeSlideIn(
                key: ValueKey(row.first.id),
                child: row.length == 2
                    ? feedPairRow(context, row)
                    : newsFeedCard(
                        i + 1, // start at 1 → Wide card, then Feed cycle
                        row.first,
                        flushBelow: newsFeedFlushBelow(restRows, i),
                        videoOk: videoOk.contains(row.first.id),
                      ),
              );
            },
          ),

        // ── Bottom padding ──────────────────────────────────────────────────────
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpace.xl),
        ),
      ],
    );
  }

  Widget _missing(NewsSignalColors c) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.text),
            onPressed: () => context.pop(),
          ),
          title: Text('Story', style: AppText.title.copyWith(color: c.text)),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off, size: 40, color: c.textFaint),
                  const SizedBox(height: AppSpace.md),
                  Text('This story has left the fresh window.',
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: c.textSecondary)),
                  const SizedBox(height: AppSpace.md),
                  if (widget.fallbackLink != null &&
                      widget.fallbackLink!.isNotEmpty) ...[
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.brand,
                        shape: const RoundedRectangleBorder(),
                      ),
                      onPressed: () => openArticle(widget.fallbackLink),
                      child: const Text('Read it on the publisher site'),
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fullCoverage(
      NewsSignalColors c, ({String id, String title, int sources}) cl) {
    return InkWell(
      onTap: () => context.push('/cluster/${cl.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: c.brand.withValues(alpha: .07),
          border: Border.all(color: c.brand.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            Icon(Icons.layers_outlined, color: c.brand, size: 22),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FULL COVERAGE',
                      style: AppText.caption.copyWith(
                          color: c.brand,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1)),
                  const SizedBox(height: 2),
                  Text('${cl.sources} sources are covering this story',
                      style: AppText.body.copyWith(color: c.text)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}
