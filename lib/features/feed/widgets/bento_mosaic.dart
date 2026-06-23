import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../utils/format.dart';
import '../../../utils/link_out.dart';
import 'card_extras.dart';

/// Compact 2-column mosaic of full-bleed image tiles with overlaid titles — the
/// web "bento" feel in an overflow-safe fixed grid (tiles are aspect-ratio
/// bounded, text is ellipsis-clipped). Used as a "Top stories" block on Home.
class BentoMosaic extends StatelessWidget {
  const BentoMosaic({super.key, required this.articles});
  final List<Article> articles;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpace.md,
      crossAxisSpacing: AppSpace.md,
      childAspectRatio: 0.92,
      children: [for (final a in articles) _BentoTile(article: a)],
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hue = hueFromString(article.source).toDouble();
    final mono = Container(color: HSLColor.fromAHSL(1, hue, 0.5, 0.4).toColor());
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (article.hasImage)
              CachedNetworkImage(
                imageUrl: article.image,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: c.bgInset),
                errorWidget: (_, __, ___) => mono,
              )
            else
              mono,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            if (article.isBreaking)
              const Positioned(top: 0, left: 0, child: LiveBadge()),
            Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.2)),
                  const SizedBox(height: 2),
                  Text(article.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
