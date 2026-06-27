import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/article.dart';
import '../../../theme/tokens.dart';

/// Muted autoplay inline player for a self-hosted, license-permissive article
/// video (`article.videoUrl`). It starts **muted** when the card scrolls into
/// view and pauses when it leaves; tapping toggles play/pause and a speaker
/// button toggles sound. Loops (short clips). Falls back to the poster on any
/// load failure (the card body still links out to the source).
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
  bool _muted = true;

  Future<void> _ensureStarted() async {
    if (_ctrl != null || _loading || _error) return;
    final url = widget.article.videoUrl;
    if (url == null) return;
    setState(() => _loading = true);
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(_muted ? 0 : 1);
      ctrl.addListener(_tick);
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

  void _tick() {
    if (mounted) setState(() {});
  }

  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final f = info.visibleFraction;
    final ctrl = _ctrl;
    if (f > 0.6) {
      if (ctrl == null) {
        _ensureStarted();
      } else if (!ctrl.value.isPlaying) {
        ctrl.play();
      }
    } else if (f < 0.15 && ctrl != null && ctrl.value.isPlaying) {
      ctrl.pause();
    }
  }

  void _toggleMute() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    setState(() => _muted = !_muted);
    ctrl.setVolume(_muted ? 0 : 1);
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_tick);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = _ctrl;
    final ready = ctrl != null && ctrl.value.isInitialized;
    return VisibilityDetector(
      key: Key('video-${widget.article.id}'),
      onVisibilityChanged: _onVisibility,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ready
            ? GestureDetector(
                onTap: () => setState(
                    () => ctrl.value.isPlaying ? ctrl.pause() : ctrl.play()),
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
                    right: AppSpace.sm,
                    top: AppSpace.sm,
                    child: _RoundBtn(
                      icon: _muted ? Icons.volume_off : Icons.volume_up,
                      onTap: _toggleMute,
                    ),
                  ),
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
                      : Icon(
                          _error ? Icons.error_outline : Icons.play_circle_fill,
                          size: 56,
                          color: Colors.white),
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
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
