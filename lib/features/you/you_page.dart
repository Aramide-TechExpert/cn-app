import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/alerts_controller.dart';
import '../../data/auth_controller.dart';
import '../../data/personalization_controller.dart';
import '../../data/reading_history.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../feed/widgets/rail_card.dart';
import '../shell/app_drawer.dart';

class YouPage extends ConsumerWidget {
  const YouPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: c.bg,
      drawer: const AppDrawer(),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Compact pinned+floating bar — same rhythm as Home / News Feed.
          SliverAppBar(
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            floating: true,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu, color: c.text),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: Text('You', style: AppText.title.copyWith(color: c.text)),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined, color: c.text),
                onPressed: () => context.push('/settings'),
              ),
              const SizedBox(width: AppSpace.xs),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.x3),
            sliver: SliverList.list(
              children: [
                if (user != null)
                  _ProfileHero(
                    email: email,
                    name: (user.userMetadata?['display_name'] as String?)
                            ?.trim() ??
                        '',
                    // Country beats region on the chip when localized.
                    region: user.userMetadata?['news_scope'] == 'region'
                        ? ((user.userMetadata?['preferred_country']
                                    as String?) ??
                                (user.userMetadata?['preferred_region']
                                    as String?))
                        : null,
                    onEdit: () => context.push('/setup?edit=1'),
                    onSignOut: () => ref.read(authServiceProvider).signOut(),
                  )
                else
                  _SignInCard(onSignIn: () => context.push('/sign-in')),
                const _StreakBadge(),
                if (user != null) const _WhatYouMissed(),
                const SizedBox(height: AppSpace.xl),
                const _MenuGroup(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Native-feel profile header: soft brand gradient, ringed avatar, name and
/// email, with edit and sign-out as compact actions.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.email,
    this.name = '',
    this.region,
    required this.onEdit,
    required this.onSignOut,
  });
  final String email;
  final String name;
  final String? region;
  final VoidCallback onEdit;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final seed = name.isNotEmpty ? name : email;
    final hue = hueFromString(seed).toDouble();
    final avatar = HSLColor.fromAHSL(1, hue, 0.55, 0.45).toColor();
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.brand.withValues(alpha: 0.16), c.bgElevated],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.brand, width: 2.5),
          ),
          child: CircleAvatar(
            radius: 36,
            backgroundColor: avatar,
            child: Text(initialOf(seed),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          name.isNotEmpty ? name : (email.isEmpty ? 'Signed in' : email),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppText.title.copyWith(color: c.text),
        ),
        if (email.isNotEmpty && name.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: c.textSecondary)),
        ],
        if (region != null && region!.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: 4),
            decoration: BoxDecoration(
              color: c.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.public, size: 13, color: c.brand),
              const SizedBox(width: 4),
              Text('$region news',
                  style: AppText.micro.copyWith(
                      color: c.brand, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        Row(children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () {
                HapticFeedback.selectionClick();
                onEdit();
              },
              style: FilledButton.styleFrom(
                backgroundColor: c.brand.withValues(alpha: 0.14),
                foregroundColor: c.brand,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.tune, size: 17),
              label: const Text('Edit profile'),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: TextButton.icon(
              onPressed: onSignOut,
              style: TextButton.styleFrom(
                foregroundColor: c.critical,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.logout, size: 17),
              label: const Text('Sign out'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.brand.withValues(alpha: 0.16), c.bgElevated],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign in to Clustez',
              style: AppText.headline.copyWith(color: c.text)),
          const SizedBox(height: 4),
          Text('Save stories, follow topics, and sync across devices.',
              style: AppText.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: onSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: c.brand,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Sign in or create account'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, {this.route});
  final IconData icon;
  final String label;
  final String? route;
}

const _menu = [
  _MenuItem(Icons.bookmark_outline, 'Saved', route: '/saved'),
  _MenuItem(Icons.insights_outlined, 'Insights', route: '/insights'),
  _MenuItem(Icons.search, 'Search', route: '/search'),
  _MenuItem(Icons.auto_awesome_outlined, 'Your interests', route: '/interests'),
  _MenuItem(Icons.bookmarks_outlined, 'Watchlists', route: '/watchlists'),
  _MenuItem(Icons.notifications_outlined, 'Alerts', route: '/alerts'),
  _MenuItem(Icons.settings_outlined, 'Settings', route: '/settings'),
];

/// Grouped native-style menu: one rounded card, inset dividers, tinted icon
/// squares, chevrons. Replaces the old row-of-bordered-boxes web look.
class _MenuGroup extends ConsumerWidget {
  const _MenuGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unreadAlerts = ref
            .watch(alertsControllerProvider)
            .valueOrNull
            ?.where((a) => a.unread)
            .length ??
        0;
    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        for (var i = 0; i < _menu.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 62),
              child: Divider(height: 1, thickness: 0.5, color: c.border),
            ),
          _MenuRow(
            item: _menu[i],
            badge: _menu[i].route == '/alerts' ? unreadAlerts : 0,
            first: i == 0,
            last: i == _menu.length - 1,
          ),
        ],
      ]),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    this.badge = 0,
    this.first = false,
    this.last = false,
  });
  final _MenuItem item;
  final int badge;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(first ? 20 : 0),
          bottom: Radius.circular(last ? 20 : 0),
        ),
        onTap: item.route == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                context.push(item.route!);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: 13),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.brand.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item.icon, size: 17, color: c.brand),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
                child:
                    Text(item.label, style: AppText.body.copyWith(color: c.text))),
            if (badge > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: c.brand,
                    borderRadius: BorderRadius.circular(AppRadii.pill)),
                child: Text('$badge',
                    style: AppText.micro.copyWith(color: c.onBrand)),
              )
            else if (item.route != null)
              Icon(Icons.chevron_right, size: 18, color: c.textFaint),
          ]),
        ),
      ),
    );
  }
}

/// "What you missed" — unread stories from followed topics. Hidden when empty.
class _WhatYouMissed extends ConsumerWidget {
  const _WhatYouMissed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final items = ref.watch(whatYouMissedProvider).valueOrNull ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.xl),
        Text('What you missed',
            style: AppText.headline.copyWith(color: c.text, fontSize: 16)),
        const SizedBox(height: AppSpace.md),
        SizedBox(
          height: 224,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.lg),
            itemBuilder: (_, i) => RailCard(article: items[i]),
          ),
        ),
      ],
    );
  }
}

/// Reading streak chip (consecutive days reading). Hidden at 0.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<int>(
      valueListenable: ReadingHistory.streak,
      builder: (context, streak, _) {
        if (streak <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg, vertical: AppSpace.md),
            decoration: BoxDecoration(
              color: c.bgInset,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔥', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpace.md),
              Text('$streak day reading streak',
                  style: AppText.bodyStrong.copyWith(color: c.text)),
            ]),
          ),
        );
      },
    );
  }
}
