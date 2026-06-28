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

/// Fade + slide-up entry animation (web AnimatedCard parity). Fire-and-forget
/// via TweenAnimationBuilder so it animates once when the element is built with
/// a fresh key (no re-animation churn while recycling during scroll).
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// A sweeping shimmer used for skeleton placeholders while the feed loads.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = c.bgInset;
    final hi = Color.alphaBlend(c.border.withValues(alpha: 0.6), base);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final dx = (_ctrl.value * 2) - 1; // -1 → 1
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(dx - 0.6, 0),
            end: Alignment(dx + 0.6, 0),
            colors: [base, hi, base],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

Widget _skelBox(BuildContext context, {double? w, double h = 12, double r = 4}) {
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: context.colors.bgInset,
      borderRadius: BorderRadius.circular(r),
    ),
  );
}

/// A single skeleton card (image block + two text lines), wrapped in Shimmer.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(color: c.bgInset),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
              child: _SkeletonLines(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLines extends StatelessWidget {
  const _SkeletonLines();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _skelBox(context, w: 90, h: 10),
        const SizedBox(height: AppSpace.sm),
        _skelBox(context, h: 16),
        const SizedBox(height: 6),
        _skelBox(context, w: 220, h: 16),
        const SizedBox(height: AppSpace.md),
        _skelBox(context, w: 140, h: 10),
      ],
    );
  }
}

/// A thick grey section band — a heavier separator than the hairline divider,
/// like the block separators between search-engine results. Used after select
/// feature cards (Wide / Featured / Magazine) to break the feed into chunks
/// without touching the cards' own layout.
class BlockDivider extends StatelessWidget {
  const BlockDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // A clean flat grey band (Google-style) — no border lines. Deeper than
    // bgInset so the section break reads distinct between cards.
    return Container(
      height: 12,
      color: Color.alphaBlend(c.border, c.bgInset),
    );
  }
}

/// Animated BREAKING badge with a softly pulsing dot — mirrors the web LivePulse.
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key});

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 3),
      color: c.breaking,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.25).animate(_ctrl),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Text('BREAKING',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

/// "Gaining attention" chip for high comment velocity — mirrors web
/// GainingAttention (>50 comments, or >15 within the last 6h).
class GainingAttention extends StatelessWidget {
  const GainingAttention({super.key});

  static bool qualifies(Article a) {
    if (a.commentCount > 50) return true;
    if (a.commentCount > 15) {
      final dt = DateTime.tryParse(a.publishedAt);
      if (dt != null && DateTime.now().difference(dt).inHours < 6) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final col = context.colors.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.trending_up, size: 13, color: col),
        const SizedBox(width: 3),
        Text('Gaining attention',
            style: AppText.caption
                .copyWith(color: col, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Reading-time pill to overlay on an image corner: clock + "N min".
class ReadingTimeBadge extends StatelessWidget {
  const ReadingTimeBadge({super.key, required this.minutes});
  final int minutes;

  @override
  Widget build(BuildContext context) {
    if (minutes <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(readTime(minutes),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Engagement footer: comment count + bookmark + animated like. Reused across
/// the richer card variants (mirrors the web article-card footer). Like/bookmark
/// pop with a spring scale on toggle (web LikeButton/BookmarkToggle parity).
class EngagementBar extends ConsumerWidget {
  const EngagementBar({super.key, required this.article});
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
      children: [
        if (article.commentCount > 0) ...[
          Icon(Icons.mode_comment_outlined, size: 15, color: c.textFaint),
          const SizedBox(width: 4),
          Text('${article.commentCount}',
              style: AppText.caption.copyWith(color: c.textFaint)),
        ],
        const Spacer(),
        if (canEngage) ...[
          _PopIcon(
            active: marked,
            icon: marked ? Icons.bookmark : Icons.bookmark_outline,
            color: marked ? c.brand : c.textFaint,
            onTap: () =>
                act(ref.read(engagementProvider.notifier).toggleBookmark),
          ),
          const SizedBox(width: AppSpace.lg),
          _PopIcon(
            active: liked,
            icon: liked ? Icons.favorite : Icons.favorite_outline,
            color: liked ? c.accent : c.textFaint,
            onTap: () => act(ref.read(engagementProvider.notifier).toggleLike),
            count: article.likeCount + (liked ? 1 : 0),
          ),
        ],
      ],
    );
  }
}

/// Icon button that springs to ~1.35 scale and back when its active state flips.
class _PopIcon extends StatefulWidget {
  const _PopIcon({
    required this.active,
    required this.icon,
    required this.color,
    required this.onTap,
    this.count,
  });
  final bool active;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? count;

  @override
  State<_PopIcon> createState() => _PopIconState();
}

class _PopIconState extends State<_PopIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant _PopIcon old) {
    super.didUpdateWidget(old);
    // Pop only when turning ON, like the web burst.
    if (widget.active && !old.active) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkResponse(
      onTap: widget.onTap,
      radius: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
          if (widget.count != null && widget.count! > 0) ...[
            const SizedBox(width: 4),
            Text('${widget.count}',
                style: AppText.caption.copyWith(color: c.textFaint)),
          ],
        ],
      ),
    );
  }
}
