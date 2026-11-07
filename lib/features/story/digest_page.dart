import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/feed_controller.dart' show apiClientProvider;
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/interleave.dart' show throttleVideoCards;
import '../feed/widgets/card_extras.dart' show FadeSlideIn;
import '../feed/widgets/feed_pattern.dart';

/// In-app landing for the ▶×3 digest push — the FULL group of stories the
/// notification listed, rendered EXACTLY like the FEED tab (owner ruling
/// 2026-10-27: the Feed page's thumbnail/card style, not Home's) via the
/// shared newsFeedCard template: Overlay hero, 6-step cycle, 2-up pairs,
/// fade-slide entrances. Lives INSIDE the Feed shell branch so the app
/// footer menu shows (router.dart).
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

  /// The FEED tab's template verbatim: planned rows (singles + 2-up compact
  /// pairs), the news-feed card cycle (Overlay hero first), video throttle,
  /// band logic and fade-slide entrances.
  Widget _feed(BuildContext context, List<Article> articles) {
    final videoOk = throttleVideoCards(articles);
    final rows = planFeedRows(articles);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        return FadeSlideIn(
          key: ValueKey(row.first.id),
          child: row.length == 2
              ? feedPairRow(context, row)
              : newsFeedCard(i, row.first,
                  flushBelow: newsFeedFlushBelow(rows, i),
                  videoOk: videoOk.contains(row.first.id)),
        );
      },
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
