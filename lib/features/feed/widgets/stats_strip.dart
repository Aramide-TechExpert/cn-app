import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/discover_controller.dart';
import '../../../data/feed_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

/// Thin, text-only "news content analysis" strip for the top of Home —
/// horizontally scrollable with a hairline between items, exactly like the News
/// Feed filter row: Stories · Breaking · High Impact · Clusters. Computed from
/// the loaded feed (+ the clusters count); no extra backend call.
class HomeStatsStrip extends ConsumerWidget {
  const HomeStatsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final items = ref.watch(feedControllerProvider).valueOrNull ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final clusters = ref.watch(clustersProvider).valueOrNull?.length;

    final breaking = items.where((a) => a.isBreaking).length;
    final high = items
        .where((a) => a.impact == 'High' || a.impact == 'Critical')
        .length;

    final stats = <Widget>[
      _Stat(value: items.length, label: 'Stories', color: c.brand),
      _Stat(value: breaking, label: 'Breaking', color: c.breaking),
      _Stat(value: high, label: 'High Impact', color: c.impact('High')),
      if (clusters != null)
        _Stat(value: clusters, label: 'Clusters', color: c.success),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs, bottom: AppSpace.sm),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            TextSpan(
                text: label,
                style: AppText.body.copyWith(
                    color: c.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500)),
          ])),
        ],
      ),
    );
  }
}
