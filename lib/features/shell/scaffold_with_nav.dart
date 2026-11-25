import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import 'app_bottom_nav.dart';

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
        // Shared with the push-landing footer (app_bottom_nav.dart) so the two
        // bars can never diverge.
        destinations: kAppNavDestinations,
      ),
    );
  }
}
