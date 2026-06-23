import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../utils/format.dart';
import '../../../utils/link_out.dart';
import 'signal_badges.dart';

/// Full-width (edge-to-edge) hero for the top stories — mirrors the web
/// HeroCarousel: auto-advances every 6s, loops seamlessly, with a subtle
/// parallax + Ken Burns zoom on the active slide. Autoplay pauses while the
/// user is touching it (and when the app is backgrounded) and resumes shortly
/// after; a play/pause control toggles it. Page dots below.
const _kAutoAdvance = Duration(seconds: 6);
const _kResumeAfter = Duration(seconds: 8);

class SpotlightCarousel extends StatefulWidget {
  const SpotlightCarousel({super.key, required this.articles, this.height = 300});
  final List<Article> articles;
  final double height;

  @override
  State<SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<SpotlightCarousel>
    with WidgetsBindingObserver {
  // Loop seamlessly by starting deep in a virtual (modulo) page space, so the
  // user can swipe both directions and autoplay never hits an edge.
  static const int _kBase = 100000; // multiple of any reasonable length
  late final bool _loop = widget.articles.length > 1;
  late final PageController _controller =
      PageController(initialPage: _loop ? _kBase : 0);
  double _page = 0; // virtual page (may be huge when looping)
  Timer? _timer;
  Timer? _resume;
  bool _playing = true;

  int get _len => widget.articles.length;
  int get _activeIndex => _loop ? (_page.round() % _len) : _page.round();

  @override
  void initState() {
    super.initState();
    _page = _loop ? _kBase.toDouble() : 0;
    _controller.addListener(() {
      final p = _controller.page;
      if (p != null && mounted) setState(() => _page = p);
    });
    WidgetsBinding.instance.addObserver(this);
    _startAutoplay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _resume?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause autoplay when the app isn't in the foreground (web's tab-hidden pause).
    if (state == AppLifecycleState.resumed) {
      if (_playing) _startAutoplay();
    } else {
      _timer?.cancel();
    }
  }

  void _startAutoplay() {
    _timer?.cancel();
    if (!_loop) return;
    _timer = Timer.periodic(_kAutoAdvance, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.nextPage(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _pauseForInteraction() {
    _timer?.cancel();
    _resume?.cancel();
  }

  void _scheduleResume() {
    if (!_playing) return;
    _resume?.cancel();
    _resume = Timer(_kResumeAfter, () {
      if (mounted) _startAutoplay();
    });
  }

  void _togglePlaying() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _startAutoplay();
    } else {
      _timer?.cancel();
      _resume?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = widget.articles;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: Listener(
            onPointerDown: (_) => _pauseForInteraction(),
            onPointerUp: (_) => _scheduleResume(),
            onPointerCancel: (_) => _scheduleResume(),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: _loop ? null : items.length,
                  itemBuilder: (context, i) {
                    final idx = _loop ? i % _len : i;
                    final distance = (_page - i).abs();
                    return _Spotlight(
                      article: items[idx],
                      parallax: (_page - i).clamp(-1.0, 1.0),
                      // Active slide sits at ~1.04 scale, easing to 1.0 as it
                      // slides away — a gentle Ken Burns feel.
                      scale: 1.0 + (0.04 * (1 - distance.clamp(0.0, 1.0))),
                    );
                  },
                ),
                if (_loop)
                  Positioned(
                    top: AppSpace.sm,
                    right: AppSpace.sm,
                    child: _PlayPauseButton(
                      playing: _playing,
                      onTap: _togglePlaying,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        _Dots(count: _len, active: _activeIndex, color: c.brand),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.onTap});
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pause auto-rotation' : 'Resume auto-rotation',
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(playing ? Icons.pause : Icons.play_arrow,
                size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Spotlight extends StatelessWidget {
  const _Spotlight({
    required this.article,
    required this.parallax,
    this.scale = 1.0,
  });
  final Article article;
  final double parallax;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => openArticle(article.sourceUrl, track: article),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (article.hasImage)
            OverflowBox(
              maxWidth: double.infinity,
              child: Transform.translate(
                offset: Offset(parallax * 28, 0),
                child: Transform.scale(
                  scale: scale,
                  child: CachedNetworkImage(
                    imageUrl: article.image,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: c.bgInset),
                    errorWidget: (_, __, ___) => Container(color: c.bgInset),
                  ),
                ),
              ),
            )
          else
            Container(color: c.bgInset),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
                stops: [0.35, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article.isBreaking)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm, vertical: 3),
                    color: c.breaking,
                    child: const Text('BREAKING',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4)),
                  ),
                const SizedBox(height: AppSpace.sm),
                Text(article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title
                        .copyWith(color: Colors.white, height: 1.2)),
                const SizedBox(height: 6),
                Row(children: [
                  SourceFavicon(
                      url: article.sourceUrl, source: article.source, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                        '${article.source} · ${timeAgo(article.publishedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.85))),
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

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active, required this.color});
  final int count;
  final int active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final faint = context.colors.border;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: on ? color : faint,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
