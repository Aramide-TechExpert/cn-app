import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../data/news_feed_controller.dart' show sourcesProvider;
import '../../data/personalization_controller.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../feed/widgets/signal_badges.dart';

/// Post-signup setup wizard — everything a new account needs, one step at a
/// time (each skippable):
///   1 Profile     — display name
///   2 Interests   — follow topics (powers For You)
///   3 Region      — home country + local-first vs worldwide news
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
  String _newsScope = 'worldwide'; // 'worldwide' | 'region'
  _Country? _country;
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
    _newsScope = meta['news_scope'] as String? ?? 'worldwide';
    final savedCountry = meta['preferred_country'] as String?;
    for (final x in _countries) {
      if (x.name == savedCountry) _country = x;
    }
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
    try {
      await auth.updateProfile({
        'display_name': _name.text.trim(),
        'preferred_sources': _pickedSources.toList(),
        'alerts_breaking': _breakingWatchlist,
        'alerts_high_impact_only': _highImpactOnly,
        'news_scope': _newsScope,
        'preferred_country': _country?.name,
        'preferred_region': _country?.region,
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
          // ── Header: back · progress · skip.
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
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _steps,
                    minHeight: 5,
                    backgroundColor: c.bgInset,
                    valueColor: AlwaysStoppedAnimation(c.brand),
                  ),
                ),
              ),
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
                  scope: _newsScope,
                  country: _country,
                  onScope: (v) => setState(() => _newsScope = v),
                  onCountry: (v) => setState(() => _country = v),
                ),
                _SourcesStep(
                  picked: _pickedSources,
                  onToggle: (s) => setState(() =>
                      _pickedSources.contains(s)
                          ? _pickedSources.remove(s)
                          : _pickedSources.add(s)),
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
              onPressed:
                  _finishing ? null : (last ? _finish : () => _goTo(_step + 1)),
              style: FilledButton.styleFrom(
                backgroundColor: c.brand,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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

/// Shared step scaffold: kicker · title · subtitle · body.
class _Step extends StatelessWidget {
  const _Step({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.child,
  });
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
        Text(kicker.toUpperCase(),
            style: AppText.micro.copyWith(color: c.brand, letterSpacing: 1.2)),
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
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
class _InterestsStep extends ConsumerWidget {
  const _InterestsStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final cats = ref.watch(categoriesProvider);
    final followed =
        ref.watch(interestsControllerProvider).valueOrNull ?? const <String>{};
    return _Step(
      kicker: 'Step 2 · Interests',
      title: 'Follow your topics',
      subtitle:
          'Pick at least 3 — they power your For You rail and daily briefing.',
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
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: list.map((cat) {
                final on = followed.contains(cat.slug);
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(interestsControllerProvider.notifier)
                        .toggle(cat.slug);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.lg, vertical: 10),
                    decoration: BoxDecoration(
                      color: on ? c.brand : c.bgInset,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: on ? c.brand : c.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (on) ...[
                        const Icon(Icons.check,
                            size: 15, color: Colors.white),
                        const SizedBox(width: 5),
                      ],
                      Text(cat.name,
                          style: AppText.callout.copyWith(
                              color: on ? c.onBrand : c.text,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              followed.length >= 3
                  ? '${followed.length} topics followed — nice.'
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
class _Country {
  const _Country(this.name, this.region);
  final String name;
  final String region;
}

const _countries = [
  _Country('Argentina', 'Americas'),
  _Country('Australia', 'Asia-Pacific'),
  _Country('Austria', 'Europe'),
  _Country('Bangladesh', 'Asia-Pacific'),
  _Country('Belgium', 'Europe'),
  _Country('Brazil', 'Americas'),
  _Country('Canada', 'Americas'),
  _Country('Chile', 'Americas'),
  _Country('China', 'Asia-Pacific'),
  _Country('Colombia', 'Americas'),
  _Country('Denmark', 'Europe'),
  _Country('Egypt', 'Middle East'),
  _Country('Ethiopia', 'Africa'),
  _Country('Finland', 'Europe'),
  _Country('France', 'Europe'),
  _Country('Germany', 'Europe'),
  _Country('Ghana', 'Africa'),
  _Country('Greece', 'Europe'),
  _Country('Hong Kong', 'Asia-Pacific'),
  _Country('India', 'Asia-Pacific'),
  _Country('Indonesia', 'Asia-Pacific'),
  _Country('Ireland', 'Europe'),
  _Country('Israel', 'Middle East'),
  _Country('Italy', 'Europe'),
  _Country('Japan', 'Asia-Pacific'),
  _Country('Kenya', 'Africa'),
  _Country('Malaysia', 'Asia-Pacific'),
  _Country('Mexico', 'Americas'),
  _Country('Netherlands', 'Europe'),
  _Country('New Zealand', 'Asia-Pacific'),
  _Country('Nigeria', 'Africa'),
  _Country('Norway', 'Europe'),
  _Country('Pakistan', 'Asia-Pacific'),
  _Country('Peru', 'Americas'),
  _Country('Philippines', 'Asia-Pacific'),
  _Country('Poland', 'Europe'),
  _Country('Portugal', 'Europe'),
  _Country('Qatar', 'Middle East'),
  _Country('Saudi Arabia', 'Middle East'),
  _Country('Singapore', 'Asia-Pacific'),
  _Country('South Africa', 'Africa'),
  _Country('South Korea', 'Asia-Pacific'),
  _Country('Spain', 'Europe'),
  _Country('Sweden', 'Europe'),
  _Country('Switzerland', 'Europe'),
  _Country('Taiwan', 'Asia-Pacific'),
  _Country('Thailand', 'Asia-Pacific'),
  _Country('Turkey', 'Middle East'),
  _Country('Ukraine', 'Europe'),
  _Country('United Arab Emirates', 'Middle East'),
  _Country('United Kingdom', 'Europe'),
  _Country('United States', 'Americas'),
  _Country('Vietnam', 'Asia-Pacific'),
];

class _RegionStep extends StatelessWidget {
  const _RegionStep({
    required this.scope,
    required this.country,
    required this.onScope,
    required this.onCountry,
  });
  final String scope;
  final _Country? country;
  final ValueChanged<String> onScope;
  final ValueChanged<_Country?> onCountry;

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<_Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bgElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CountrySheet(),
    );
    if (picked != null) onCountry(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget scopeCard({
      required String value,
      required IconData icon,
      required String title,
      required String sub,
    }) {
      final on = scope == value;
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onScope(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: AppSpace.md),
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: on ? c.brand : c.border, width: on ? 1.6 : 1),
          ),
          child: Row(children: [
            Icon(icon, size: 24, color: on ? c.brand : c.textSecondary),
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
            if (on) Icon(Icons.check_circle, size: 20, color: c.brand),
          ]),
        ),
      );
    }

    return _Step(
      kicker: 'Step 3 · Region',
      title: 'Where is home?',
      subtitle:
          'Set your country, then choose whether your feed leads with local coverage or the whole world.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _pick(context),
            child: Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              child: Row(children: [
                Icon(Icons.public, size: 24, color: c.brand),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: country == null
                      ? Text('Choose your country',
                          style: AppText.bodyStrong
                              .copyWith(color: c.textSecondary))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(country!.name,
                                style: AppText.bodyStrong
                                    .copyWith(color: c.text)),
                            const SizedBox(height: 3),
                            Text(country!.region,
                                style: AppText.caption
                                    .copyWith(color: c.textSecondary)),
                          ],
                        ),
                ),
                Icon(Icons.chevron_right, color: c.textFaint),
              ]),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          scopeCard(
            value: 'region',
            icon: Icons.location_on_outlined,
            title: 'My country & region first',
            sub:
                'Lead with stories tied to your country and region, then the world.',
          ),
          scopeCard(
            value: 'worldwide',
            icon: Icons.language,
            title: 'Worldwide',
            sub: 'The biggest stories from everywhere, no local weighting.',
          ),
        ],
      ),
    );
  }
}

