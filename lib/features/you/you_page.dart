import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../data/reading_history.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
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
          SliverAppBar.large(
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu, color: c.text),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: Text('You', style: AppText.title.copyWith(color: c.text)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, 0, AppSpace.lg, AppSpace.x3),
            sliver: SliverList.list(
              children: [
                if (user != null)
                  _AccountCard(
                    email: email,
                    onSignOut: () => ref.read(authServiceProvider).signOut(),
                  )
                else
                  _SignInCard(onSignIn: () => context.push('/sign-in')),
                const _StreakBadge(),
                const SizedBox(height: AppSpace.xl),
                ..._menu.map((m) => _MenuRow(item: m)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.email, required this.onSignOut});
  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hue = hueFromString(email).toDouble();
    final avatar = HSLColor.fromAHSL(1, hue, 0.55, 0.45).toColor();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: avatar,
              child: Text(initialOf(email),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(email.isEmpty ? 'Signed in' : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body
                          .copyWith(color: c.text, fontWeight: FontWeight.w600)),
                  Text('Synced account',
                      style: AppText.caption.copyWith(color: c.textFaint)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: AppSpace.lg),
          OutlinedButton(
            onPressed: onSignOut,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.border),
              minimumSize: const Size.fromHeight(46),
            ),
            child: Text('Sign out',
                style: AppText.callout.copyWith(color: c.critical)),
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Card(
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
            ),
            child: const Text('Sign in or create account'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.hint, {this.route});
  final IconData icon;
  final String label;
  final String hint;
  final String? route;
}

const _menu = [
  _MenuItem(Icons.bookmark_outline, 'Saved', '', route: '/saved'),
  _MenuItem(Icons.insights_outlined, 'Insights', '', route: '/insights'),
  _MenuItem(Icons.search, 'Search', '', route: '/search'),
  _MenuItem(Icons.auto_awesome_outlined, 'Your interests', 'Next'),
  _MenuItem(Icons.notifications_outlined, 'Alerts', 'Later'),
  _MenuItem(Icons.settings_outlined, 'Settings', 'Next'),
];

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});
  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: item.route == null ? null : () => context.push(item.route!),
          child: Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Icon(item.icon, size: 20, color: c.textSecondary),
              const SizedBox(width: AppSpace.md),
              Expanded(
                  child: Text(item.label,
                      style: AppText.body.copyWith(color: c.text))),
              if (item.hint.isNotEmpty)
                Text(item.hint,
                    style: AppText.micro.copyWith(color: c.textFaint))
              else if (item.route != null)
                Icon(Icons.chevron_right, size: 18, color: c.textFaint),
            ]),
          ),
        ),
      ),
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
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpace.md),
              Text('$streak-day reading streak',
                  style: AppText.bodyStrong.copyWith(color: c.text)),
            ]),
          ),
        );
      },
    );
  }
}
