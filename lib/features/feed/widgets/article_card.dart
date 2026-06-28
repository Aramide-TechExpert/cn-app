import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/auth_controller.dart';
import '../../../data/engagement_controller.dart';
import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../utils/format.dart';
import '../../../utils/link_out.dart';
import 'article_actions.dart';
import 'card_extras.dart';
import 'signal_badges.dart';

/// Compact, edge-to-edge row card (mirrors the web `row` variant): square
/// thumbnail + title + meta, full-width with a hairline divider. Tap link-outs;
/// long-press opens the native action sheet.
class ArticleCard extends ConsumerWidget {
  const ArticleCard({super.key, required this.article, this.showDivider = true});

  final Article article;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final dbId = article.dbId;
    final canEngage = dbId != null;
    final eng = ref.watch(engagementProvider).valueOrNull;
    final liked = canEngage && (eng?.liked.contains(dbId) ?? false);
    final marked = canEngage && (eng?.bookmarked.contains(dbId) ?? false);

    void act(Future<void> Function(String) toggle) {
      if (ref.read(currentUserProvider) == null) {
        context.push('/sign-in');
        return;
      }
      HapticFeedback.selectionClick();
      toggle(dbId!);
    }

    return Column(
      children: [
        InkWell(
          onTap: () => openArticle(article.sourceUrl, track: article),
          onLongPress: () => showArticleActions(context, ref, article),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg, vertical: AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(article: article),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SourceLine(article: article),
                      const SizedBox(height: 6),
                      Text(article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong
                              .copyWith(color: c.text, height: 1.3)),
                      const SizedBox(height: 8),
                      SignalRow(article: article),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text(readTime(article.readingMinutes),
                            style:
                                AppText.caption.copyWith(color: c.textFaint)),
                        const Spacer(),
                        if (canEngage) ...[
                          _IconBtn(
                            icon: marked
                                ? Icons.bookmark
                                : Icons.bookmark_outline,
                            color: marked ? c.brand : c.textFaint,
                            onTap: () => act(ref
                                .read(engagementProvider.notifier)
                                .toggleBookmark),
                          ),
                          const SizedBox(width: AppSpace.md),
                          _IconBtn(
                            icon:
                                liked ? Icons.favorite : Icons.favorite_outline,
                            color: liked ? c.accent : c.textFaint,
                            onTap: () => act(ref
                                .read(engagementProvider.notifier)
                                .toggleLike),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const BlockDivider(),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 112,
      height: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (article.hasImage)
            CachedNetworkImage(
              imageUrl: article.image,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: c.bgInset),
              errorWidget: (_, __, ___) => _Monogram(source: article.source),
            )
          else
            _Monogram(source: article.source),
          if (article.isBreaking)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                color: c.breaking,
                child: const Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final hue = hueFromString(source).toDouble();
    return Container(
      color: HSLColor.fromAHSL(1, hue, 0.5, 0.4).toColor(),
      alignment: Alignment.center,
      child: Text(initialOf(source),
          style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Icon(icon, size: 18, color: color),
    );
  }
}
