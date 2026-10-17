import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/auth_controller.dart' show currentUserProvider;
import '../../data/engagement_controller.dart';
import '../../data/feed_controller.dart' show apiClientProvider;
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../../utils/link_out.dart';
import '../feed/widgets/article_actions.dart';

/// In-app story landing — where notification taps arrive. Shows the card's
/// full orientation (image, AI summary, what happened / why it matters) so
/// the reader stays INSIDE Cluster News; the publisher page is a deliberate
/// button at the bottom, not the destination. This is the monetizable
/// surface (future ad slot lives on this screen).
class StoryPage extends ConsumerStatefulWidget {
  const StoryPage({super.key, required this.id, this.fallbackLink});

  /// external_id or db uuid — `GET /articles/:id` accepts both.
  final String id;

  /// Publisher URL from the push payload — used when the article has been
  /// purged from the feed window before the user tapped.
  final String? fallbackLink;

  @override
  ConsumerState<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends ConsumerState<StoryPage> {
  Article? _article;
  ({String id, String title, int sources})? _cluster;
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
      a = null; // purged / offline — the missing-state UI handles it
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
              : _story(c, _article!),
    );
  }

  /// Article gone (purged window) — offer the publisher page instead.
  Widget _missing(ClusterNewsColors c) {
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

  Widget _story(ClusterNewsColors c, Article a) {
    final sections = <(String, String)>[
      if ((a.summary ?? '').isNotEmpty) ('Summary', a.summary!),
      if ((a.whatHappened ?? '').isNotEmpty)
        ('What happened', a.whatHappened!),
      if ((a.whyItMatters ?? '').isNotEmpty)
        ('Why it matters', a.whyItMatters!),
    ];
    final lede = sections.isEmpty ? a.excerpt : null;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      children: [
        if (a.hasImage)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(imageUrl: a.image, fit: BoxFit.cover),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (a.isBreaking) _chip(c, 'BREAKING', danger: true),
                  _chip(c, a.impact.toUpperCase()),
                  if (a.trustScore != null) _chip(c, 'TRUST ${a.trustScore}'),
                  Text(
                      '${a.source} · ${timeAgo(a.publishedAt)} · ${readTime(a.readingMinutes)}',
                      style: AppText.caption.copyWith(color: c.textFaint)),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              Text(a.title,
                  style: AppText.headline.copyWith(color: c.text)),
              const SizedBox(height: AppSpace.md),
              if (lede != null)
                Text(lede,
                    style: AppText.body
                        .copyWith(color: c.textSecondary, height: 1.5)),
              for (final (head, body) in sections) ...[
                Text(head.toUpperCase(),
                    style: AppText.caption.copyWith(
                        color: c.brand,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1)),
                const SizedBox(height: AppSpace.xs),
                Text(body,
                    style: AppText.body
                        .copyWith(color: c.textSecondary, height: 1.5)),
                const SizedBox(height: AppSpace.md),
              ],
              _actionsRow(c, a),
              if (a.topics.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.xs,
                  children: [
                    for (final t in a.topics.take(6))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.bgElevated,
                          border: Border.all(color: c.border),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(t,
                            style: AppText.caption
                                .copyWith(color: c.textSecondary)),
                      ),
                  ],
                ),
              ],
              if (_cluster != null) ...[
                const SizedBox(height: AppSpace.md),
                _fullCoverage(c, _cluster!),
              ],
              const SizedBox(height: AppSpace.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: c.brand,
                  minimumSize: const Size.fromHeight(48),
                  shape: const RoundedRectangleBorder(),
                ),
                onPressed: () =>
                    openArticle(a.sourceUrl ?? widget.fallbackLink, track: a),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('Read the full story on ${a.source}'),
              ),
              const SizedBox(height: AppSpace.xs),
              Center(
                child: Text('Opens the publisher in the in-app browser',
                    style: AppText.caption.copyWith(color: c.textFaint)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Save · Share · More — the card actions, visible instead of buried.
  Widget _actionsRow(ClusterNewsColors c, Article a) {
    final dbId = a.dbId;
    final marked = dbId != null &&
        (ref
                .watch(engagementProvider)
                .valueOrNull
                ?.bookmarked
                .contains(dbId) ??
            false);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: marked ? c.brand : c.textSecondary,
              side: BorderSide(color: c.border),
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: dbId == null
                ? null
                : () {
                    if (ref.read(currentUserProvider) == null) {
                      context.push('/sign-in');
                      return;
                    }
                    HapticFeedback.selectionClick();
                    ref.read(engagementProvider.notifier).toggleBookmark(dbId);
                  },
            icon: Icon(marked ? Icons.bookmark : Icons.bookmark_outline,
                size: 18),
            label: Text(marked ? 'Saved' : 'Save'),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: c.textSecondary,
              side: BorderSide(color: c.border),
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: () {
              final url = a.sourceUrl;
              if (url != null && url.isNotEmpty) {
                Share.share('${a.title}\n$url');
              }
            },
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Share'),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        IconButton(
          onPressed: () => showArticleActions(context, ref, a),
          icon: Icon(Icons.more_horiz, color: c.textSecondary),
        ),
      ],
    );
  }

  /// "Full coverage" CTA — the same story from N sources (cluster detail).
  Widget _fullCoverage(
      ClusterNewsColors c, ({String id, String title, int sources}) cl) {
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

  Widget _chip(ClusterNewsColors c, String label, {bool danger = false}) {
    final color = danger ? const Color(0xFFE5484D) : c.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: AppText.caption.copyWith(
              color: color, fontWeight: FontWeight.w700, letterSpacing: .6)),
    );
  }
}
