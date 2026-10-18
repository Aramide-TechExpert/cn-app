import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/feed_controller.dart' show apiClientProvider;
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../feed/widgets/card_variants.dart';
import '../feed/widgets/magazine_card.dart';
import '../feed/widgets/overlay_card.dart';

/// In-app landing for the ▶×3 digest push — the FULL group of stories the
/// notification listed, rendered with the SAME dynamic card system as the
/// Home feed (owner ruling 2026-10-18: the flat thumbnail list was "not in
/// any way interesting" — this screen must look like Home/News, cycling
/// through the full-width card variants).
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
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpace.xl),
                  itemCount: articles.length,
                  itemBuilder: (_, i) => _digestCard(i, articles[i]),
                ),
    );
  }

  /// The Home feed's variant cycle — every card style surfaces as you scroll,
  /// with text fallbacks so image-led variants never render an empty box.
  Widget _digestCard(int i, Article a) {
    Widget overlay() => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: OverlayCard(article: a),
        );
    switch (i % 7) {
      case 0:
        return a.hasImage ? WideCard(article: a) : FeaturedCard(article: a);
      case 1:
        return a.hasImage ? DefaultCard(article: a) : ListCard(article: a);
      case 2:
        return a.hasImage
            ? SplitCard(article: a, imageRight: true)
            : ListCard(article: a);
      case 3:
        return a.hasImage ? overlay() : ListCard(article: a);
      case 4:
        return a.hasImage ? MagazineCard(article: a) : ListCard(article: a);
      case 5:
        return FeaturedCard(article: a);
      default:
        return a.hasImage
            ? SplitCard(article: a, imageRight: true)
            : ListCard(article: a);
    }
  }

  Widget _empty(ClusterNewsColors c) {
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
