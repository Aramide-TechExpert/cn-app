import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/feed_controller.dart' show apiClientProvider;
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';

/// In-app landing for the ▶×3 digest push — the FULL group of stories the
/// notification listed (not just the lead), each with its thumbnail, tapping
/// through to the in-app story screen. Keeps every headline on the push
/// reachable and the reader inside Cluster News (owner ruling 2026-10-17:
/// a list push must open the list, with thumbnails, never a single link).
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
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpace.md),
                  itemCount: articles.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpace.sm),
                  itemBuilder: (_, i) => _DigestCard(article: articles[i]),
                ),
    );
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

class _DigestCard extends StatelessWidget {
  const _DigestCard({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = article;
    return Material(
      color: c.bgElevated,
      child: InkWell(
        onTap: () => context.push('/story/${a.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 92,
                  height: 72,
                  child: a.hasImage
                      ? CachedNetworkImage(
                          imageUrl: a.image,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholder(c),
                        )
                      : _placeholder(c),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${a.source} · ${timeAgo(a.publishedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: c.textFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ClusterNewsColors c) => Container(
        color: c.bgInset,
        alignment: Alignment.center,
        child: Icon(Icons.public, size: 22, color: c.textFaint),
      );
}
