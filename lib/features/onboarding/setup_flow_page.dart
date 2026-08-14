import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../data/news_feed_controller.dart' show publishersProvider;
import '../../data/personalization_controller.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../../utils/source_regions.dart';
import '../feed/widgets/signal_badges.dart';

/// Post-signup setup wizard — everything a new account needs, one step at a
/// time (each skippable):
///   1 Profile     — display name
///   2 Interests   — follow topics (powers For You)
///   3 Region      — news region segment (US, UK, Canada, Africa, …) or Worldwide
///   4 Sources     — favorite publishers (stored in profile metadata)
///   5 Alerts      — breaking-news starter watchlist + high-impact filter
///   6 Appearance  — theme + text size
/// Prefs land in Supabase auth metadata (synced across devices); interests
/// and the starter watchlist land in their own tables. With [edit] true
/// (Settings → Preferences) every step prefills from saved metadata and
/// finishing returns to Settings instead of Home.
class SetupFlowPage extends ConsumerStatefulWidget {
  const SetupFlowPage({super.key, this.edit = false});
  final bool edit;

  @override
  ConsumerState<SetupFlowPage> createState() => _SetupFlowPageState();
}

class _SetupFlowPageState extends ConsumerState<SetupFlowPage> {
  static const _steps = 6;
  final _page = PageController();
  final _name = TextEditingController();
  int _step = 0;
  final Set<String> _pickedSources = {};
  bool _breakingWatchlist = true;
  bool _highImpactOnly = false;
  /// Selected location scopes — "Segment" or "Segment|Country" entries,
  /// MULTI and CROSS-region (2026-08-14). Empty = Worldwide. The feed is
  /// the union; the first entry is the PRIMARY (briefing/trending edition).
  final List<String> _scopes = [];
  String get _segment =>
      _scopes.isEmpty ? 'Worldwide' : _scopes.first.split('|').first;
  String? get _country {
    if (_scopes.isEmpty) return null;
    final parts = _scopes.first.split('|');
    return parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  }
  bool _detecting = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    final meta = user?.userMetadata ?? const {};
    // Google accounts arrive with full_name/name — use it before falling back
    // to the email prefix.
    final fromMeta = ((meta['display_name'] ??
            meta['full_name'] ??
            meta['name']) as String?)
        ?.trim();
    _name.text = (fromMeta?.isNotEmpty ?? false)
        ? fromMeta!
        : (user?.email?.split('@').first ?? '');
    // Prefill everything the user already saved, so re-running the wizard
    // from Settings edits preferences instead of resetting them.
    _pickedSources
        .addAll(((meta['preferred_sources'] as List?) ?? const []).cast<String>());
    _breakingWatchlist = meta['alerts_breaking'] as bool? ?? true;
    _highImpactOnly = meta['alerts_high_impact_only'] as bool? ?? false;
    final savedScopes = meta['preferred_scopes'];
    if (savedScopes is List && savedScopes.isNotEmpty) {
      for (final e in savedScopes) {
        if (e is! String || e.isEmpty) continue;
        final seg = e.split('|').first;
        if (newsSegments.any((s) => s.$1 == seg) && !_scopes.contains(e)) {
          _scopes.add(e);
        }
      }
    } else {
      // Legacy single-scope prefill.
      final saved = meta['preferred_region'] as String?;
      if (meta['news_scope'] == 'region' &&
          newsSegments.any((s) => s.$1 == saved)) {
        final savedCountry = meta['preferred_country'] as String?;
        _scopes.add((countriesFor(saved!)?.contains(savedCountry) ?? false)
            ? '$saved|$savedCountry'
            : saved);
      }
    }
  }

  /// Country-level location detect (IP lookup, no permission dialog): sets
  /// both the segment and, when we carry that country's outlets, the country.
  /// Three independent free providers are tried in order — each one
  /// rate-limits under load, so any failure or bad payload falls through.
  Future<void> _detectLocation() async {
    setState(() => _detecting = true);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ));
    String? detected;
    try {
      final r = await dio.get('https://ipapi.co/json/');
      final d = r.data;
      // Rate limiting arrives as 200 + {"error": true} here.
      if (d is Map && d['error'] != true) {
        detected = d['country_name'] as String?;
      }
    } catch (_) {}
    if (detected == null) {
      try {
        final r = await dio.get('https://ipwho.is/');
        final d = r.data;
        if (d is Map && d['success'] == true) {
          detected = d['country'] as String?;
        }
      } catch (_) {}
    }
    if (detected == null) {
      try {
        final r = await dio.get('https://api.country.is/');
        final d = r.data;
        if (d is Map) detected = isoToCountry[d['country']];
      } catch (_) {}
    }
    if (!mounted) return;
    final segment = detected == null ? null : countryToSegment[detected];
    setState(() {
      _detecting = false;
      if (segment != null) {
        final scope = (countriesFor(segment)?.contains(detected) ?? false)
            ? '$segment|$detected'
            : segment;
        // Detected location becomes the PRIMARY scope (kept alongside any
        // other regions already selected).
        _scopes
          ..removeWhere((e) => e.split('|').first == segment)
          ..insert(0, scope);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(segment == null
            ? "Couldn't detect your location. Pick your region manually."
            : 'Set to ${_country ?? _segment} from your location.')));
  }

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _page.animateToPage(step,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  /// Closing the wizard still counts as done — mark it so sign-in never
  /// re-traps this account; every preference stays editable in Settings.
  void _dismiss() {
    ref
        .read(authServiceProvider)
        .updateProfile({'setup_complete': true}).catchError((_) {});
    ref.read(settingsControllerProvider.notifier).markFirstRunSeen();
    context.canPop() ? context.pop() : context.go('/');
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final auth = ref.read(authServiceProvider);
    final followed =
        ref.read(interestsControllerProvider).valueOrNull ?? const <String>{};
    // Enforce the Location preference on favorites: picks made under an
    // earlier location must not survive a change (the picker never shows
    // them, but the saved list has to match what the gate allows too).
    final gateMeta = <String, dynamic>{
      'news_scope': _scopes.isEmpty ? 'worldwide' : 'region',
      'preferred_scopes': List<String>.of(_scopes),
      'preferred_region': _segment,
      if (_country != null) 'preferred_country': _country,
    };
    try {
      await auth.updateProfile({
        'display_name': _name.text.trim(),
        'preferred_sources':
            _pickedSources.where((s) => sourceVisible(s, gateMeta)).toList(),
        'alerts_breaking': _breakingWatchlist,
        'alerts_high_impact_only': _highImpactOnly,
        // Multi/cross-region scopes + the legacy single-scope keys
        // (primary = first scope) so older builds and single-region
        // surfaces (briefing, trending) keep working.
        'preferred_scopes': List<String>.of(_scopes),
        'news_scope': _segment == 'Worldwide' ? 'worldwide' : 'region',
        'preferred_region': _segment,
        'preferred_country': _country,
        'setup_complete': true,
      });
      // Starter watchlist so Alerts has something to match from day one —
      // first run only; editing prefs must not spawn duplicates.
      if (!widget.edit && _breakingWatchlist && followed.isNotEmpty) {
        final cats =
            ref.read(categoriesProvider).valueOrNull ?? const <CategoryOption>[];
        final names = [
          for (final c in cats)
            if (followed.contains(c.slug)) c.name,
        ].take(6).toList();
        if (names.isNotEmpty) {
          await ref.read(watchlistsControllerProvider.notifier).create(
                name: 'My big stories',
                tags: names,
                breaking: true,
                highImpact: _highImpactOnly,
              );
        }
      }
    } catch (_) {
      // Setup must never trap the user — prefs can be edited later.
    }
    ref.read(settingsControllerProvider.notifier).markFirstRunSeen();
    if (!mounted) return;
    // Edit flow returns to Settings; first run heads Home.
    if (widget.edit && context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = _step == _steps - 1;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Header: back · skip (the step kicker inside each page carries
          // the "Step N" context; no progress bar).
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
            child: Row(children: [
              IconButton(
                onPressed: _step == 0 ? _dismiss : () => _goTo(_step - 1),
                icon: Icon(
                    _step == 0 ? Icons.close : Icons.arrow_back_ios_new,
                    size: 20,
                    color: c.textSecondary),
              ),
              const Spacer(),
              TextButton(
                onPressed:
                    _finishing ? null : (last ? _finish : () => _goTo(_step + 1)),
                child: Text('Skip',
                    style: AppText.callout.copyWith(color: c.textSecondary)),
              ),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ProfileStep(name: _name),
                const _InterestsStep(),
                _RegionStep(
                  scopes: List<String>.of(_scopes),
                  detecting: _detecting,
                  onDetect: _detectLocation,
                  onScopes: (v) => setState(() {
                    _scopes
                      ..clear()
                      ..addAll(v);
                  }),
                ),
                _SourcesStep(
                  picked: _pickedSources,
                  onToggle: (s) => setState(() =>
                      _pickedSources.contains(s)
                          ? _pickedSources.remove(s)
                          : _pickedSources.add(s)),
                  scopes: List<String>.of(_scopes),
                ),
                _AlertsStep(
                  breaking: _breakingWatchlist,
                  highImpact: _highImpactOnly,
                  onBreaking: (v) => setState(() => _breakingWatchlist = v),
                  onHighImpact: (v) => setState(() => _highImpactOnly = v),
                ),
                const _AppearanceStep(),
              ],
            ),
          ),
          // ── Primary action.
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: FilledButton(
              onPressed: _finishing
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      last ? _finish() : _goTo(_step + 1);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: c.brand,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: _finishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(last ? "I'm all set" : 'Continue'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Shared step scaffold: tonal icon · kicker · title · subtitle · body.
class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final IconData icon;
  final String kicker;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.lg),
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.brand.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: c.brand),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(kicker.toUpperCase(),
            style:
                AppText.micro.copyWith(color: c.brand, letterSpacing: 1.2)),
        const SizedBox(height: AppSpace.xs),
        Text(title, style: AppText.display.copyWith(color: c.text)),
        const SizedBox(height: AppSpace.sm),
        Text(subtitle,
            style: AppText.body.copyWith(color: c.textSecondary, height: 1.5)),
        const SizedBox(height: AppSpace.xl),
        child,
      ],
    );
  }
}

