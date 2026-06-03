import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/sign_in_page.dart';
import 'features/discover/cluster_detail_page.dart';
import 'features/discover/discover_page.dart';
import 'features/discover/topic_page.dart';
import 'features/feed/home_page.dart';
import 'features/shell/placeholder_page.dart';
import 'features/shell/scaffold_with_nav.dart';
import 'features/you/you_page.dart';

/// App routes: a 5-tab stateful shell (Home · Discover · Watch · Saved · You).
/// Detail routes (/cluster/:id, /topic/:slug) and /sign-in land in follow-ups.
final router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, __) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/discover', builder: (_, __) => const DiscoverPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/watch',
              builder: (_, __) => const PlaceholderPage(
                icon: Icons.play_circle_outline,
                title: 'Watch',
                subtitle:
                    'A swipeable video feed — inline players, link-out for the rest.',
                phase: 'LATER',
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/saved',
              builder: (_, __) => const PlaceholderPage(
                icon: Icons.bookmark_outline,
                title: 'Saved',
                subtitle:
                    'Bookmarks, watchlists, and history — available offline.',
                phase: 'LATER',
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/you', builder: (_, __) => const YouPage()),
          ],
        ),
      ],
    ),
    GoRoute(path: '/sign-in', builder: (_, __) => const SignInPage()),
    GoRoute(
      path: '/cluster/:id',
      builder: (_, s) => ClusterDetailPage(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/topic/:slug',
      builder: (_, s) => TopicPage(
        slug: s.pathParameters['slug']!,
        name: s.uri.queryParameters['name'],
      ),
    ),
  ],
);
