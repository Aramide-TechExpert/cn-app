import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';

/// Bottom-tab shell host for the 5-tab IA. Driven by go_router's
/// [StatefulNavigationShell] so each tab keeps its own navigation stack.
class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The Reel (center, index 2) is a full-screen swiper — hide the footer so
    // it runs edge to edge. Its own close button returns to Home.
    final onReel = navigationShell.currentIndex == 2;
    return Scaffold(
      extendBody: onReel,
      body: navigationShell,
      bottomNavigationBar: onReel
          ? null
          : NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        backgroundColor: c.bgElevated,
        destinations: const [
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
          // Center: the full-screen "reel/stack" swiper.
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
        ],
      ),
    );
  }
}
