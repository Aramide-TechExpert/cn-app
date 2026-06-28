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
import 'inline_video.dart';
import 'signal_badges.dart';

// ── shared image cover (network image or monogram fallback), square corners ──
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

// Animated pulsing BREAKING badge (see card_extras.dart).
Widget _breaking(BuildContext context) => const LiveBadge();

/// Reading-time pill positioned at the image's bottom-right (feed cards).
Widget _readTimeOverlay(Article a) => Positioned(
      right: AppSpace.sm,
      bottom: AppSpace.sm,
      child: ReadingTimeBadge(minutes: a.readingMinutes),
    );

/// Optional "Gaining attention" line shown under the signal row.
Widget _attention(Article a) => GainingAttention.qualifies(a)
    ? const Padding(
        padding: EdgeInsets.only(top: 6),
        child: GainingAttention(),
      )
    : const SizedBox.shrink();

/// SPLIT — horizontal magazine card: a landscape image on one side, text on the
/// other. The side alternates (web "magazine-alternating") so consecutive split
/// cards mirror each other — a distinct shape from the vertical image-top cards.
class SplitCard extends ConsumerWidget {
  const SplitCard({super.key, required this.article, this.imageRight = false});
  final Article article;
  final bool imageRight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 132,
        height: 112,
        child: Stack(fit: StackFit.expand, children: [
          _cover(context, article),
          if (article.isBreaking)
            Positioned(top: 0, left: 0, child: _breaking(context)),
        ]),
      ),
    );
    final text = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SignalRow(article: article),
          const SizedBox(height: 6),
          Text(article.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong.copyWith(color: c.text, height: 1.3)),
          const SizedBox(height: 6),
          SourceLine(article: article),
        ],
      ),
    );
    return Column(children: [
      InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        onLongPress: () => showArticleActions(context, ref, article),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: imageRight
                ? [text, const SizedBox(width: AppSpace.md), image]
                : [image, const SizedBox(width: AppSpace.md), text],
          ),
        ),
      ),
      _divider(context),
    ]);
  }
}

Widget _divider(BuildContext context) =>
    Divider(height: 1, thickness: 1, color: context.colors.border);

const _bodyPad =
    EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg);

/// DEFAULT — full-width square card: full-bleed image, signals, title, source.
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
                _readTimeOverlay(article),
                if (article.isBreaking)
                  Positioned(top: 0, left: 0, child: _breaking(context)),
              ]),
            ),
            Padding(
              padding: _bodyPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SignalRow(article: article),
                  _attention(article),
                  const SizedBox(height: AppSpace.sm),
                  Text(article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headline
                          .copyWith(color: c.text, fontSize: 16)),
                  if (article.blurb != null) ...[
                    const SizedBox(height: 6),
                    Text(article.blurb!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(color: c.textSecondary)),
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
      _divider(context),
    ]);
  }
}

/// WIDE — prominent feature: short 2:1 image, larger title + summary.
class WideCard extends ConsumerWidget {
  const WideCard({super.key, required this.article, this.bandBelow = true});
  final Article article;
  /// Grey section band below (default). The feed sets this false when the next
  /// card is also a big image card, so two stacked image cards get a thin line.
  final bool bandBelow;

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
                _readTimeOverlay(article),
                if (article.isBreaking)
                  Positioned(top: 0, left: 0, child: _breaking(context)),
              ]),
            ),
            Padding(
              padding: _bodyPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SignalRow(article: article),
                  _attention(article),
                  const SizedBox(height: AppSpace.sm),
                  Text(article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title
                          .copyWith(color: c.text, fontSize: 20, height: 1.2)),
                  if (article.blurb != null) ...[
                    const SizedBox(height: 6),
                    Text(article.blurb!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(color: c.textSecondary)),
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
      bandBelow ? const BlockDivider() : _divider(context),
    ]);
  }
}

