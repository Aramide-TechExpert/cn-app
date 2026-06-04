import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../data/watch_controller.dart';
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../../utils/link_out.dart';

class WatchPage extends ConsumerWidget {
  const WatchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final watch = ref.watch(watchFeedProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.invalidate(watchFeedProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar.large(
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              title:
                  Text('Watch', style: AppText.title.copyWith(color: c.text)),
            ),
            watch.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
              error: (_, __) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text("Couldn't load videos.",
                      style: AppText.body.copyWith(color: c.textSecondary)),
                ),
              ),
              data: (items) => items.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('No videos right now.',
                            style:
                                AppText.body.copyWith(color: c.textSecondary)),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, 0, AppSpace.lg, AppSpace.x3),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpace.md,
                          crossAxisSpacing: AppSpace.md,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _VideoTile(article: items[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPreview(context, article),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (article.hasImage)
                    CachedNetworkImage(
                      imageUrl: article.image,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: c.bgInset),
                      errorWidget: (_, __, ___) => Container(color: c.bgInset),
                    )
                  else
                    Container(color: c.bgInset),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black45],
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.play_circle_fill,
                        size: 40, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.callout.copyWith(color: c.text)),
                  const SizedBox(height: 4),
                  Text(article.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: c.textFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// In-app preview sheet — plays YouTube INLINE; otherwise poster + link-out.
void _openPreview(BuildContext context, Article article) {
  final c = context.colors;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bgElevated,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (_) => _PreviewSheet(article: article),
  );
}

class _PreviewSheet extends StatefulWidget {
  const _PreviewSheet({required this.article});
  final Article article;

  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> {
  YoutubePlayerController? _yt;

  @override
  void initState() {
    super.initState();
    final url = widget.article.sourceUrl;
    final id = (url != null && url.isNotEmpty)
        ? YoutubePlayerController.convertUrlToId(url)
        : null;
    if (id != null) {
      _yt = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: true,
        params: const YoutubePlayerParams(showFullscreenButton: false),
      );
    }
  }

  @override
  void dispose() {
    _yt?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final article = widget.article;
    final inline = _yt != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: inline
                  ? YoutubePlayer(controller: _yt!, aspectRatio: 16 / 9)
                  : _Poster(article: article),
            ),
            const SizedBox(height: AppSpace.md),
            Text(article.title,
                style: AppText.headline.copyWith(color: c.text)),
            const SizedBox(height: 4),
            Text('${article.source} · ${timeAgo(article.publishedAt)}',
                style: AppText.caption.copyWith(color: c.textFaint)),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      openArticle(article.sourceUrl);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: inline ? c.bgInset : c.brand,
                      foregroundColor: inline ? c.text : c.onBrand,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: Icon(inline ? Icons.open_in_new : Icons.play_arrow),
                    label: Text(
                        inline
                            ? 'Open on ${article.source}'
                            : 'Watch on ${article.source}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                IconButton.filledTonal(
                  onPressed: () {
                    final url = article.sourceUrl;
                    if (url != null && url.isNotEmpty) {
                      Share.share('${article.title}\n$url');
                    }
                  },
                  icon: const Icon(Icons.ios_share),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (article.hasImage)
            CachedNetworkImage(imageUrl: article.image, fit: BoxFit.cover)
          else
            Container(color: c.bgInset),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
          const Center(
            child:
                Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
