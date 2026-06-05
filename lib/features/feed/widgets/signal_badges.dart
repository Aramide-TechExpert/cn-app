import 'package:flutter/material.dart';

import '../../../data/source_signals.dart';
import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

/// A small pill used by all the signal badges.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg, this.icon});
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

class ImpactBadge extends StatelessWidget {
  const ImpactBadge({super.key, required this.impact});
  final String impact;
  @override
  Widget build(BuildContext context) {
    final col = context.colors.impact(impact);
    return _Pill(
      label: '${impact.toUpperCase()} IMPACT',
      bg: col.withValues(alpha: 0.16),
      fg: col,
    );
  }
}

class BiasBadge extends StatelessWidget {
  const BiasBadge({super.key, required this.source});
  final String source;
  @override
  Widget build(BuildContext context) {
    final b = biasFor(source);
    if (b == Bias.unknown) return const SizedBox.shrink();
    const blue = Color(0xFF2563EB);
    const emerald = Color(0xFF30A46C);
    const red = Color(0xFFDC2626);
    final (Color bg, Color fg) = switch (b) {
      Bias.left => (blue, Colors.white),
      Bias.leanLeft => (blue.withValues(alpha: 0.16), blue),
      Bias.center => (emerald.withValues(alpha: 0.16), emerald),
      Bias.leanRight => (red.withValues(alpha: 0.16), red),
      Bias.right => (red, Colors.white),
      Bias.unknown => (Colors.transparent, Colors.transparent),
    };
    return _Pill(label: biasLabel(b), bg: bg, fg: fg);
  }
}

class TrustPill extends StatelessWidget {
  const TrustPill({super.key, required this.score});
  final int? score;
  @override
  Widget build(BuildContext context) {
    if (score == null || score == 0) return const SizedBox.shrink();
    const green = Color(0xFF30A46C);
    return _Pill(
      label: '$score%',
      bg: green.withValues(alpha: 0.16),
      fg: green,
      icon: Icons.verified_outlined,
    );
  }
}

class FactCheckBadge extends StatelessWidget {
  const FactCheckBadge({super.key, required this.source});
  final String source;
  @override
  Widget build(BuildContext context) {
    if (!isFactChecked(source)) return const SizedBox.shrink();
    const green = Color(0xFF30A46C);
    return _Pill(
      label: 'Fact-check',
      bg: green.withValues(alpha: 0.16),
      fg: green,
      icon: Icons.fact_check_outlined,
    );
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Pill(
      label: categoryLabel(slug).toUpperCase(),
      bg: c.bgInset,
      fg: c.textSecondary,
    );
  }
}

/// The full trust-signal row shown on cards: category · impact · bias · trust ·
/// fact-check. Mirrors the web card badge cluster.
class SignalRow extends StatelessWidget {
  const SignalRow({super.key, required this.article, this.spacing = 6});
  final Article article;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (article.categories.isNotEmpty) CategoryChip(slug: article.categories.first),
        ImpactBadge(impact: article.impact),
        BiasBadge(source: article.source),
        TrustPill(score: article.trustScore),
        FactCheckBadge(source: article.source),
      ],
    );
  }
}
