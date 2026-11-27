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
import '../feed/widgets/card_variants.dart' show CompactCard;
import '../feed/widgets/feed_pattern.dart';
import '../shell/app_bottom_nav.dart' show LandingBottomNav;
import 'landing_header.dart';

/// Single-story push landing — the LOCKED template (owner spec 2026-11-27):
///   0. Header   — shared [landingHeader] ("TOP STORY" eyebrow + source), so
///      the screen reads as "occupied" like the Home/Feed tabs
///   1. Big hero  — the notified story as `newsFeedCard(0)`, the focal card
///      (no "Continue reading" button; the hero itself is the focus)
///   2. Full Coverage row — only when the story belongs to a cluster
///   3. "More News" slider — a horizontal `CompactCard` rail, exactly like the
///      homepage "Trending now" section
///   4. Rest of More News — 2-up compact pairs (`feedPairRow`), the small
///      side-by-side cards from the Feed page (NO trailing big cover card)
/// A TOP-LEVEL route (outside the shell) so it can never stack on the Feed
/// branch and break the Feed tab; the footer tabs are drawn by
/// [LandingBottomNav]. Single source of truth — do not add bespoke variants.
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
      // Footer tabs on the landing (owner 2026-11-25) — drawn by the shared
      // LandingBottomNav so it matches the real shell footer exactly and
      // routes straight to the real tabs. The landing itself is a top-level
      // route, so the Feed tab is never polluted.
      bottomNavigationBar: const LandingBottomNav(),
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

  /// The locked single-push template: big hero → Full Coverage (if clustered)
  /// → horizontal "More News" slider (homepage Trending style) → dynamic
  /// feed-rhythm cards for the remainder.
  Widget _story(BuildContext context, NewsSignalColors c, Article a) {
    final videoOk = throttleVideoCards([a, ..._more]);
    // First slice of More News becomes the horizontal slider; the rest renders
    // as 2-up compact pairs (the Feed page's small side-by-side cards) — never
    // a trailing big cover card (owner spec 2026-11-27).
    const sliderCount = 8;
    final sliderItems = _more.take(sliderCount).toList();
    final restMore = _more.length > sliderCount
        ? _more.skip(sliderCount).cast<Article>().toList()
        : <Article>[];
    // Chunk the remainder into pairs so each row is two small cards.
    final restPairs = <List<Article>>[];
    for (var k = 0; k < restMore.length; k += 2) {
      restPairs.add(restMore.sublist(
          k, k + 2 > restMore.length ? restMore.length : k + 2));
    }

    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        landingHeader(context, eyebrow: 'Top Story', title: a.source),
        SliverList(
          delegate: SliverChildListDelegate([
            // ── 1. Big hero — the pushed story as the focal card (index 0) ──────
            FadeSlideIn(
              child: newsFeedCard(0, a,
                  flushBelow: sliderItems.isNotEmpty || _cluster != null,
                  videoOk: videoOk.contains(a.id)),
            ),

            // ── 2. Full coverage (only when clustered) ──────────────────────────
            if (_cluster != null) ...[
              const SizedBox(height: AppSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: _fullCoverage(c, _cluster!),
              ),
            ],

            // ── 3. "More News" horizontal slider (homepage Trending style) ──────
            if (sliderItems.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
                child: Text('More News',
                    style: AppText.headline.copyWith(color: c.text)),
              ),
              SizedBox(
                height: 248,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  itemCount: sliderItems.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpace.md),
                  itemBuilder: (_, i) =>
                      CompactCard(article: sliderItems[i], width: 220),
                ),
              ),
            ],
          ]),
        ),

        // ── 4. Remainder — 2-up compact pairs (small Feed-page cards) ───────────
        // No trailing big cover card: each row is two small cards side by side
        // (owner spec 2026-11-27). A lone odd item sits as a single compact card.
        if (restPairs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
              child: Text('More to read',
                  style: AppText.headline.copyWith(color: c.text)),
            ),
          ),
          SliverList.builder(
            itemCount: restPairs.length,
            itemBuilder: (context, i) {
              final row = restPairs[i];
              return FadeSlideIn(
                key: ValueKey(row.first.id),
                child: row.length == 2
                    ? feedPairRow(context, row)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: CompactCard(article: row.first, width: 220),
                        ),
                      ),
              );
            },
          ),
        ],

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
        landingHeader(context, eyebrow: 'Top Story', title: 'Story'),
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