// ── Step 1: profile ─────────────────────────────────────────────────────────
class _ProfileStep extends ConsumerWidget {
  const _ProfileStep({required this.name});
  final TextEditingController name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final email = ref.watch(currentUserProvider)?.email ?? '';
    return _Step(
      icon: Icons.person_outline,
      kicker: 'Step 1 · Profile',
      title: 'What should we call you?',
      subtitle: 'Your name shows on your account and comments.',
      child: Column(children: [
        ValueListenableBuilder(
          valueListenable: name,
          builder: (_, v, __) {
            final seed = v.text.trim().isEmpty ? email : v.text.trim();
            return CircleAvatar(
              radius: 40,
              backgroundColor:
                  HSLColor.fromAHSL(1, hueFromString(seed).toDouble(), 0.55, 0.45)
                      .toColor(),
              child: Text(initialOf(seed),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800)),
            );
          },
        ),
        const SizedBox(height: AppSpace.xl),
        TextField(
          controller: name,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.words,
          style: AppText.headline.copyWith(color: c.text),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: c.textFaint),
            filled: true,
            fillColor: c.bgInset,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.brand),
            ),
          ),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
          Text(email, style: AppText.caption.copyWith(color: c.textFaint)),
        ],
      ]),
    );
  }
}

// ── Step 2: interests ───────────────────────────────────────────────────────
/// Topic icon per category slug — gives the tile grid the same leading-glyph
/// rhythm as the Location step's emoji tiles.
IconData _topicIcon(String slug) => switch (slug) {
      'ai' => Icons.auto_awesome,
      'world-news' => Icons.public,
      'politics' => Icons.account_balance,
      'business' => Icons.business_center,
      'finance' => Icons.trending_up,
      'technology' => Icons.memory,
      'science' => Icons.science,
      'health' => Icons.monitor_heart,
      'climate' => Icons.eco,
      'sports' => Icons.sports_soccer,
      'entertainment' => Icons.theaters,
      'startups' => Icons.rocket_launch,
      'cybersecurity' => Icons.security,
      'general-news' => Icons.newspaper,
      _ => Icons.tag,
    };

