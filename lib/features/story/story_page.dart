import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/feed_controller.dart' show apiClientProvider;
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../../utils/link_out.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final a = await ref.read(apiClientProvider).article(widget.id);
    if (!mounted) return;
    setState(() {
      _article = a;
      _loading = false;
    });
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
                  Text('${a.source} · ${timeAgo(a.publishedAt)}',
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
              const SizedBox(height: AppSpace.sm),
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
