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

/// Primary feed card. Tap link-outs to the publisher (content model);
/// long-press opens the native action sheet.
class ArticleCard extends ConsumerWidget {
  const ArticleCard({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final blurb = article.blurb;

    return Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openArticle(article.sourceUrl),
        onLongPress: () => showArticleActions(context, ref, article),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(article: article),
              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SourceRow(article: article),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headline.copyWith(color: c.text),
                    ),
                    if (blurb != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        blurb,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(color: c.textSecondary),
                      ),
                    ],
                    const SizedBox(height: AppSpace.md),
                    _Footer(article: article),
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

class _Cover extends StatelessWidget {
  const _Cover({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AspectRatio(
      aspectRatio: 16 / 9,
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
              top: AppSpace.md,
              left: AppSpace.md,
              child: _Pill(label: 'BREAKING', color: c.breaking),
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
    final color = HSLColor.fromAHSL(1, hue, 0.5, 0.38).toColor();
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        initialOf(source),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 44,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hue = hueFromString(article.source).toDouble();
    final avatarColor = HSLColor.fromAHSL(1, hue, 0.55, 0.45).toColor();
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: avatarColor,
          child: Text(
            initialOf(article.source),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            article.source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption
                .copyWith(color: c.text, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 6),
        Text('· ${timeAgo(article.publishedAt)}',
            style: AppText.caption.copyWith(color: c.textFaint)),
      ],
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.article});
  final Article article;

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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: c.impact(article.impact),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(article.impact,
                style: AppText.caption.copyWith(color: c.textSecondary)),
          ],
        ),
        Row(
          children: [
            Text(readTime(article.readingMinutes),
                style: AppText.caption.copyWith(color: c.textFaint)),
            if (canEngage) ...[
              const SizedBox(width: AppSpace.md),
              _IconBtn(
                icon: marked ? Icons.bookmark : Icons.bookmark_outline,
                color: marked ? c.brand : c.textFaint,
                onTap: () => act(
                    ref.read(engagementProvider.notifier).toggleBookmark),
              ),
              const SizedBox(width: AppSpace.sm),
              _IconBtn(
                icon: liked ? Icons.favorite : Icons.favorite_outline,
                color: liked ? c.accent : c.textFaint,
                onTap: () =>
                    act(ref.read(engagementProvider.notifier).toggleLike),
              ),
            ],
          ],
        ),
      ],
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
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(label,
          style: AppText.micro.copyWith(color: Colors.white)),
    );
  }
}
