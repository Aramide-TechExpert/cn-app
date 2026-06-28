import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../utils/format.dart';
import '../../../utils/link_out.dart';
import 'article_actions.dart';
import 'card_extras.dart';
import 'signal_badges.dart';

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
          onTap: () => openArticle(article.sourceUrl, track: article),
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
                    Positioned(
                      right: AppSpace.sm,
                      bottom: AppSpace.sm,
                      child: ReadingTimeBadge(minutes: article.readingMinutes),
                    ),
                    if (article.isBreaking)
                      const Positioned(top: 0, left: 0, child: LiveBadge()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SignalRow(article: article),
                    if (GainingAttention.qualifies(article)) ...[
                      const SizedBox(height: 6),
                      const GainingAttention(),
                    ],
                    const SizedBox(height: AppSpace.sm),
                    Text(article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headline
                            .copyWith(color: c.text, fontSize: 18, height: 1.25)),
                    if (blurb != null) ...[
                      const SizedBox(height: 6),
                      Text(blurb,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppText.body.copyWith(color: c.textSecondary)),
                    ],
                    const SizedBox(height: AppSpace.sm),
                    SourceLine(article: article),
                    const SizedBox(height: AppSpace.md),
                    EngagementBar(article: article),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
