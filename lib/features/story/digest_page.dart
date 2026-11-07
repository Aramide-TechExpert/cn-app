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
/// notification listed, rendered EXACTLY like the FEED tab (owner rulings
/// 2026-10-27 + strict re-enforcement 2026-11-07): the page embeds the
/// SHARED newsFeedBody sliver in the SAME served layout mode as /discover,
/// so the arrangement is one code path and cannot diverge. Lives INSIDE the
/// Feed shell branch so the app footer menu shows (router.dart).
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
    // STRICT Feed parity (owner ruling 2026-11-07): the same scroll chrome
    // as /discover (pinned+floating bar, bouncing physics) and the SAME
    // shared newsFeedBody sliver in the SAME served layout mode — this page
    // renders nothing of its own, so it cannot drift from the Feed tab.
    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            title: Text('Fresh stories',
                style: AppText.title.copyWith(color: c.text)),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (articles.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _empty(c))
          else ...[
            newsFeedBody(
              context,
              view: servedFeedView(),
              items: articles,
              videoOk: throttleVideoCards(articles),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
          ],
        ],
      ),
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
