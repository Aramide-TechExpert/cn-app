import 'package:flutter/material.dart';

import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/link_out.dart';
import 'widgets/inline_video.dart';

/// Full-screen, TikTok-style vertical reel of license-safe videos. Opens from a
/// Shorts card at the tapped index; swipe up/down moves to the next clip. Each
/// page autoplays (muted) when it scrolls into view; tap toggles play/pause.
class VideoReelPage extends StatefulWidget {
  const VideoReelPage({super.key, required this.videos, this.initialIndex = 0});
  final List<Article> videos;
  final int initialIndex;

  @override
  State<VideoReelPage> createState() => _VideoReelPageState();
}

class _VideoReelPageState extends State<VideoReelPage> {
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          itemCount: widget.videos.length,
          itemBuilder: (context, i) {
            final v = widget.videos[i];
            return Stack(fit: StackFit.expand, children: [
              Center(
                child: InlineVideo(
                  article: v,
                  aspectRatio: size.width / size.height,
                  fit: BoxFit.contain,
                  muteController: _muted,
                  showMuteButton: false,
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
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpace.lg,
                right: AppSpace.lg,
                bottom: 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v.source,
                        style: AppText.caption.copyWith(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(v.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headline
                            .copyWith(color: Colors.white, fontSize: 17)),
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
              padding: const EdgeInsets.only(top: AppSpace.xs, right: AppSpace.sm),
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
    );
  }
}
