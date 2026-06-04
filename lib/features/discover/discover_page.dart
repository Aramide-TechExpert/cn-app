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
          ref.invalidate(briefingProvider);
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

            // Search (simple tappable field → full search screen).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
                child: InkWell(
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
              ),
            ),

            // Daily briefing entry.
            SliverToBoxAdapter(child: _BriefingCard()),

            // Trending.
            const SliverToBoxAdapter(child: _SectionHeader('Trending')),
            SliverToBoxAdapter(
              child: trending.when(
                loading: () => const _InlineLoader(),
                error: (_, __) => const _InlineNote('Trending unavailable.'),
                data: (topics) => topics.isEmpty
                    ? const _InlineNote('Nothing trending yet.')
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

            // Full coverage.
            const SliverToBoxAdapter(child: _SectionHeader('Full coverage')),
            clusters.when(
              loading: () => const SliverToBoxAdapter(child: _InlineLoader()),
              error: (_, __) => const SliverToBoxAdapter(
                  child: _InlineNote("Couldn't load clusters.")),
              data: (list) => list.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _InlineNote(
                          'No multi-source stories are clustered right now.'))
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
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x2)),
          ],
        ),
      ),
    );
  }
}

class _BriefingCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final b = ref.watch(briefingProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
      child: Material(
        color: c.brandSoft,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () => context.push('/briefing'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(children: [
              Icon(Icons.newspaper, color: c.brand),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Briefing',
                        style: AppText.bodyStrong.copyWith(color: c.text)),
                    Text(
                        b?.title.isNotEmpty == true
                            ? b!.title
                            : "Today's top stories, in brief",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.caption.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.textFaint),
            ]),
          ),
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
