import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../models/article.dart';
import '../../../theme/tokens.dart';

/// Tap-to-play inline player for a self-hosted article video
/// (`article.videoUrl`, set at ingest — never YouTube/Vimeo). Shows the article
/// image as a poster with a play button; on tap it streams the video with a
/// play/pause toggle + scrub bar. On any load failure it falls back to the
/// poster (the card body still links out to the source).
class InlineVideo extends StatefulWidget {
  const InlineVideo({super.key, required this.article, this.aspectRatio = 16 / 9});
  final Article article;
  final double aspectRatio;

  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  VideoPlayerController? _ctrl;
  bool _loading = false;
  bool _error = false;

  Future<void> _start() async {
    final url = widget.article.videoUrl;
    if (url == null || _loading) return;
    setState(() => _loading = true);
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await ctrl.initialize();
      ctrl.addListener(_onTick);
      await ctrl.play();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _loading = false;
      });
    } catch (_) {
      ctrl.dispose();
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = _ctrl;
    final ready = ctrl != null && ctrl.value.isInitialized;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ready
          ? GestureDetector(
              onTap: () => setState(() =>
                  ctrl.value.isPlaying ? ctrl.pause() : ctrl.play()),
              child: Stack(fit: StackFit.expand, children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: ctrl.value.size.width,
                    height: ctrl.value.size.height,
                    child: VideoPlayer(ctrl),
                  ),
                ),
                if (!ctrl.value.isPlaying)
                  const Center(
                      child: Icon(Icons.play_circle_fill,
                          size: 56, color: Colors.white70)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    ctrl,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: c.brand,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              ]),
            )
          : Stack(fit: StackFit.expand, children: [
              if (widget.article.hasImage)
                CachedNetworkImage(
                  imageUrl: widget.article.image,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: c.bgInset),
                  errorWidget: (_, __, ___) => Container(color: c.bgInset),
                )
              else
                Container(color: c.bgInset),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black45],
                  ),
                ),
              ),
              Center(
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : InkResponse(
                        onTap: _error ? null : _start,
                        child: Icon(
                            _error
                                ? Icons.error_outline
                                : Icons.play_circle_fill,
                            size: 56,
                            color: Colors.white),
                      ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: Colors.black.withValues(alpha: 0.6),
                  child: const Text('VIDEO',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                ),
              ),
            ]),
    );
  }
}
