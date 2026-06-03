import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/discover_controller.dart';
import '../../models/cluster.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final clusters = ref.watch(clustersProvider);
    final trending = ref.watch(trendingProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.brand,
          onRefresh: () async {
            ref.invalidate(clustersProvider);
            ref.invalidate(trendingProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.x3),
            children: [
              Text('CLUSTEZ',
                  style: AppText.micro
                      .copyWith(color: c.brand, letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text('Discover', style: AppText.display.copyWith(color: c.text)),
              const SizedBox(height: AppSpace.lg),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: () => context.push('/search'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg, vertical: AppSpace.md),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.search, size: 20, color: c.textFaint),
                    const SizedBox(width: AppSpace.sm),
                    Text('Search news, topics, sources',
                        style: AppText.body.copyWith(color: c.textFaint)),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpace.xl),

              // Trending
              Text('Trending', style: AppText.headline.copyWith(color: c.text)),
              const SizedBox(height: AppSpace.md),
              trending.when(
                loading: () => _loader(c.brand),
                error: (_, __) => _muted(context, 'Trending unavailable.'),
                data: (topics) => topics.isEmpty
                    ? _muted(context, 'Nothing trending yet.')
                    : SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: topics.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppSpace.sm),
                          itemBuilder: (_, i) => _TopicChip(topic: topics[i]),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpace.xl),

              // Full coverage
              Text('Full coverage',
                  style: AppText.headline.copyWith(color: c.text)),
              const SizedBox(height: AppSpace.md),
              clusters.when(
                loading: () => _loader(c.brand),
                error: (_, __) => _muted(context, "Couldn't load clusters."),
                data: (list) => list.isEmpty
                    ? _EmptyCoverage()
                    : Column(
                        children: [
                          for (final cl in list) ...[
                            _ClusterCard(cluster: cl),
                            const SizedBox(height: AppSpace.md),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loader(Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Center(child: CircularProgressIndicator(color: color)),
      );

  Widget _muted(BuildContext context, String text) => Text(
        text,
        style: AppText.body.copyWith(color: context.colors.textSecondary),
      );
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.topic});
  final TrendingTopic topic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: () => context.push(
          '/topic/${topic.slug}?name=${Uri.encodeComponent(topic.topic)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          color: c.bgInset,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Text(topic.topic, style: AppText.callout.copyWith(color: c.text)),
          const SizedBox(width: 6),
          Text('${topic.count}',
              style: AppText.caption.copyWith(color: c.textFaint)),
        ]),
      ),
    );
  }
}

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({required this.cluster});
  final StoryCluster cluster;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => context.push('/cluster/${cluster.id}'),
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
                Icon(Icons.account_tree_outlined, size: 14, color: c.brand),
                const SizedBox(width: 5),
                Text('FULL COVERAGE',
                    style: AppText.micro.copyWith(color: c.brand)),
              ]),
              const SizedBox(height: AppSpace.sm),
              Text(cluster.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headline.copyWith(color: c.text)),
              if (cluster.summary.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                Text(cluster.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(color: c.textSecondary)),
              ],
              const SizedBox(height: AppSpace.md),
              Text(
                '${cluster.sourceCount} ${cluster.sourceCount == 1 ? "source" : "sources"} · updated ${timeAgo(cluster.lastUpdated)}',
                style: AppText.caption.copyWith(color: c.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCoverage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.x2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: c.border),
      ),
      child: Text(
        'No multi-source stories are clustered right now. Check back as coverage develops.',
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(color: c.textSecondary),
      ),
    );
  }
}
