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

  @override
  void dispose() {
    _controller.dispose();
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
      ]),
    );
  }
}
