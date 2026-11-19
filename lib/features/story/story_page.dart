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
/// hero (identical card template to the Feed tab), then a "Continue reading"
/// CTA, an optional Full Coverage row, and a More News section in the same
/// Feed card rhythm. Lives as a TOP-LEVEL route (outside the shell) so it
/// never interferes with the Feed tab stack (router.dart /story/:id).
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
  Article? _article;
  ({String id, String title, int sources})? _cluster;
  List<Article> _more = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
            .toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Story', style: AppText.title.copyWith(color: c.text)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _article == null
              ? _missing(c)
              : _story(context, c, _article!),
    );
  }

  Widget _story(BuildContext context, NewsSignalColors c, Article a) {
    final videoOk = throttleVideoCards([a, ..._more]);
    final moreRows = planFeedRows(_more);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      children: [
        // ── Main story — exact Feed Overlay hero (index 0) ─────────────────
        newsFeedCard(0, a,
            flushBelow: moreRows.isNotEmpty || _cluster != null,
            videoOk: videoOk.contains(a.id)),

        // ── Continue reading CTA ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: c.brand,
              minimumSize: const Size.fromHeight(44),
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: () =>
                openArticle(a.sourceUrl ?? widget.fallbackLink, track: a),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text('Continue reading on ${a.source}'),
          ),
        ),

        // ── Full coverage ───────────────────────────────────────────────────
        if (_cluster != null) ...[
          const SizedBox(height: AppSpace.md),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: _fullCoverage(c, _cluster!),
          ),
        ],

        // ── More news — Feed card rhythm ────────────────────────────────────
        if (moreRows.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.sm),
            child: Text(
              'MORE NEWS',
              style: AppText.caption.copyWith(
                  color: c.brand,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1),
            ),
          ),
          for (var i = 0; i < moreRows.length; i++)
            FadeSlideIn(
              key: ValueKey(moreRows[i].first.id),
              child: moreRows[i].length == 2
                  ? feedPairRow(context, moreRows[i])
                  : newsFeedCard(
                      i + 1, // start at 1 → Wide card, then Feed cycle
                      moreRows[i].first,
                      flushBelow: newsFeedFlushBelow(moreRows, i),
                      videoOk: videoOk.contains(moreRows[i].first.id),
                    ),
            ),
        ],
      ],
    );
  }

  Widget _missing(NewsSignalColors c) {
    return Center(
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
