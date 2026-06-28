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
  const InlineVideo({
    super.key,
    required this.article,
    this.aspectRatio = 16 / 9,
    this.tapToToggle = true,
    this.fit = BoxFit.cover,
    this.muteController,
    this.showMuteButton = true,
  });
  final Article article;
  final double aspectRatio;
  /// When supplied, mute state is driven by this shared notifier instead of
  /// per-instance local state — so the full-screen reel can own one prominent
  /// sound toggle that applies to every page. Tapping the speaker (or the
  /// parent's button) flips it for all videos bound to the same controller.
  final ValueNotifier<bool>? muteController;
  /// Hide the built-in corner speaker button (the reel draws its own larger,
  /// easier-to-find control).
  final bool showMuteButton;
  /// When false, taps fall through to a parent (e.g. a Shorts card that opens
  /// the full-screen reel) instead of toggling play/pause.
  final bool tapToToggle;
  /// How the video fills its box — cover for cards, contain for the reel
  /// (so landscape clips letterbox cleanly on black instead of cropping).
  final BoxFit fit;

  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  VideoPlayerController? _ctrl;
  bool _loading = false;
  bool _error = false;
  bool _localMuted = true;

  /// Effective mute: the shared controller wins when present, else local state.
  bool get _muted => widget.muteController?.value ?? _localMuted;

  @override
  void initState() {
    super.initState();
    widget.muteController?.addListener(_onExternalMute);
  }

  // Shared controller flipped elsewhere (e.g. the reel's sound button) — apply
  // the new volume to this player and refresh the speaker icon.
  void _onExternalMute() {
    _ctrl?.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }
  // Unique + stable per instance: the same article can render in two places at
  // once (Shorts rail + interleaved feed), and VisibilityDetector keys must be
  // globally unique. identityHashCode(this) is stable across this State's rebuilds.
  late final Key _visKey =
      Key('video-${widget.article.id}-${identityHashCode(this)}');

  Future<void> _ensureStarted() async {
    if (_ctrl != null || _loading || _error) return;
    final url = widget.article.videoUrl;
    if (url == null || url.isEmpty) return;
    // Some sources emit a relative video path (e.g. DVIDS "/video/x.m3u8") —
    // resolve it against the article URL so it's a fetchable absolute URL.
    Uri? uri = Uri.tryParse(url);
    if (uri != null && !uri.hasScheme) {
      final base = Uri.tryParse(widget.article.sourceUrl ?? '');
      if (base != null && base.hasScheme) uri = base.resolveUri(uri);
    }
    if (uri == null || !uri.hasScheme) {
      setState(() => _error = true);
      return;
    }
    setState(() => _loading = true);
    final ctrl = VideoPlayerController.networkUrl(uri);
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
    final mc = widget.muteController;
    if (mc != null) {
      // Flips every video bound to the shared controller via _onExternalMute.
      mc.value = !mc.value;
    } else {
      setState(() => _localMuted = !_localMuted);
      ctrl.setVolume(_localMuted ? 0 : 1);
    }
  }

  @override
  void dispose() {
    widget.muteController?.removeListener(_onExternalMute);
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
      key: _visKey,
      onVisibilityChanged: _onVisibility,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ready
            ? GestureDetector(
                onTap: widget.tapToToggle
                    ? () => setState(() =>
                        ctrl.value.isPlaying ? ctrl.pause() : ctrl.play())
                    : null,
                child: Stack(fit: StackFit.expand, children: [
                  FittedBox(
                    fit: widget.fit,
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
                  if (widget.showMuteButton)
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
