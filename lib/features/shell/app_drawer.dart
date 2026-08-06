import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../data/source_signals.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';

/// The app-wide side menu — modernized (Bing-style): brand/profile header,
/// a rounded grid of quick-access tiles, then grouped rounded cards for
/// tools, category chips, and account.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? '';

    void go(String path) {
      Navigator.pop(context);
      context.go(path);
    }

    void push(String path) {
      Navigator.pop(context);
      context.push(path);
    }

    return Drawer(
      backgroundColor: c.bg,
      // Square right edge — no top/bottom corner curve.
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.lg),
          children: [
            // ── Brand + profile header card.
            Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.brand, c.brand.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('C',
                          style: AppText.headline.copyWith(color: c.brand)),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Text('Clustez',
                        style: AppText.title.copyWith(color: Colors.white)),
                  ]),
                  const SizedBox(height: AppSpace.lg),
                  if (user != null)
                    Row(children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.white,
                        child: Text(
                            initialOf(
                                (user.userMetadata?['display_name'] as String?)
                                        ?.trim()
                                        .isNotEmpty ==
                                    true
                                    ? user.userMetadata!['display_name'] as String
                                    : email),
                            style: TextStyle(
                                color: c.brand,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                ((user.userMetadata?['display_name']
                                                as String?)
                                            ?.trim()
                                            .isNotEmpty ==
                                        true)
                                    ? user.userMetadata!['display_name']
                                        as String
                                    : 'Signed in',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            Text(email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.micro.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.85))),
                          ],
                        ),
                      ),
                      InkResponse(
                        onTap: () => go('/you'),
                        child: const Icon(Icons.chevron_right,
                            color: Colors.white70),
                      ),
                    ])
                  else
                    FilledButton(
                      onPressed: () => push('/sign-in'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: c.brand,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sign in',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),

            // ── Quick access grid (Bing-style feature tiles).
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: AppSpace.md,
              crossAxisSpacing: AppSpace.md,
              childAspectRatio: 0.86,
              children: [
                _Tile(icon: Icons.home_outlined, label: 'Home', onTap: () => go('/')),
                _Tile(
                    icon: Icons.dynamic_feed_outlined,
                    label: 'Feed',
                    onTap: () => go('/discover')),
                _Tile(
                    icon: Icons.play_circle_outline,
                    label: 'Reel',
                    onTap: () => go('/stack')),
                _Tile(
                    icon: Icons.account_tree_outlined,
                    label: 'Clusters',
                    onTap: () => go('/clusters')),
                _Tile(
                    icon: Icons.newspaper_outlined,
                    label: 'Briefing',
                    onTap: () => go('/briefing')),
                _Tile(
                    icon: Icons.search,
                    label: 'Search',
                    onTap: () => push('/search')),
                _Tile(
                    icon: Icons.bookmark_outline,
                    label: 'Saved',
                    onTap: () => push('/saved')),
                _Tile(
                    icon: Icons.insights_outlined,
                    label: 'Insights',
                    onTap: () => push('/insights')),
              ],
            ),
            const SizedBox(height: AppSpace.lg),

            // ── Personalization group.
            _Group(children: [
              _Row(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Your interests',
                  onTap: () => push('/interests')),
              _Row(
                  icon: Icons.bookmarks_outlined,
                  label: 'Watchlists',
                  onTap: () => push('/watchlists')),
              _Row(
                  icon: Icons.notifications_outlined,
                  label: 'Alerts',
                  onTap: () => push('/alerts')),
            ]),
            const SizedBox(height: AppSpace.lg),

            // ── Categories as chips (compact, modern — no endless list).
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm, 0, AppSpace.sm, AppSpace.sm),
              child: Text('CATEGORIES',
                  style: AppText.micro
                      .copyWith(color: c.textFaint, letterSpacing: 1)),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (slug, label) in kNewsCategories)
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => push(
                        '/topic/$slug?name=${Uri.encodeComponent(label)}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: c.bgInset,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(label,
                          style: AppText.caption.copyWith(color: c.text)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),

            // ── Account group.
            _Group(children: [
              _Row(
                  icon: Icons.person_outline,
                  label: 'Account',
                  onTap: () => go('/you')),
              _Row(
                  icon: Icons.gavel_outlined,
                  label: 'Sources & attribution',
                  onTap: () => push('/legal-sources')),
              if (user != null)
                _Row(
                  icon: Icons.logout,
                  label: 'Sign out',
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(authServiceProvider).signOut();
                  },
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Rounded quick-access tile: filled icon square + tiny label.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bgInset,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: c.text),
          ),
          const SizedBox(height: 5),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.micro.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

/// Rounded card grouping a few rows (Bing-style settings groups).
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i + 1 < children.length)
            Divider(height: 1, indent: 52, color: c.border),
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: 13),
        child: Row(children: [
          Icon(icon, size: 20, color: c.textSecondary),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(label, style: AppText.body.copyWith(color: c.text))),
          Icon(Icons.chevron_right, size: 18, color: c.textFaint),
        ]),
      ),
    );
  }
}
