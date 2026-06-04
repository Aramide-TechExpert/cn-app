import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../utils/format.dart';
import '../../../utils/link_out.dart';

/// Swipeable, parallax "spotlight" carousel for the top stories — a native,
/// dynamic hero that RN couldn't do as fluidly. Pages scale toward the centre.
class SpotlightCarousel extends StatefulWidget {
  const SpotlightCarousel({super.key, required this.articles});
  final List<Article> articles;

  @override
  State<SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<SpotlightCarousel> {
  late final PageController _controller =
      PageController(viewportFraction: 0.86);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page;
      if (p != null && mounted) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = widget.articles;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _controller,
            padEnds: true,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final delta = (_page - i).abs();
              final scale = (1 - delta * 0.07).clamp(0.9, 1.0);
              return Transform.scale(
                scale: scale,
                child: _SpotlightCard(
                  article: items[i],
                  // subtle parallax of the image vs the card
                  parallax: (_page - i).clamp(-1.0, 1.0),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.md),
        _Dots(count: items.length, active: _page.round(), color: c.brand),
      ],
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.article, required this.parallax});
  final Article article;
  final double parallax;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      child: Material(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: InkWell(
          onTap: () => openArticle(article.sourceUrl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (article.hasImage)
                OverflowBox(
                  maxWidth: double.infinity,
                  child: Transform.translate(
                    offset: Offset(parallax * 24, 0),
                    child: CachedNetworkImage(
                      imageUrl: article.image,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: c.bgInset),
                      errorWidget: (_, __, ___) => Container(color: c.bgInset),
                    ),
                  ),
                )
              else
                Container(color: c.bgInset),
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
              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.isBreaking)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.breaking,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text('BREAKING',
                            style: AppText.micro.copyWith(color: Colors.white)),
                      ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headline.copyWith(
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${article.source} · ${timeAgo(article.publishedAt)}',
                      style: AppText.caption
                          .copyWith(color: Colors.white.withValues(alpha: 0.85)),
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
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active, required this.color});
  final int count;
  final int active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final faint = context.colors.border;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: on ? color : faint,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
