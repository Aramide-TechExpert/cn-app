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

/// Full-bleed feature card (mirrors the web `overlay` variant): edge-to-edge
/// image with a gradient + source/impact/headline overlaid. No curve. Used to
/// break up the row feed for a dynamic, magazine rhythm.
class OverlayCard extends ConsumerWidget {
  const OverlayCard(
      {super.key,
      required this.article,
      this.height = 220,
      this.bandBelow = false});

  final Article article;
  final double height;
  /// Grey band below — set true by the feed only when the next card is also a
  /// big image card (so two stacked image cards are split by the band).
  final bool bandBelow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final hue = hueFromString(article.source).toDouble();

    final card = InkWell(
      onTap: () => openArticle(article.sourceUrl, track: article),
      onLongPress: () => showArticleActions(context, ref, article),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (article.hasImage)
              CachedNetworkImage(
                imageUrl: article.image,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: c.bgInset),
                errorWidget: (_, __, ___) =>
                    Container(color: HSLColor.fromAHSL(1, hue, 0.5, 0.38).toColor()),
              )
            else
              Container(color: HSLColor.fromAHSL(1, hue, 0.5, 0.38).toColor()),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.35, 1.0],
                ),
              ),
            ),
            if (article.isBreaking)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 3),
                  color: c.breaking,
                  child: const Text('BREAKING',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                ),
              ),
            Positioned(
              left: AppSpace.lg,
              right: AppSpace.lg,
              bottom: AppSpace.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    SourceFavicon(
                        url: article.sourceUrl,
                        source: article.source,
                        size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${article.source} · ${timeAgo(article.publishedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headline
                          .copyWith(color: Colors.white, height: 1.25)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!bandBelow) return card;
    return Column(children: [card, const BlockDivider()]);
  }
}
