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
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(clustersProvider);
          ref.invalidate(trendingProvider);
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
              title: Text('Discover',
                  style: AppText.title.copyWith(color: c.text)),
            ),

            // Material 3 search bar (read-only → full search screen).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
                child: SearchBar(
                  hintText: 'Search news, topics, sources',
                  leading: Icon(Icons.search, color: c.textFaint),
                  backgroundColor: WidgetStatePropertyAll(c.bgInset),
                  elevation: const WidgetStatePropertyAll(0),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      side: BorderSide(color: c.border),
                    ),
                  ),
                  onTap: () => context.push('/search'),
                  onChanged: (_) => context.push('/search'),
                ),
              ),
            ),

            // Trending chips.
            const SliverToBoxAdapter(child: _SectionHeader(label: 'Trending')),
            SliverToBoxAdapter(
              child: trending.when(
                loading: () => const _InlineLoader(),
                error: (_, __) => const SizedBox.shrink(),
                data: (topics) => topics.isEmpty
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: 44,
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

            // Full coverage clusters.
            const SliverToBoxAdapter(
                child: _SectionHeader(label: 'Full coverage')),
            clusters.when(
              loading: () => const SliverToBoxAdapter(child: _InlineLoader()),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (list) => list.isEmpty
                  ? SliverToBoxAdapter(child: _EmptyCoverage())
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, 0, AppSpace.lg, AppSpace.x3),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpace.md),
                        itemBuilder: (_, i) => _ClusterCard(cluster: list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
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
    return Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, 0, AppSpace.lg, AppSpace.x3),
      child: Container(
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
      ),
    );
  }
}
