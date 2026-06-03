import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/discover_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../feed/widgets/article_card.dart';

class ClusterDetailPage extends ConsumerWidget {
  const ClusterDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final detail = ref.watch(clusterDetailProvider(id));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Full coverage')),
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.x3),
            itemCount: d.articles.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpace.lg),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FULL COVERAGE',
                        style: AppText.micro
                            .copyWith(color: c.brand, letterSpacing: 1)),
                    const SizedBox(height: AppSpace.sm),
                    Text(d.cluster.title,
                        style: AppText.title.copyWith(color: c.text)),
                    if (d.cluster.summary.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(d.cluster.summary,
                          style: AppText.body
                              .copyWith(color: c.textSecondary)),
                    ],
                  ],
                );
              }
              return ArticleCard(article: d.articles[i - 1]);
            },
          );
        },
      ),
    );
  }
}
