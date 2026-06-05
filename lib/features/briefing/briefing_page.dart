import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/discover_controller.dart';
import '../../models/briefing.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../shell/app_drawer.dart';

/// Daily Briefing tab — today's top stories in brief. (Replaces the Saved tab.)
class BriefingPage extends ConsumerWidget {
  const BriefingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final briefing = ref.watch(briefingProvider);

    return Scaffold(
      backgroundColor: c.bg,
      drawer: const AppDrawer(),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.invalidate(briefingProvider),
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
                  Text('Briefing', style: AppText.title.copyWith(color: c.text)),
            ),
            briefing.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
              error: (_, __) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text("Couldn't load the briefing.",
                      style: AppText.body.copyWith(color: c.textSecondary)),
                ),
              ),
              data: (b) {
                if (b == null) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.x2),
                        child: Text(
                          "Today's briefing isn't ready yet. Check back later.",
                          textAlign: TextAlign.center,
                          style:
                              AppText.body.copyWith(color: c.textSecondary),
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, 0, AppSpace.lg, AppSpace.x3),
                  sliver: SliverList.list(children: [
                    if (b.date.isNotEmpty)
                      Text(b.date.toUpperCase(),
                          style: AppText.micro
                              .copyWith(color: c.brand, letterSpacing: 1.2)),
                    const SizedBox(height: AppSpace.xs),
                    Text(b.title, style: AppText.display.copyWith(color: c.text)),
                    if (b.summary.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.md),
                      Text(b.summary,
                          style: AppText.body
                              .copyWith(color: c.textSecondary, height: 1.5)),
                    ],
                    if (b.topStories.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xl),
                      Text('Top stories',
                          style: AppText.headline.copyWith(color: c.text)),
                      const SizedBox(height: AppSpace.md),
                      ...b.topStories.map((s) => _Story(story: s)),
                    ],
                    if (b.trendingTopics.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xl),
                      Text('Trending topics',
                          style: AppText.headline.copyWith(color: c.text)),
                      const SizedBox(height: AppSpace.md),
                      Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: b.trendingTopics
                            .map((t) => Chip(
                                  label: Text(t),
                                  backgroundColor: c.bgInset,
                                  side: BorderSide(color: c.border),
                                  shape: const RoundedRectangleBorder(),
                                  labelStyle:
                                      AppText.callout.copyWith(color: c.text),
                                ))
                            .toList(),
                      ),
                    ],
                    if (b.marketSignals.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xl),
                      Text('Market signals',
                          style: AppText.headline.copyWith(color: c.text)),
                      const SizedBox(height: AppSpace.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        color: c.bgInset,
                        child: Text(b.marketSignals,
                            style: AppText.body
                                .copyWith(color: c.textSecondary, height: 1.5)),
                      ),
                    ],
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({required this.story});
  final BriefingTopStory story;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${story.number}',
              style: AppText.title.copyWith(color: c.brand)),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(story.title,
                    style: AppText.bodyStrong.copyWith(color: c.text)),
                if (story.summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(story.summary,
                      style: AppText.body.copyWith(color: c.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
