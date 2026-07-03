import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/discover_controller.dart';
import '../../../data/feed_controller.dart';
import '../../../data/news_feed_controller.dart';
import '../../../models/widgets_data.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

String _fmtNum(double v) {
  final neg = v < 0;
  final abs = v.abs();
  final s = abs >= 1000 ? abs.round().toString() : abs.toStringAsFixed(2);
  // Thousands separators on the integer part.
  final dot = s.indexOf('.');
  final intPart = dot == -1 ? s : s.substring(0, dot);
  final frac = dot == -1 ? '' : s.substring(dot);
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return '${neg ? '-' : ''}$buf$frac';
}

/// Thin, text-only "news content analysis" strip for the top of Home —
/// horizontally scrollable with a hairline between items, exactly like the News
/// Feed filter row: Stories · Breaking · High Impact · Clusters. Computed from
/// the loaded feed (+ the clusters count); no extra backend call.
class HomeStatsStrip extends ConsumerWidget {
  const HomeStatsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final loaded = ref.watch(feedControllerProvider).valueOrNull ?? const [];
    if (loaded.isEmpty) return const SizedBox.shrink();
    // Real corpus stats (not just the loaded page) + live cluster/source counts.
    final corpus = ref.watch(statsProvider).valueOrNull;
    final clusters = ref.watch(clustersProvider).valueOrNull?.length;
    final sources = ref.watch(sourcesProvider).valueOrNull?.length;
    final breaking = corpus?.breaking ?? 0;
    final highImpact = (corpus?.high ?? 0) + (corpus?.critical ?? 0);

    // Only show tiles with a meaningful (non-zero) value, so nothing renders
    // as a dead "0" (the corpus is currently all-"medium", so Breaking/High
    // Impact stay hidden until the data has them).
    final stats = <Widget>[
      _Stat(
          value: corpus?.total ?? loaded.length,
          label: 'Stories',
          color: c.brand),
      if (sources != null && sources > 0)
        _Stat(value: sources, label: 'Sources', color: c.accent),
      if (clusters != null && clusters > 0)
        _Stat(value: clusters, label: 'Clusters', color: c.success),
      if (breaking > 0)
        _Stat(value: breaking, label: 'Breaking', color: c.breaking),
      if (highImpact > 0)
        _Stat(value: highImpact, label: 'High Impact', color: c.impact('High')),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 5),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          itemCount: stats.length,
          separatorBuilder: (_, __) => Center(
            child: Container(width: 1, height: 15, color: c.border),
          ),
          itemBuilder: (_, i) => stats[i],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: '$value ',
                style: AppText.body.copyWith(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            TextSpan(
                text: label,
                style: AppText.body.copyWith(
                    color: c.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ])),
        ],
      ),
    );
  }
}

/// Thin, text-only markets strip for Home — exchange rates + stocks/indices in
/// the same scrollable text style as the stats strip. Change % is coloured
/// green/red. Sits directly below [HomeStatsStrip]; hidden until data loads.
class HomeMarketsStrip extends ConsumerWidget {
  const HomeMarketsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final data = ref.watch(widgetsDataProvider).valueOrNull;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    final items = <Widget>[
      for (final f in data.fx) _Fx(rate: f),
      for (final q in [...data.stocks, ...data.markets]) _Quote(quote: q),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Deeper thin line tying the markets strip to the stats strip above it.
        Divider(
            height: 1,
            thickness: 1,
            color: Color.alphaBlend(
                c.textFaint.withValues(alpha: 0.5), c.border)),
        const SizedBox(height: 5),
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            itemCount: items.length,
            separatorBuilder: (_, __) => Center(
              child: Container(width: 1, height: 13, color: c.border),
            ),
            itemBuilder: (_, i) => items[i],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
      ],
    );
  }
}

class _Fx extends StatelessWidget {
  const _Fx({required this.rate});
  final FxRate rate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: 'USD/${rate.code} ',
              style: AppText.body.copyWith(
                  color: c.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          TextSpan(
              text: _fmtNum(rate.rate),
              style: AppText.body.copyWith(
                  color: c.text, fontSize: 14, fontWeight: FontWeight.w700)),
        ])),
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.quote});
  final MarketQuote quote;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final up = quote.changePct >= 0;
    final chgColor = up ? c.success : c.breaking;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '${quote.label} ',
              style: AppText.body.copyWith(
                  color: c.text, fontSize: 14, fontWeight: FontWeight.w700)),
          TextSpan(
              text: _fmtNum(quote.price),
              style: AppText.body.copyWith(
                  color: c.textSecondary, fontSize: 14)),
          TextSpan(
              text: '  ${up ? '▲' : '▼'}${quote.changePct.abs().toStringAsFixed(2)}%',
              style: AppText.body.copyWith(
                  color: chgColor, fontSize: 12, fontWeight: FontWeight.w700)),
        ])),
      ),
    );
  }
}
