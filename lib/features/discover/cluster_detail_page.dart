import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/discover_controller.dart';
import '../../data/source_signals.dart';
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/interleave.dart' show throttleVideoCards;
import '../feed/widgets/card_extras.dart' show FadeSlideIn;
import '../feed/widgets/feed_pattern.dart';

class ClusterDetailPage extends ConsumerWidget {
  const ClusterDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final detail = ref.watch(clusterDetailProvider(id));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Full coverage'),
      ),
      body: detail.when(
        loading: () => Center(child: CircularProgressIndicator(color: c.brand)),
        error: (_, __) => Center(
          child: Text("Couldn't load this story.",
              style: AppText.body.copyWith(color: c.textSecondary)),
        ),
        data: (d) {
          if (d == null) {
            return Center(
              child: Text('Story not found.',
                  style: AppText.body.copyWith(color: c.textSecondary)),
            );
          }
          // Chronological order for the timeline.
          final timeline = [...d.articles]
            ..sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
          final whyItMatters = d.articles
              .map((a) => a.whyItMatters)
              .firstWhere((w) => w != null && w.isNotEmpty, orElse: () => null);

          // Horizontal padding lives on the HEADER block only — the story
          // list below is the shared feed template, whose cards manage their
          // own gutters (full-bleed variants must reach the screen edges).
          final videoOk = throttleVideoCards(timeline);
          final rows = planFeedRows(timeline);
          return ListView(
            padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.x3),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Text('FULL COVERAGE',
                  style:
                      AppText.micro.copyWith(color: c.brand, letterSpacing: 1)),
              const SizedBox(height: AppSpace.sm),
              Text(d.cluster.title,
                  style: AppText.title.copyWith(color: c.text)),
              if (d.cluster.summary.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                Text(d.cluster.summary,
                    style: AppText.body.copyWith(color: c.textSecondary)),
              ],
              const SizedBox(height: AppSpace.lg),
              _DiversityMeter(articles: d.articles),
              if (whyItMatters != null) ...[
                const SizedBox(height: AppSpace.lg),
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
                      Text(whyItMatters,
                          style: AppText.body.copyWith(color: c.text)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              Text('How it developed',
                  style: AppText.headline.copyWith(color: c.text, fontSize: 16)),
              const SizedBox(height: AppSpace.sm),
                  ],
                ),
              ),
              // The FEED tab's template, enforced: same shared newsFeedCard
              // cycle / pairs / bands as /discover and the digest landing —
              // never a bespoke card style on a notification landing.
              for (var i = 0; i < rows.length; i++)
                FadeSlideIn(
                  key: ValueKey(rows[i].first.id),
                  child: rows[i].length == 2
                      ? feedPairRow(context, rows[i])
                      : newsFeedCard(i, rows[i].first,
                          flushBelow: newsFeedFlushBelow(rows, i),
                          videoOk: videoOk.contains(rows[i].first.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Source-diversity meter — distinct sources + a Left/Center/Right bias bar,
/// using the same source→bias map as the cards.
class _DiversityMeter extends StatelessWidget {
  const _DiversityMeter({required this.articles});
  final List<Article> articles;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sources = {for (final a in articles) a.source};
    var left = 0, center = 0, right = 0, unrated = 0;
    for (final s in sources) {
      final b = biasFor(s);
      if (b == Bias.left || b == Bias.leanLeft) {
        left++;
      } else if (b == Bias.center) {
        center++;
      } else if (b == Bias.right || b == Bias.leanRight) {
        right++;
      } else {
        unrated++;
      }
    }
    const blue = Color(0xFF2563EB);
    const green = Color(0xFF30A46C);
    const red = Color(0xFFDC2626);

    Widget seg(int n, Color color) =>
        n == 0 ? const SizedBox.shrink() : Expanded(flex: n, child: Container(height: 8, color: color));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.balance, size: 15, color: c.textSecondary),
          const SizedBox(width: 6),
          Text('${sources.length} ${sources.length == 1 ? "source" : "sources"} · coverage spread',
              style: AppText.caption
                  .copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: AppSpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Row(children: [
            seg(left, blue),
            seg(center, green),
            seg(right, red),
            seg(unrated, c.border),
          ]),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: AppSpace.md, children: [
          if (left > 0) _legend(blue, 'Left $left'),
          if (center > 0) _legend(green, 'Center $center'),
          if (right > 0) _legend(red, 'Right $right'),
          if (unrated > 0) _legend(c.border, 'Unrated $unrated'),
        ]),
      ],
    );
  }

  Widget _legend(Color color, String label) => Builder(builder: (context) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppText.caption
                  .copyWith(color: context.colors.textFaint)),
        ]);
      });
}