class _InterestsStep extends ConsumerWidget {
  const _InterestsStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final cats = ref.watch(categoriesProvider);
    final followed =
        ref.watch(interestsControllerProvider).valueOrNull ?? const <String>{};
    return _Step(
      icon: Icons.auto_awesome_outlined,
      kicker: 'Step 2 · Interests',
      title: 'Follow your topics',
      subtitle:
          'Pick at least 3. They power your For You rail and daily briefing.',
      child: cats.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpace.xl),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (_, __) => Text("Couldn't load topics.",
            style: AppText.body.copyWith(color: c.textSecondary)),
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TileGrid(children: [
              for (final cat in list)
                _PickTile(
                  label: cat.name,
                  leading: Icon(_topicIcon(cat.slug),
                      size: 20,
                      color: followed.contains(cat.slug)
                          ? c.brand
                          : c.textSecondary),
                  selected: followed.contains(cat.slug),
                  onTap: () => ref
                      .read(interestsControllerProvider.notifier)
                      .toggle(cat.slug),
                ),
            ]),
            const SizedBox(height: AppSpace.lg),
            Text(
              followed.length >= 3
                  ? '${followed.length} topics followed. Nice.'
                  : '${followed.length} of 3 picked',
              style: AppText.caption.copyWith(
                  color: followed.length >= 3 ? c.success : c.textFaint,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: region ──────────────────────────────────────────────────────────
class _RegionStep extends StatelessWidget {
  const _RegionStep({
    required this.scopes,
    required this.detecting,
    required this.onDetect,
    required this.onScopes,
  });
  /// "Segment" / "Segment|Country" entries — multi + cross-region.
  final List<String> scopes;
  final bool detecting;
  final VoidCallback onDetect;
  final ValueChanged<List<String>> onScopes;

  bool _segmentOn(String seg) => scopes.any((e) => e.split('|').first == seg);

  String _chipLabel(String e) {
    final parts = e.split('|');
    return parts.length > 1 && parts[1].isNotEmpty
        ? parts[1]
        : 'All ${parts.first}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Step(
      icon: Icons.public,
      kicker: 'Step 3 · Region',
      title: 'Make it local',
      subtitle:
          'Pick one or SEVERAL regions and countries — your feed becomes the mix of all of them. Worldwide keeps it fully global.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.tonalIcon(
            onPressed: detecting ? null : onDetect,
            style: FilledButton.styleFrom(
              backgroundColor: c.brand.withValues(alpha: 0.14),
              foregroundColor: c.brand,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            icon: detecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, size: 18),
            label: Text(detecting ? 'Detecting…' : 'Use my location'),
          ),
          const SizedBox(height: AppSpace.lg),
          _TileGrid(children: [
            for (final (label, emoji) in newsSegments)
              _PickTile(
                label: label,
                leading: Text(emoji, style: const TextStyle(fontSize: 22)),
                selected: label == 'Worldwide'
                    ? scopes.isEmpty
                    : _segmentOn(label),
                onTap: () {
                  if (label == 'Worldwide') {
                    onScopes(const []);
                    return;
                  }
                  if (countriesFor(label) == null) {
                    // Single-country segment (US/UK/Canada/India): the tap
                    // simply toggles it in or out of the mix.
                    final next = List<String>.of(scopes);
                    _segmentOn(label)
                        ? next.removeWhere(
                            (e) => e.split('|').first == label)
                        : next.add(label);
                    onScopes(next);
                    return;
                  }
                  // Regions with a country roster pop the multi-select
                  // drawer (pick several countries, or the whole region).
                  _showCountryDrawer(context,
                      segment: label, scopes: scopes, onScopes: onScopes);
                },
              ),
          ]),
          if (scopes.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xl),
            Text('Your locations',
                style: AppText.bodyStrong.copyWith(color: c.text)),
            const SizedBox(height: 3),
            Text(
                'Stories from all of these lead your feed. The first is your briefing edition.',
                style: AppText.caption.copyWith(color: c.textFaint)),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final e in scopes)
                  _ScopeChip(
                    label: _chipLabel(e),
                    onRemove: () =>
                        onScopes(List<String>.of(scopes)..remove(e)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Country picker drawer — MULTI-select: check several countries, or the
/// whole region; Done applies. Same sheet construction as the app's other
/// sheets (material paints to the screen bottom, SafeArea pads content).
Future<void> _showCountryDrawer(
  BuildContext context, {
  required String segment,
  required List<String> scopes,
  required ValueChanged<List<String>> onScopes,
}) {
  final countries = [...?countriesFor(segment)]..sort();
  final other =
      scopes.where((e) => e.split('|').first != segment).toList();
  final picked = <String>{
    for (final e in scopes)
      if (e.split('|').first == segment &&
          e.contains('|') &&
          e.split('|')[1].isNotEmpty)
        e.split('|')[1],
  };
  // Opening an unselected region defaults to "All" so a quick Done adds
  // the whole region; specific picks switch All off.
  var all = picked.isEmpty;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.bgElevated,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final c = ctx.colors;
        Widget row(String label, bool on, VoidCallback onTap,
                {bool emphasize = false}) =>
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.x2, vertical: 13),
                child: Row(children: [
                  Expanded(
                    child: Text(label,
                        style: (emphasize || on
                                ? AppText.bodyStrong
                                : AppText.body)
                            .copyWith(color: on ? c.brand : c.text)),
                  ),
                  Icon(
                      on
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 22,
                      color: on ? c.brand : c.textFaint),
                ]),
              ),
            );
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.72),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.x2, 0, AppSpace.x2, 4),
                  child: Text(segment,
                      style: AppText.headline.copyWith(color: c.text)),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpace.x2),
                  child: Text(
                      'Pick one or several countries, or the whole region.',
                      style: AppText.caption.copyWith(color: c.textFaint)),
                ),
                const SizedBox(height: AppSpace.sm),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      row('All $segment', all, () {
                        setSheet(() {
                          all = !all;
                          if (all) picked.clear();
                        });
                      }, emphasize: true),
                      Divider(height: 1, thickness: 1, color: c.border),
                      for (final name in countries) ...[
                        row(name, picked.contains(name), () {
                          setSheet(() {
                            picked.contains(name)
                                ? picked.remove(name)
                                : picked.add(name);
                            if (picked.isNotEmpty) all = false;
                          });
                        }),
                        if (name != countries.last)
                          Divider(
                              height: 1, thickness: 1, color: c.border),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.x2, AppSpace.sm, AppSpace.x2, AppSpace.md),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: () {
                      // Nothing checked at all = region removed from the mix.
                      onScopes([
                        ...other,
                        if (all)
                          segment
                        else
                          ...picked.map((n) => '$segment|$n'),
                      ]);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Short readable summary of the scope list ("Nigeria, UK +2 more").
String _scopesSummary(List<String> scopes) {
  final names = [
    for (final e in scopes)
      e.contains('|') && e.split('|')[1].isNotEmpty
          ? e.split('|')[1]
          : e.split('|').first,
  ];
  if (names.length <= 2) return names.join(', ');
  return '${names.take(2).join(', ')} +${names.length - 2} more';
}

/// Removable location chip on the Region step.
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, 6, AppSpace.sm, 6),
      decoration: BoxDecoration(
        color: c.brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: AppText.callout
                .copyWith(color: c.brand, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            HapticFeedback.selectionClick();
            onRemove();
          },
          child: Icon(Icons.close_rounded, size: 16, color: c.brand),
        ),
      ]),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.label,
    required this.leading,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        decoration: BoxDecoration(
          color: selected ? c.brand.withValues(alpha: 0.14) : c.bgInset,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          leading,
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.callout.copyWith(
                    color: selected ? c.brand : c.text,
                    fontWeight: FontWeight.w700)),
          ),
          if (selected) Icon(Icons.check_circle, size: 18, color: c.brand),
        ]),
      ),
    );
  }
}

