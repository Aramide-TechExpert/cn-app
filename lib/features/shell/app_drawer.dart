import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../data/source_signals.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';

/// The app-wide side menu (mirrors the web sidebar): primary nav, tools,
/// categories, and account. Opened from the menu button on every tab.
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
      backgroundColor: c.bgElevated,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Brand + account header.
            Container(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      color: c.brand,
                      child: Text('C',
                          style: AppText.headline.copyWith(color: c.onBrand)),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Text('Clustez',
                        style: AppText.title.copyWith(color: c.text)),
                  ]),
                  const SizedBox(height: AppSpace.lg),
                  if (user != null)
                    Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: HSLColor.fromAHSL(
                                1, hueFromString(email).toDouble(), 0.55, 0.45)
                            .toColor(),
                        child: Text(initialOf(email),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(color: c.textSecondary)),
                      ),
                    ])
                  else
                    FilledButton(
                      onPressed: () => push('/sign-in'),
                      style: FilledButton.styleFrom(
                        backgroundColor: c.brand,
                        minimumSize: const Size.fromHeight(42),
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: const Text('Sign in'),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),

            // Primary nav (tabs).
            _Item(icon: Icons.home_outlined, label: 'Home', onTap: () => go('/')),
            _Item(
                icon: Icons.dynamic_feed_outlined,
                label: 'News Feed',
                onTap: () => go('/discover')),
            _Item(
                icon: Icons.account_tree_outlined,
                label: 'Clusters',
                onTap: () => go('/clusters')),
            _Item(
                icon: Icons.newspaper_outlined,
                label: 'Briefing',
                onTap: () => go('/briefing')),
            Divider(height: 1, color: c.border),

            // Tools.
            _Item(
                icon: Icons.search,
                label: 'Search',
                onTap: () => push('/search')),
            _Item(
                icon: Icons.insights_outlined,
                label: 'Insights',
                onTap: () => push('/insights')),
            _Item(
                icon: Icons.bookmark_outline,
                label: 'Saved',
                onTap: () => push('/saved')),
            Divider(height: 1, color: c.border),

            // Categories.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
              child: Text('CATEGORIES',
                  style: AppText.micro.copyWith(color: c.textFaint)),
            ),
            for (final (slug, label) in kNewsCategories)
              _Item(
                icon: Icons.label_outline,
                label: label,
                dense: true,
                onTap: () =>
                    push('/topic/$slug?name=${Uri.encodeComponent(label)}'),
              ),
            Divider(height: 1, color: c.border),

            // Account.
            _Item(
                icon: Icons.person_outline,
                label: 'Account',
                onTap: () => go('/you')),
            if (user != null)
              _Item(
                icon: Icons.logout,
                label: 'Sign out',
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authServiceProvider).signOut();
                },
              ),
            const SizedBox(height: AppSpace.lg),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dense = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      dense: dense,
      leading: Icon(icon, size: 20, color: c.textSecondary),
      title: Text(label, style: AppText.body.copyWith(color: c.text)),
      onTap: onTap,
    );
  }
}
