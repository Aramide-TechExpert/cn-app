import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../utils/format.dart';
import '../../../utils/link_out.dart';
import 'article_actions.dart';

/// Fixed-width poster card for horizontal rails (web "rail" feel): image on
/// top, title + source below. No curve.
class RailCard extends ConsumerWidget {
  const RailCard({super.key, required this.article, this.width = 248});

  final Article article;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final hue = hueFromString(article.source).toDouble();

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => openArticle(article.sourceUrl),
        onLongPress: () => showArticleActions(context, ref, article),
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
                      errorWidget: (_, __, ___) => Container(
                          color:
                              HSLColor.fromAHSL(1, hue, 0.5, 0.4).toColor()),
                    )
                  else
                    Container(
                        color: HSLColor.fromAHSL(1, hue, 0.5, 0.4).toColor()),
                  if (article.isBreaking)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        color: c.breaking,
                        child: const Text('BREAKING',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong.copyWith(color: c.text, height: 1.3)),
            const SizedBox(height: 4),
            Text('${article.source} · ${timeAgo(article.publishedAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: c.textFaint)),
          ],
        ),
      ),
    );
  }
}
