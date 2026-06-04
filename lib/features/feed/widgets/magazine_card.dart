import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../utils/format.dart';
import '../../../utils/link_out.dart';
import 'article_actions.dart';

/// Full-width image-top card (web "magazine"/"default"): big edge-to-edge
/// image, then a large headline + meta below. No curve; hairline divider.
class MagazineCard extends ConsumerWidget {
  const MagazineCard({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final hue = hueFromString(article.source).toDouble();
    final blurb = article.blurb;

    return Column(
      children: [
        InkWell(
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
                            color: HSLColor.fromAHSL(1, hue, 0.5, 0.4)
                                .toColor()),
                      )
                    else
                      Container(
                          color:
                              HSLColor.fromAHSL(1, hue, 0.5, 0.4).toColor()),
                    if (article.isBreaking)
                      Positioned(
                        top: AppSpace.md,
                        left: AppSpace.md,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.breaking,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: const Text('BREAKING',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: c.impact(article.impact),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${article.source} · ${timeAgo(article.publishedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                              color: c.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpace.sm),
                    Text(article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title
                            .copyWith(color: c.text, height: 1.2)),
                    if (blurb != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(blurb,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppText.body.copyWith(color: c.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: c.border),
      ],
    );
  }
}
