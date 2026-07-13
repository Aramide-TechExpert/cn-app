import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/auth_controller.dart';
import '../../data/engagement_controller.dart';
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/link_out.dart';
import 'widgets/inline_video.dart';

/// Full-screen, TikTok-style vertical reel of license-safe videos. Opens from a
/// Shorts card at the tapped index; swipe up/down moves to the next clip. Each
/// page autoplays (muted) when it scrolls into view; tap toggles play/pause.
/// A right-side rail carries Like · Save · Share. System chrome is dark.
class VideoReelPage extends ConsumerStatefulWidget {
  const VideoReelPage({super.key, required this.videos, this.initialIndex = 0});
  final List<Article> videos;
  final int initialIndex;

  @override
  ConsumerState<VideoReelPage> createState() => _VideoReelPageState();
}

class _VideoReelPageState extends ConsumerState<VideoReelPage> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  // One shared mute state for the whole reel — starts muted (autoplay rule),
  // and the single prominent button below flips every page at once.
  final ValueNotifier<bool> _muted = ValueNotifier(true);

  @override
  void dispose() {
    _controller.dispose();
    _muted.dispose();
    super.dispose();
  }

  void _act(Article v, Future<void> Function(String) toggle) {
    if (ref.read(currentUserProvider) == null) {
      context.push('/sign-in');
      return;
    }
    final dbId = v.dbId;
    if (dbId == null) return;
    HapticFeedback.selectionClick();
    toggle(dbId);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final eng = ref.watch(engagementProvider).valueOrNull;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark system chrome on the reel — light status icons + black nav/footer.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            itemBuilder: (context, i) {
              final v = widget.videos[i];
              final dbId = v.dbId;
              final liked = dbId != null && (eng?.liked.contains(dbId) ?? false);
              final marked =
                  dbId != null && (eng?.bookmarked.contains(dbId) ?? false);
              return Stack(fit: StackFit.expand, children: [
                Center(
                  child: InlineVideo(
                    article: v,
                    aspectRatio: size.width / size.height,
                    fit: BoxFit.contain,
                    muteController: _muted,
                    showMuteButton: false,
                    // Reels loop the 4s preview forever; the caption's
                    // read-on-source link carries to the full video.
                    previewLoop: const Duration(seconds: 4),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                          stops: [0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Right-side action rail: Like · Save · Share.
                Positioned(
                  right: AppSpace.sm,
                  bottom: 110,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ReelAction(
                        icon: liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? const Color(0xFFFF5A5F) : Colors.white,
                        label: '${v.likeCount + (liked ? 1 : 0)}',
                        onTap: () => _act(
                            v, ref.read(engagementProvider.notifier).toggleLike),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _ReelAction(
                        icon: marked ? Icons.bookmark : Icons.bookmark_border,
                        color: marked ? context.colors.brandPressed : Colors.white,
                        label: 'Save',
                        onTap: () => _act(v,
                            ref.read(engagementProvider.notifier).toggleBookmark),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _ReelAction(
                        icon: Icons.ios_share,
                        color: Colors.white,
                        label: 'Share',
                        onTap: () =>
                            Share.share('${v.title}\n${v.sourceUrl ?? ''}'),
                      ),
                    ],
                  ),
                ),
                // Bottom caption: source · title · excerpt · read-on-source.
                Positioned(
                  left: AppSpace.lg,
                  right: 84, // clear of the action rail
                  bottom: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(v.source,
                          style:
                              AppText.caption.copyWith(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(v.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.headline
                              .copyWith(color: Colors.white, fontSize: 17)),
                      if (v.blurb != null) ...[
                        const SizedBox(height: 6),
                        Text(v.blurb!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.82))),
                      ],
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => openArticle(v.sourceUrl, track: v),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.open_in_new,
                              size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Read on ${v.source}',
                              style: AppText.caption
                                  .copyWith(color: Colors.white)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ]);
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Prominent, always-in-the-same-spot sound toggle — large tap target so
          // it's easy to find/press (the old tiny corner speaker was the gripe).
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding:
                    const EdgeInsets.only(top: AppSpace.xs, right: AppSpace.sm),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _muted,
                  builder: (_, muted, __) => Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _muted.value = !_muted.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(muted ? Icons.volume_off : Icons.volume_up,
                              size: 20, color: Colors.white),
                          const SizedBox(width: 7),
                          Text(muted ? 'Tap for sound' : 'Sound on',
                              style: AppText.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// One icon + label in the reel's right-side action rail.
class _ReelAction extends StatelessWidget {
  const _ReelAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 30, shadows: const [
            Shadow(color: Colors.black54, blurRadius: 6),
          ]),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
        ],
      ),
    );
  }
}
