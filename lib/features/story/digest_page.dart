import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/feed_controller.dart' show apiClientProvider;
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/interleave.dart' show throttleVideoCards;
import '../feed/widgets/feed_pattern.dart';

/// In-app landing for the ▶×3 digest push — the FULL group of stories the
/// notification listed, rendered with the SAME feed template as Home/News
/// (owner rulings 2026-10-18 + 2026-10-26: shared pattern via
/// feed_pattern.dart — row planning, 2-up pairs, variant cycle, video
/// throttle — so this screen always matches the feeds), closed by a footer.
class DigestPage extends ConsumerStatefulWidget {
  const DigestPage({super.key, required this.ids});

  /// Comma-separated article ids (external_id ?? uuid) from the push payload.
  final String ids;

  @override
  ConsumerState<DigestPage> createState() => _DigestPageState();
}

class _DigestPageState extends ConsumerState<DigestPage> {
  List<Article>? _articles;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ids = widget.ids
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(10)
        .toList();
    final api = ref.read(apiClientProvider);
    // Fetch in parallel; a purged story simply drops off the list.
    final results = await Future.wait(
      ids.map((id) async {
        try {
          return await api.article(id);
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _articles = results.whereType<Article>().toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final articles = _articles ?? const <Article>[];
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Fresh stories', style: AppText.title.copyWith(color: c.text)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : articles.isEmpty
              ? _empty(c)
              : _feed(context, articles),
    );
  }

  /// The Home feed template verbatim: planned rows (singles + 2-up pairs),
  /// the full-width variant cycle, video throttling and band logic — then
  /// the footer as the last row.
  Widget _feed(BuildContext context, List<Article> articles) {
    final videoOk = throttleVideoCards(articles);
    final rows = planFeedRows(articles);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == rows.length) return _footer(context);
        final row = rows[i];
        if (row.length == 2) return feedPairRow(context, row);
        final a = row.first;
        return feedCard(i, a,
            flushBelow: feedFlushBelow(rows, i, videoOk),
            videoOk: videoOk.contains(a.id));
      },
    );
  }

  /// End-of-digest footer: closes the fixed list (no pagination here) and
  /// hands the reader to the live feed.
  Widget _footer(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: c.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.lg),
          child: Column(
            children: [
              Text("That's your digest",
                  style: AppText.headline.copyWith(color: c.text)),
              const SizedBox(height: AppSpace.sm),
              Text('More stories are landing on the feed right now.',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: c.textSecondary)),
              const SizedBox(height: AppSpace.lg),
              FilledButton(
                onPressed: () => context.go('/'),
                style: FilledButton.styleFrom(backgroundColor: c.brand),
                child: const Text('Open the full feed'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(NewsSignalColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, size: 40, color: c.textFaint),
            const SizedBox(height: AppSpace.md),
            Text('These stories have left the fresh window.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: c.textSecondary)),
            const SizedBox(height: AppSpace.sm),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Open the feed'),
            ),
          ],
        ),
      ),
    );
  }
}
