import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';

/// The five footer tabs — the SINGLE source of truth for the bottom bar.
/// Both the real shell ([ScaffoldWithNav]) and the push-landing templates
/// ([LandingBottomNav]) render from this list so they can never diverge.
const List<NavigationDestination> kAppNavDestinations = [
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.dynamic_feed_outlined),
    selectedIcon: Icon(Icons.dynamic_feed),
    label: 'Feed',
  ),
  NavigationDestination(
    icon: Icon(Icons.auto_stories_outlined),
    selectedIcon: Icon(Icons.auto_stories),
    label: 'Reel',
  ),
  NavigationDestination(
    icon: Icon(Icons.account_tree_outlined),
    selectedIcon: Icon(Icons.account_tree),
    label: 'Clusters',
  ),
  NavigationDestination(
    icon: Icon(Icons.newspaper_outlined),
    selectedIcon: Icon(Icons.newspaper),
    label: 'Briefing',
  ),
];

/// Tab index → shell route. Kept in lockstep with [kAppNavDestinations].
const List<String> kAppNavRoutes = [
  '/', // Home
  '/discover', // Feed
  '/stack', // Reel
  '/clusters', // Clusters
  '/briefing', // Briefing
];

/// Footer bar for the push-landing templates (StoryPage / DigestPage). The
/// landings are TOP-LEVEL routes (outside the shell) so they can never stack
/// on the Feed branch and break the Feed tab — but the owner wants the footer
/// visible on them (2026-11-25). This renders the same five tabs and drives
/// the shell with `context.go`, so tapping a tab jumps straight to that real
/// shell tab. No tab is "current" on a landing, so [highlight] just picks
/// which icon reads as active (Feed by default — a pushed story is feed
/// content).
class LandingBottomNav extends StatelessWidget {
  const LandingBottomNav({super.key, this.highlight = 1});

  final int highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NavigationBar(
      selectedIndex: highlight,
      onDestinationSelected: (i) => context.go(kAppNavRoutes[i]),
      backgroundColor: c.bgElevated,
      destinations: kAppNavDestinations,
    );
  }
}