/// 2-column tile grid — the Location step's arrangement, reused by the
/// Topics and Publishers steps for a consistent wizard.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpace.sm,
      crossAxisSpacing: AppSpace.sm,
      childAspectRatio: 2.6,
      children: children,
    );
  }
}

// ── Step 4: sources ─────────────────────────────────────────────────────────
class _SourcesStep extends ConsumerStatefulWidget {
  const _SourcesStep({
    required this.picked,
    required this.onToggle,
    required this.scopes,
  });
  final Set<String> picked;
  final ValueChanged<String> onToggle;
  /// The Location step's LIVE multi-scope pick, not saved metadata.
  final List<String> scopes;

  @override
  ConsumerState<_SourcesStep> createState() => _SourcesStepState();
}

class _SourcesStepState extends ConsumerState<_SourcesStep> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _group(BuildContext context, String label, List<String> names) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: AppText.micro
              .copyWith(color: c.textSecondary, letterSpacing: 1.2)),
      const SizedBox(height: AppSpace.sm),
      _TileGrid(children: [
        for (final s in names)
          _PickTile(
            label: s,
            leading: SourceFavicon(url: null, source: s, size: 20),
            selected: widget.picked.contains(s),
            onTap: () => widget.onToggle(s),
          ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final publishers = ref.watch(publishersProvider);
    // The gate sees the wizard's live Location pick, so the roster reacts
    // the moment the previous step changes — before anything is saved.
    final meta = <String, dynamic>{
      'news_scope': widget.scopes.isEmpty ? 'worldwide' : 'region',
      'preferred_scopes': widget.scopes,
    };
    return _Step(
      icon: Icons.newspaper_outlined,
      kicker: 'Step 4 · Sources',
      title: 'Favorite your publishers',
      subtitle: widget.scopes.isEmpty
          ? 'Choose the outlets you trust most. Your feed gets tuned to them.'
          : 'Publishers for ${_scopesSummary(widget.scopes)} plus the '
              'global desks. Your feed gets tuned to them.',
      child: publishers.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpace.xl),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (_, __) => Text("Couldn't load publishers.",
            style: AppText.body.copyWith(color: c.textSecondary)),
        data: (all) {
          final q = _search.text.trim().toLowerCase();
          final visible = all
              .where((s) => sourceVisible(s, meta))
              .where((s) => q.isEmpty || s.toLowerCase().contains(q))
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          // Their location's own outlets lead; global desks + topical
          // verticals follow.
          final local = visible
              .where((s) => sourceInfo(s)?.kind == SourceKind.national)
              .toList();
          final global =
              visible.where((s) => !local.contains(s)).toList();
          final localLabel = widget.scopes.isEmpty
              ? 'Flagship publishers'
              : _scopesSummary(widget.scopes);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search publishers',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _search.clear()),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: c.bgInset,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              if (visible.isEmpty)
                Text('No publishers match "${_search.text.trim()}".',
                    style: AppText.body.copyWith(color: c.textSecondary))
              else ...[
                if (local.isNotEmpty) _group(context, localLabel, local),
                if (local.isNotEmpty && global.isNotEmpty)
                  const SizedBox(height: AppSpace.lg),
                if (global.isNotEmpty)
                  _group(context, 'Global & topics', global),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Step 4: alerts ──────────────────────────────────────────────────────────
class _AlertsStep extends StatelessWidget {
  const _AlertsStep({
    required this.breaking,
    required this.highImpact,
    required this.onBreaking,
    required this.onHighImpact,
  });
  final bool breaking;
  final bool highImpact;
  final ValueChanged<bool> onBreaking;
  final ValueChanged<bool> onHighImpact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget card(
        {required IconData icon,
        required String title,
        required String sub,
        required bool value,
        required ValueChanged<bool> onChanged}) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpace.md),
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon, size: 24, color: c.brand),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong.copyWith(color: c.text)),
                const SizedBox(height: 3),
                Text(sub,
                    style: AppText.caption
                        .copyWith(color: c.textSecondary, height: 1.35)),
              ],
            ),
          ),
          Switch.adaptive(
              value: value, activeColor: c.brand, onChanged: onChanged),
        ]),
      );
    }

    return _Step(
      icon: Icons.notifications_active_outlined,
      kicker: 'Step 5 · Alerts',
      title: 'Never miss the big one',
      subtitle:
          'We build a starter watchlist from your topics. Matches land on your Alerts page.',
      child: Column(children: [
        card(
          icon: Icons.bolt_outlined,
          title: 'Breaking news watchlist',
          sub: 'A "My big stories" watchlist matching breaking coverage of your topics.',
          value: breaking,
          onChanged: onBreaking,
        ),
        card(
          icon: Icons.priority_high,
          title: 'High impact only',
          sub: 'Limit matches to Critical and High impact stories.',
          value: highImpact,
          onChanged: onHighImpact,
        ),
      ]),
    );
  }
}

// ── Step 5: appearance ──────────────────────────────────────────────────────
class _AppearanceStep extends ConsumerWidget {
  const _AppearanceStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);
    return _Step(
      icon: Icons.palette_outlined,
      kicker: 'Step 6 · Appearance',
      title: 'Make it yours',
      subtitle:
          'Theme and reading size. You can change these any time in Settings.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Auto')),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light')),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => notifier.setThemeMode(s.first),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Text size',
              style: AppText.bodyStrong.copyWith(color: c.text)),
          Slider.adaptive(
            value: settings.textScale.clamp(0.85, 1.3),
            min: 0.85,
            max: 1.3,
            divisions: 9,
            activeColor: c.brand,
            label: '${(settings.textScale * 100).round()}%',
            onChanged: (v) => notifier.setTextScale(v),
          ),
          Text('The quick brown fox jumps over the lazy dog.',
              style: AppText.body.copyWith(
                  color: c.textSecondary,
                  fontSize: 15 * settings.textScale)),
        ],
      ),
    );
  }
}
