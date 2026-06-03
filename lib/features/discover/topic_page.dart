import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/discover_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../feed/widgets/article_card.dart';

class TopicPage extends ConsumerWidget {
  const TopicPage({super.key, required this.slug, this.name});
  final String slug;
  final String? name;

  String get _title {
    final raw = (name != null && name!.isNotEmpty)
        ? name!
        : slug.replaceAll('-', ' ');
    return raw
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final feed = ref.watch(topicFeedProvider(slug));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(_title)),
      body: feed.when(
        loading: () => Center(child: CircularProgressIndicator(color: c.brand)),
        error: (_, __) => Center(
          child: Text("Couldn't load this topic.",
              style: AppText.body.copyWith(color: c.textSecondary)),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Text('No stories in this topic yet.',
                    style: AppText.body.copyWith(color: c.textSecondary)),
              )
            : RefreshIndicator(
                color: c.brand,
                onRefresh: () async => ref.invalidate(topicFeedProvider(slug)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.x3),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpace.lg),
                  itemBuilder: (_, i) => ArticleCard(article: items[i]),
                ),
              ),
      ),
    );
  }
}
