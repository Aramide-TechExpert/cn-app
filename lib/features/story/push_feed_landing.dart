import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/feed_controller.dart' show apiClientProvider;
import '../../models/article.dart';
import '../../theme/tokens.dart';
import '../../utils/link_out.dart';
import '../discover/discover_page.dart';

/// EVERY push tap lands here (owner ruling 2026-11-08) — single stories and
/// ▶×3 digests alike. This widget only resolves the pushed article ids, then
/// renders the REAL Feed page (DiscoverPage) with those stories pinned ahead
/// of the stream: story 1 becomes the hero card, the normal feed continues
/// underneath, filter bar / layout / chrome are the Feed's own. No clone
/// screen exists, so the landing can never diverge from the Feed page.
///
/// If every pushed story has already left the fresh window, the publisher
/// link from the payload (single pushes carry one) opens directly and the
/// plain Feed renders behind it.
class PushFeedLanding extends ConsumerStatefulWidget {
  const PushFeedLanding({super.key, required this.ids, this.fallbackLink});

  /// Comma-separated article ids (external_id ?? uuid) from the push payload.
  final String ids;

  /// Publisher URL from a single-story push — the purged-story fallback.
  final String? fallbackLink;

  @override
  ConsumerState<PushFeedLanding> createState() => _PushFeedLandingState();
}

class _PushFeedLandingState extends ConsumerState<PushFeedLanding> {
  List<Article>? _pinned;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = widget.ids
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(10)
        .toList();
    final api = ref.read(apiClientProvider);
    // Fetch in parallel; a purged story simply drops off the pinned block.
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
    final pinned = results.whereType<Article>().toList();
    setState(() => _pinned = pinned);
    if (pinned.isEmpty &&
        widget.fallbackLink != null &&
        widget.fallbackLink!.isNotEmpty) {
      // Story gone before the tap — honor the tap with the publisher page;
      // the user is already on the Feed when they come back.
      openArticle(widget.fallbackLink);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _pinned;
    if (pinned == null) {
      // Brief id-resolve wait — then it's the Feed page, nothing else.
      return Scaffold(
        backgroundColor: context.colors.bg,
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    return DiscoverPage(pinned: pinned);
  }
}