/// Searchable country picker sheet — pops with the tapped [_Country].
class _CountrySheet extends StatefulWidget {
  const _CountrySheet();

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? _countries
        : _countries
            .where((x) =>
                x.name.toLowerCase().contains(q) ||
                x.region.toLowerCase().contains(q))
            .toList();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(children: [
          const SizedBox(height: AppSpace.sm),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: AppText.body.copyWith(color: c.text),
              decoration: InputDecoration(
                hintText: 'Search countries…',
                hintStyle: TextStyle(color: c.textFaint),
                prefixIcon: Icon(Icons.search, color: c.textFaint),
                filled: true,
                fillColor: c.bgInset,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final x = list[i];
                return ListTile(
                  title:
                      Text(x.name, style: AppText.body.copyWith(color: c.text)),
                  subtitle: Text(x.region,
                      style: AppText.caption.copyWith(color: c.textFaint)),
                  onTap: () => Navigator.pop(context, x),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Step 4: sources ─────────────────────────────────────────────────────────
class _SourcesStep extends ConsumerWidget {
  const _SourcesStep({required this.picked, required this.onToggle});
  final Set<String> picked;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sources = ref.watch(sourcesProvider);
    return _Step(
      kicker: 'Step 4 · Sources',
      title: 'Favorite your publishers',
      subtitle:
          'Choose the outlets you trust most — saved to your profile for a feed tuned to them.',
      child: sources.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpace.xl),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (_, __) => Text("Couldn't load sources.",
            style: AppText.body.copyWith(color: c.textSecondary)),
        data: (list) => Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: list.take(20).map((s) {
            final on = picked.contains(s);
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle(s);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? c.brand : c.bgInset,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: on ? c.brand : c.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SourceFavicon(url: null, source: s, size: 16),
                  const SizedBox(width: 6),
                  Text(s,
                      style: AppText.callout.copyWith(
                          color: on ? c.onBrand : c.text,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          }).toList(),
        ),
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
          border: Border.all(color: c.border),
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
      kicker: 'Step 5 · Alerts',
      title: 'Never miss the big one',
      subtitle:
          'We build a starter watchlist from your topics — matches land on your Alerts page.',
      child: Column(children: [
        card(
          icon: Icons.bolt_outlined,
          title: 'Breaking-news watchlist',
          sub: 'A "My big stories" watchlist matching breaking coverage of your topics.',
          value: breaking,
          onChanged: onBreaking,
        ),
        card(
          icon: Icons.priority_high,
          title: 'High-impact only',
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
      kicker: 'Step 6 · Appearance',
      title: 'Make it yours',
      subtitle: 'Theme and reading size — you can change these any time in Settings.',
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
