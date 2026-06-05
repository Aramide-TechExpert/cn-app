import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../utils/format.dart';
import '../../../utils/link_out.dart';
import 'article_actions.dart';
import 'signal_badges.dart';

// ── shared image cover (network image or monogram fallback) ──────────────────
Widget _cover(BuildContext context, Article a, {BoxFit fit = BoxFit.cover}) {
  final c = context.colors;
  final hue = hueFromString(a.source).toDouble();
  final mono = Container(
    color: HSLColor.fromAHSL(1, hue, 0.5, 0.4).toColor(),
    alignment: Alignment.center,
    child: Text(initialOf(a.source),
        style: const TextStyle(
            color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
  );
  if (!a.hasImage) return mono;
  return CachedNetworkImage(
    imageUrl: a.image,
    fit: fit,
    placeholder: (_, __) => Container(color: c.bgInset),
    errorWidget: (_, __, ___) => mono,
  );
}

Widget _breaking(BuildContext context) {
  final c = context.colors;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 3),
    decoration: BoxDecoration(
        color: c.breaking, borderRadius: BorderRadius.circular(AppRadii.pill)),
    child: const Text('BREAKING',
        style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4)),
  );
}

Widget _divider(BuildContext context) =>
    Divider(height: 1, thickness: 1, color: context.colors.border);

/// DEFAULT — standard full-width card: image-top, signal row, headline, source.
class DefaultCard extends ConsumerWidget {
  const DefaultCard({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(children: [
      InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        onLongPress: () => showArticleActions(context, ref, article),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                _cover(context, article),
                if (article.isBreaking)
                  Positioned(
                      top: AppSpace.md, left: AppSpace.lg, child: _breaking(context)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SignalRow(article: article),
                  const SizedBox(height: AppSpace.sm),
                  Text(article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headline.copyWith(color: c.text)),
                  const SizedBox(height: 6),
                  Text('${article.source} · ${timeAgo(article.publishedAt)}',
                      style: AppText.caption.copyWith(color: c.textFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
      _divider(context),
    ]);
  }
}

/// WIDE — prominent feature: short 2:1 image, big serif-ish headline + summary.
class WideCard extends ConsumerWidget {
  const WideCard({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(children: [
      InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        onLongPress: () => showArticleActions(context, ref, article),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 1,
              child: Stack(fit: StackFit.expand, children: [
                _cover(context, article),
                if (article.isBreaking)
                  Positioned(
                      top: AppSpace.md, left: AppSpace.lg, child: _breaking(context)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SignalRow(article: article),
                  const SizedBox(height: AppSpace.sm),
                  Text(article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display
                          .copyWith(color: c.text, fontSize: 24, height: 1.15)),
                  if (article.blurb != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(article.blurb!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(color: c.textSecondary)),
                  ],
                  const SizedBox(height: 6),
                  Text('${article.source} · ${timeAgo(article.publishedAt)}',
                      style: AppText.caption.copyWith(color: c.textFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
      _divider(context),
    ]);
  }
}

/// FEATURED — text-only analysis card with a "Why it matters" callout.
class FeaturedCard extends ConsumerWidget {
  const FeaturedCard({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
      child: Material(
        color: c.bgElevated,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () => openArticle(article.sourceUrl, track: article),
          onLongPress: () => showArticleActions(context, ref, article),
          child: Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: c.brandSoft,
                        borderRadius: BorderRadius.circular(AppRadii.sm)),
                    child: Text('FEATURED',
                        style: AppText.micro.copyWith(color: c.brand)),
                  ),
                ]),
                const SizedBox(height: AppSpace.sm),
                SignalRow(article: article),
                const SizedBox(height: AppSpace.sm),
                Text(article.title,
                    style: AppText.headline.copyWith(color: c.text)),
                if (article.blurb != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(article.blurb!,
                      style: AppText.body.copyWith(color: c.textSecondary)),
                ],
                if ((article.whyItMatters ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: BoxDecoration(
                      color: c.brandSoft,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WHY IT MATTERS',
                            style: AppText.micro.copyWith(color: c.brand)),
                        const SizedBox(height: 4),
                        Text(article.whyItMatters!,
                            style: AppText.body.copyWith(color: c.text)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                Text('${article.source} · ${timeAgo(article.publishedAt)}',
                    style: AppText.caption.copyWith(color: c.textFaint)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// VIDEO — image-top with a play overlay + VIDEO tag.
class VideoCard extends ConsumerWidget {
  const VideoCard({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(children: [
      InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        onLongPress: () => showArticleActions(context, ref, article),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                _cover(context, article),
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
                        size: 52, color: Colors.white)),
                Positioned(
                  top: AppSpace.md,
                  left: AppSpace.lg,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadii.sm)),
                    child: const Text('VIDEO',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4)),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SignalRow(article: article),
                  const SizedBox(height: AppSpace.sm),
                  Text(article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headline.copyWith(color: c.text)),
                  const SizedBox(height: 6),
                  Text('${article.source} · ${timeAgo(article.publishedAt)}',
                      style: AppText.caption.copyWith(color: c.textFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
      _divider(context),
    ]);
  }
}

/// LIST — minimal inline item, no image: signal row + headline + meta.
class ListCard extends ConsumerWidget {
  const ListCard({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(children: [
      InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        onLongPress: () => showArticleActions(context, ref, article),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SignalRow(article: article),
              const SizedBox(height: AppSpace.sm),
              Text(article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headline.copyWith(color: c.text, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                  '${article.source} · ${timeAgo(article.publishedAt)}'
                  '${article.readingMinutes > 0 ? ' · ${readTime(article.readingMinutes)}' : ''}',
                  style: AppText.caption.copyWith(color: c.textFaint)),
            ],
          ),
        ),
      ),
      _divider(context),
    ]);
  }
}

/// COMPACT — fixed-width rail card: 16:9 image + title + source + signals.
class CompactCard extends ConsumerWidget {
  const CompactCard({super.key, required this.article, this.width = 200});
  final Article article;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        onLongPress: () => showArticleActions(context, ref, article),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(fit: StackFit.expand, children: [
                  _cover(context, article),
                  if (article.isBreaking)
                    Positioned(top: 6, left: 6, child: _breaking(context)),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong.copyWith(color: c.text)),
            const SizedBox(height: 4),
            Row(children: [
              Flexible(
                child: Text(article.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: c.textFaint)),
              ),
              if (article.trustScore != null) ...[
                const SizedBox(width: 6),
                TrustPill(score: article.trustScore),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

/// VERTICAL — 9:16 reels card for a "Shorts" rail: full-bleed + overlay.
class VerticalCard extends ConsumerWidget {
  const VerticalCard({super.key, required this.article, this.width = 150});
  final Article article;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        onLongPress: () => showArticleActions(context, ref, article),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(fit: StackFit.expand, children: [
              _cover(context, article),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.45, 1.0],
                  ),
                ),
              ),
              const Center(
                  child: Icon(Icons.play_circle_fill,
                      size: 38, color: Colors.white)),
              if (article.isBreaking)
                Positioned(top: 8, left: 8, child: _breaking(context)),
              Positioned(
                left: AppSpace.sm,
                right: AppSpace.sm,
                bottom: AppSpace.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(article.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 2),
                    Text(article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