/// FEATURED — text-only square card with a "Why it matters" callout.
class FeaturedCard extends ConsumerWidget {
  const FeaturedCard({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(children: [
      InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        onLongPress: () => showArticleActions(context, ref, article),
        child: Container(
          width: double.infinity,
          color: c.bgInset,
          padding: _bodyPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  color: c.brand,
                  child: const Text('FEATURED',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                ),
                const SizedBox(width: 6),
                Expanded(child: SignalRow(article: article)),
              ]),
              const SizedBox(height: AppSpace.sm),
              Text(article.title,
                  style: AppText.headline.copyWith(color: c.text, fontSize: 16)),
              if (article.blurb != null) ...[
                const SizedBox(height: 6),
                Text(article.blurb!,
                    style: AppText.body.copyWith(color: c.textSecondary)),
              ],
              if ((article.whyItMatters ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.md),
                  color: c.brandSoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WHY IT MATTERS',
                          style: TextStyle(
                              color: c.brand,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4)),
                      const SizedBox(height: 4),
                      Text(article.whyItMatters!,
                          style: AppText.body.copyWith(color: c.text)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              SourceLine(article: article),
            ],
          ),
        ),
      ),
      const BlockDivider(),
    ]);
  }
}

/// VIDEO — full-width square card with a play overlay + VIDEO tag.
class VideoCard extends ConsumerWidget {
  const VideoCard({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(children: [
      // Media: stream inline when the source carries a self-hosted video,
      // otherwise a link-out poster with the VIDEO tag + play overlay.
      if (article.hasPlayableVideo)
        InlineVideo(article: article)
      else
        InkWell(
          onTap: () => openArticle(article.sourceUrl, track: article),
          onLongPress: () => showArticleActions(context, ref, article),
          child: AspectRatio(
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
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: Colors.black.withValues(alpha: 0.6),
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
        ),
      InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        onLongPress: () => showArticleActions(context, ref, article),
        child: Padding(
          padding: _bodyPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SignalRow(article: article),
              _attention(article),
              const SizedBox(height: AppSpace.sm),
              Text(article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppText.headline.copyWith(color: c.text, fontSize: 16)),
              if (article.blurb != null) ...[
                const SizedBox(height: 6),
                Text(article.blurb!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(color: c.textSecondary)),
              ],
              const SizedBox(height: AppSpace.sm),
              SourceLine(article: article),
              const SizedBox(height: AppSpace.md),
              EngagementBar(article: article),
            ],
          ),
        ),
      ),
      _divider(context),
    ]);
  }
}

/// LIST — compact inline item, no image: signals + title + source.
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
              const SizedBox(height: 6),
              Text(article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(color: c.text)),
              const SizedBox(height: 6),
              SourceLine(article: article, showReadTime: true),
            ],
          ),
        ),
      ),
      _divider(context),
    ]);
  }
}

/// COMPACT — fixed-width square rail card: image + title + source.
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
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                _cover(context, article),
                if (article.isBreaking)
                  Positioned(top: 0, left: 0, child: _breaking(context)),
              ]),
            ),
            const SizedBox(height: 6),
            Text(article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong.copyWith(color: c.text, fontSize: 14)),
            const SizedBox(height: 4),
            SourceLine(article: article),
          ],
        ),
      ),
    );
  }
}

/// VERTICAL — 9:16 square reels card: full-bleed + overlay.
class VerticalCard extends ConsumerWidget {
  const VerticalCard(
      {super.key, required this.article, this.width = 150, this.onTap});
  final Article article;
  final double width;
  /// When set (Shorts rail), tapping the card runs this (open full reel) instead
  /// of toggling the inline preview's play/pause.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = Positioned(
      left: AppSpace.sm,
      right: AppSpace.sm,
      bottom: AppSpace.sm,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(article.source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption
                    .copyWith(color: Colors.white.withValues(alpha: 0.85))),
            const SizedBox(height: 2),
            Text(article.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
    // Real video → autoplaying inline player (Shorts); else link-out poster.
    if (article.hasPlayableVideo) {
      return SizedBox(
        width: width,
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(children: [
            InlineVideo(
                article: article,
                aspectRatio: 9 / 16,
                tapToToggle: onTap == null),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                      stops: [0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            overlay,
          ]),
          ),
        ),
      );
    }
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => openArticle(article.sourceUrl, track: article),
        onLongPress: () => showArticleActions(context, ref, article),
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
              Positioned(top: 0, left: 0, child: _breaking(context)),
            overlay,
          ]),
        ),
      ),
    );
  }
}
