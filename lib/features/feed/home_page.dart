import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/feed_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'widgets/article_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 600) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final feed = ref.watch(feedControllerProvider);
    final controller = ref.read(feedControllerProvider.notifier);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: feed.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: c.brand),
          ),
          error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: controller.refresh,
          ),
          data: (items) => RefreshIndicator(
            color: c.brand,
            onRefresh: controller.refresh,
            child: ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.x3),
              itemCount: items.length + 2, // header + footer
              separatorBuilder: (_, i) =>
                  const SizedBox(height: AppSpace.lg),
              itemBuilder: (context, i) {
                if (i == 0) return const _Header();
                if (i == items.length + 1) {
                  return controller.hasMore
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpace.xl),
                          child: Center(
                            child: CircularProgressIndicator(color: c.brand),
                          ),
                        )
                      : const SizedBox.shrink();
                }
                return ArticleCard(article: items[i - 1]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CLUSTEZ',
            style: AppText.micro
                .copyWith(color: c.brand, letterSpacing: 1.2)),
        const SizedBox(height: 2),
        Text('Top Stories', style: AppText.display.copyWith(color: c.text)),
        const SizedBox(height: 2),
        Text('The news that matters, in context.',
            style: AppText.callout.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpace.xs),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Couldn't load the feed",
                textAlign: TextAlign.center,
                style: AppText.headline.copyWith(color: c.text)),
            const SizedBox(height: AppSpace.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: c.textSecondary)),
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: c.brand),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
