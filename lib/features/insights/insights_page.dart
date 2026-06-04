import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/discover_controller.dart';
import '../../models/stats.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final stats = ref.watch(statsProvider);
    final trending = ref.watch(trendingProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(statsProvider);
          ref.invalidate(trendingProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.x3),
          children: [
            stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpace.x3),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
              error: (_, __) => Text("Couldn't load insights.",
                  style: AppText.body.copyWith(color: c.textSecondary)),
              data: (s) => _StatsBody(stats: s),
            ),
            const SizedBox(height: AppSpace.xl),
            Text('Trending topics',
                style: AppText.headline.copyWith(color: c.text)),
            const SizedBox(height: AppSpace.md),
            trending.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (topics) => Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: topics
                    .take(12)
                    .map((t) => Chip(
                          label: Text('${t.topic} · ${t.count}'),
                          backgroundColor: c.bgInset,
                          side: BorderSide(color: c.border),
                          labelStyle: AppText.caption.copyWith(color: c.text),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});
  final CorpusStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = stats.total == 0 ? 1 : stats.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: 'Stories tracked', value: '${stats.total}')),
          const SizedBox(width: AppSpace.md),
          Expanded(
              child: _StatTile(
                  label: 'Breaking now',
                  value: '${stats.breaking}',
                  accent: c.breaking)),
        ]),
        const SizedBox(height: AppSpace.xl),
        Text('Impact breakdown',
            style: AppText.headline.copyWith(color: c.text)),
        const SizedBox(height: AppSpace.md),
        _Bar(label: 'Critical', count: stats.critical, total: total, color: c.critical),
        _Bar(label: 'High', count: stats.high, total: total, color: c.high),
        _Bar(label: 'Medium', count: stats.medium, total: total, color: c.medium),
        _Bar(label: 'Low', count: stats.low, total: total, color: c.low),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.accent});
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppText.display.copyWith(color: accent ?? c.text)),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final frac = (count / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: AppText.callout.copyWith(color: c.text))),
            Text('$count',
                style: AppText.callout.copyWith(color: c.textSecondary)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Stack(
              children: [
                Container(height: 8, color: c.bgInset),
                FractionallySizedBox(
                  widthFactor: frac == 0 ? 0.02 : frac,
                  child: Container(height: 8, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
