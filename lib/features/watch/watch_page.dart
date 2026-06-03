import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      body: SafeArea(
        bottom: false,
        child: watch.when(
          loading: () => Center(child: CircularProgressIndicator(color: c.brand)),
          error: (_, __) => Center(
            child: Text("Couldn't load videos.",
                style: AppText.body.copyWith(color: c.textSecondary)),
          ),
          data: (items) => RefreshIndicator(
            color: c.brand,
            onRefresh: () async => ref.invalidate(watchFeedProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.x3),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpace.lg),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CLUSTEZ',
                          style: AppText.micro
                              .copyWith(color: c.brand, letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text('Watch',
                          style: AppText.display.copyWith(color: c.text)),
                      const SizedBox(height: AppSpace.sm),
                    ],
                  );
                }
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpace.x4),
                    child: Center(
                      child: Text('No videos right now.',
                          style:
                              AppText.body.copyWith(color: c.textSecondary)),
                    ),
                  );
                }
                return _VideoCard(article: items[i - 1]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openArticle(article.sourceUrl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
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
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.play_circle_fill,
                        size: 56, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headline.copyWith(color: c.text)),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    '${article.source} · ${timeAgo(article.publishedAt)}',
                    style: AppText.caption.copyWith(color: c.textFaint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
