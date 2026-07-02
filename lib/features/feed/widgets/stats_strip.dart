import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/discover_controller.dart';
import '../../../data/feed_controller.dart';
import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

/// Horizontal "news content analysis" strip for the top of Home — ports the web
/// dashboard StatsRow: Total Stories · Breaking · High Impact · Clusters, each
/// with a 24h sparkline. Swipeable like the News Feed filter row. Computed from
/// the loaded feed (+ the clusters count) — no extra backend call.
class HomeStatsStrip extends ConsumerWidget {
  const HomeStatsStrip({super.key});

  // 8 buckets of 3h across the last 24h (newest on the right), matching web.
  static List<int> _buckets(
      List<Article> items, bool Function(Article) keep) {
    final out = List<int>.filled(8, 0);
    final now = DateTime.now();
    for (final a in items) {
      if (!keep(a)) continue;
      final dt = DateTime.tryParse(a.publishedAt);
      if (dt == null) continue;
      final hoursAgo = now.difference(dt).inMinutes / 60.0;
      if (hoursAgo < 0 || hoursAgo > 24) continue;
      final b = ((24 - hoursAgo) / 3).floor().clamp(0, 7);
      out[b] += 1;
    }
    return out;
  }

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

    final tiles = <Widget>[
      _StatTile(
        label: 'Stories',
        value: items.length,
        icon: Icons.article_outlined,
        color: c.brand,
        spark: _buckets(items, (_) => true),
      ),
      _StatTile(
        label: 'Breaking',
        value: breaking,
        icon: Icons.bolt,
        color: c.breaking,
        spark: _buckets(items, (a) => a.isBreaking),
      ),
      _StatTile(
        label: 'High Impact',
        value: high,
        icon: Icons.trending_up,
        color: c.impact('High'),
        spark:
            _buckets(items, (a) => a.impact == 'High' || a.impact == 'Critical'),
      ),
      if (clusters != null)
        _StatTile(
          label: 'Clusters',
          value: clusters,
          icon: Icons.layers_outlined,
          color: c.success,
          spark: _buckets(items, (_) => true).map((v) => (v / 3).round()).toList(),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm, bottom: AppSpace.md),
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          itemCount: tiles.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
          itemBuilder: (_, i) => tiles[i],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.spark,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final List<int> spark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 156,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$value',
                        style: AppText.title.copyWith(
                            color: c.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 22,
            width: double.infinity,
            child: CustomPaint(painter: _SparklinePainter(spark, color)),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.data, this.color);
  final List<int> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final range = maxV <= 0 ? 1.0 : maxV.toDouble();
    final dx = size.width / (data.length - 1);
    final pts = <Offset>[
      for (var i = 0; i < data.length; i++)
        Offset(i * dx, size.height - (data[i] / range) * size.height),
    ];
    // Soft fill under the line.
    final fill = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      fill.lineTo(p.dx, p.dy);
    }
    fill.lineTo(pts.last.dx, size.height);
    fill.close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    // Line.
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}
