import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/discover_controller.dart';
import '../../models/cluster.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../discover/markets_weather_section.dart';
import '../feed/widgets/rail_card.dart';
import '../shell/app_drawer.dart';

/// Clusters — multi-source "full coverage" stories, plus trending topics, topic
/// rails and market/weather widgets. (Replaces the old Watch tab.)
class ClustersPage extends ConsumerWidget {
  const ClustersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final clusters = ref.watch(clustersProvider);
    final trending = ref.watch(trendingProvider);
    final topTopics =
        trending.valueOrNull?.take(3).toList() ?? const <TrendingTopic>[];

    return Scaffold(
      backgroundColor: c.bg,
      drawer: const AppDrawer(),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(clustersProvider);
          ref.invalidate(trendingProvider);
          ref.invalidate(widgetsDataProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar.large(
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.menu, color: c.text),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              title:
                  Text('Clusters', style: AppText.title.copyWith(color: c.text)),
            ),

            // Trending topics.
            const SliverToBoxAdapter(child: _SectionHeader('Trending')),
            SliverToBoxAdapter(
              child: trending.when(
                loading: () => const _InlineLoader(),
                error: (_, __) => const _InlineNote('Trending unavailable.'),
                data: (topics) => topics.isEmpty
                    ? const _InlineNote('Nothing trending yet.')
                    : SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.lg),
                          itemCount: topics.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppSpace.sm),
                          itemBuilder: (_, i) => _TopicChip(topic: topics[i]),
                        ),
                      ),
              ),
            ),

            // Topic rails.
            ...topTopics.map(
              (t) => SliverToBoxAdapter(child: _TopicSection(topic: t)),
            ),

            // Markets + weather.
            const SliverToBoxAdapter(child: MarketsWeatherSection()),

            // Full coverage clusters.
            const SliverToBoxAdapter(child: _SectionHeader('Full coverage')),
            clusters.when(
              loading: () => const SliverToBoxAdapter(child: _InlineLoader()),
              error: (_, __) => const SliverToBoxAdapter(
                  child: _InlineNote("Couldn't load clusters.")),
              data: (list) => list.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _InlineNote(
                          'No multi-source stories are clustered right now.'))
                  : SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, thickness: 1, color: c.border),
                      itemBuilder: (_, i) => _ClusterCard(cluster: list[i]),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x2)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
      child: Text(label,
          style: AppText.headline.copyWith(color: context.colors.text)),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
}

class _InlineNote extends StatelessWidget {
  const _InlineNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Text(text,
          style: AppText.body.copyWith(color: context.colors.textSecondary)),
    );
  }
}

class _TopicSection extends ConsumerWidget {
  const _TopicSection({required this.topic});
  final TrendingTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final articles = ref.watch(topicFeedProvider(topic.slug)).valueOrNull;
    if (articles == null) return const SizedBox.shrink();
    final items = articles.where((a) => a.hasImage).take(8).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final name = topic.topic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.lg, AppSpace.sm, AppSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Text(name,
                    style: AppText.headline.copyWith(color: c.text)),
              ),
              TextButton(
                onPressed: () => context.push(
                    '/topic/${topic.slug}?name=${Uri.encodeComponent(name)}'),
                child: Text('See all',
                    style: AppText.callout.copyWith(color: c.brand)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.lg),
            itemBuilder: (_, i) => RailCard(article: items[i]),
          ),
        ),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.topic});
  final TrendingTopic topic;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ActionChip(
      label: Text(topic.topic),
      labelStyle: AppText.callout.copyWith(color: c.text),
      backgroundColor: c.bgInset,
      side: BorderSide(color: c.border),
      shape: const RoundedRectangleBorder(),
      onPressed: () => context.push(
          '/topic/${topic.slug}?name=${Uri.encodeComponent(topic.topic)}'),
    );
  }
}

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({required this.cluster});
  final StoryCluster cluster;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => context.push('/cluster/${cluster.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.lg),
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
    );
  }
}
