import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/auth_controller.dart';
import '../../data/engagement_controller.dart';
import '../../data/feed_controller.dart';
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../../utils/link_out.dart';
import 'widgets/signal_badges.dart';

/// Stack feed — full-screen vertical swiper (web /feed/stack). One story per
/// page, full-bleed, with inline actions. Swipe up for the next.
class StackFeedPage extends ConsumerStatefulWidget {
  const StackFeedPage({super.key});

  @override
  ConsumerState<StackFeedPage> createState() => _StackFeedPageState();
}

class _StackFeedPageState extends ConsumerState<StackFeedPage> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedControllerProvider);
    final ctrl = ref.read(feedControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: feed.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(
          child: Text('Could not load.',
              style: AppText.body.copyWith(color: Colors.white70)),
        ),
        data: (items) {
          final stack = items.where((a) => a.hasImage).toList();
          if (stack.isEmpty) {
            return const Center(
              child: Text('Nothing to show',
                  style: TextStyle(color: Colors.white70)),
            );
          }
          return Stack(children: [
            PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: stack.length,
              onPageChanged: (i) {
                if (i >= stack.length - 3) ctrl.loadMore();
              },
              itemBuilder: (_, i) => _StackCard(article: stack[i]),
            ),
            // Close affordance back to Home.
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _StackCard extends ConsumerWidget {
  const _StackCard({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final dbId = article.dbId;
    final eng = ref.watch(engagementProvider).valueOrNull;
    final liked = dbId != null && (eng?.liked.contains(dbId) ?? false);
    final marked = dbId != null && (eng?.bookmarked.contains(dbId) ?? false);

    void act(Future<void> Function(String) toggle) {
      if (dbId == null) return;
      if (ref.read(currentUserProvider) == null) {
        context.push('/sign-in');
        return;
      }
      HapticFeedback.selectionClick();
      toggle(dbId);
    }

    return GestureDetector(
      onTap: () => openArticle(article.sourceUrl, track: article),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: article.image,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.black),
            errorWidget: (_, __, ___) => Container(color: Colors.black),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent, Colors.black],
                stops: [0.0, 0.4, 0.92],
              ),
            ),
          ),
          if (article.isBreaking)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                color: c.breaking,
                child: const Text('BREAKING',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
              ),
            ),
          Positioned(
            left: AppSpace.lg,
            right: AppSpace.lg,
            bottom: AppSpace.x3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SignalRow(article: article),
                const SizedBox(height: AppSpace.sm),
                Text(article.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title.copyWith(color: Colors.white)),
                if (article.blurb != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(article.blurb!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body
                          .copyWith(color: Colors.white.withValues(alpha: 0.85))),
                ],
                const SizedBox(height: AppSpace.md),
                Row(children: [
                  SourceFavicon(
                      url: article.sourceUrl, source: article.source, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        '${article.source} · ${timeAgo(article.publishedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption
                            .copyWith(color: Colors.white.withValues(alpha: 0.85))),
                  ),
                ]),
                const SizedBox(height: AppSpace.md),
                Row(children: [
                  _StackBtn(
                    icon: Icons.open_in_new,
                    label: 'Read',
                    onTap: () => openArticle(article.sourceUrl, track: article),
                  ),
                  const SizedBox(width: AppSpace.lg),
                  if (dbId != null) ...[
                    _StackIcon(
                      icon: marked ? Icons.bookmark : Icons.bookmark_outline,
                      active: marked,
                      onTap: () => act(
                          ref.read(engagementProvider.notifier).toggleBookmark),
                    ),
                    const SizedBox(width: AppSpace.lg),
                    _StackIcon(
                      icon: liked ? Icons.favorite : Icons.favorite_outline,
                      active: liked,
                      onTap: () => act(
                          ref.read(engagementProvider.notifier).toggleLike),
                    ),
                    const SizedBox(width: AppSpace.lg),
                  ],
                  _StackIcon(
                    icon: Icons.ios_share,
                    active: false,
                    onTap: () {
                      final u = article.sourceUrl;
                      if (u != null && u.isNotEmpty) {
                        Share.share('${article.title}\n$u');
                      }
                    },
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StackBtn extends StatelessWidget {
  const _StackBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.brand,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: c.onBrand),
            const SizedBox(width: 6),
            Text(label,
                style: AppText.callout
                    .copyWith(color: c.onBrand, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _StackIcon extends StatelessWidget {
  const _StackIcon(
      {required this.icon, required this.active, required this.onTap});
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Icon(icon,
          size: 26, color: active ? c.accent : Colors.white),
    );
  }
}
