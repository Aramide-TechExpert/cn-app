import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart' show currentUserProvider;
import '../../data/feed_controller.dart' show apiClientProvider;
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/link_out.dart';
import '../../utils/source_regions.dart' show activeScopes;
import '../feed/stack_feed_page.dart' show StackCard;

/// Reel-format landing for SINGLE-story pushes (owner ruling 2026-11-07):
/// the old story-page landing — hero thumbnail, buttons, the Save/Share row —
/// did not qualify. A push tap now opens the story as the Reel's full-bleed
/// StackCard (the EXACT /stack card, one code path), and swiping up keeps
/// reading fresh stories shaped to the user's own feed (region scopes +
/// favorite sources — never a random global slice). Close returns home.
class PushLandingPage extends ConsumerStatefulWidget {
  const PushLandingPage({super.key, required this.id, this.fallbackLink});

  /// external_id or db uuid — `GET /articles/:id` accepts both.
  final String id;

  /// Publisher URL from the push payload — used when the article has been
  /// purged from the feed window before the user tapped.
  final String? fallbackLink;

  @override
  ConsumerState<PushLandingPage> createState() => _PushLandingPageState();
}

class _PushLandingPageState extends ConsumerState<PushLandingPage> {
  final _controller = PageController();
  Article? _lead;
  List<Article> _more = const [];
  bool _loading = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      _lead = a;
      _loading = false;
    });
    if (a == null) return;
    // Swipe-up continuation: the user's own feed shape (same server params
    // as Home — scopes + favorites), minus the pushed story itself.
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
            .where((m) => m.id != a!.id && m.hasImage)
            .take(10)
            .toList();
      });
    } catch (_) {} // the continuation is a bonus, never an error state
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _lead == null
              ? _missing(context)
              : _reel(context),
    );
  }

  Widget _reel(BuildContext context) {
    final stack = [_lead!, ..._more];
    return Stack(children: [
      PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: stack.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) => StackCard(article: stack[i]),
      ),
      // Close affordance back home (same as the Reel tab).
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      // First-card hint that the landing continues — disappears on swipe.
      if (_page == 0 && _more.isNotEmpty)
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 6,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.keyboard_arrow_up,
                color: Colors.white54, size: 20),
            Text('Swipe up for more',
                style: AppText.caption.copyWith(color: Colors.white54)),
          ]),
        ),
    ]);
  }

  /// Article gone (purged window) — offer the publisher page instead.
  Widget _missing(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_toggle_off,
                size: 40, color: Colors.white38),
            const SizedBox(height: AppSpace.md),
            Text('This story has left the fresh window.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: Colors.white70)),
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
