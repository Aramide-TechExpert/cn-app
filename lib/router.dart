import 'package:go_router/go_router.dart';

import 'features/auth/sign_in_page.dart';
import 'features/briefing/briefing_page.dart';
import 'features/discover/cluster_detail_page.dart';
import 'features/discover/discover_page.dart';
import 'features/discover/topic_page.dart';
import 'features/feed/home_page.dart';
import 'features/insights/insights_page.dart';
import 'features/saved/saved_page.dart';
import 'features/search/search_page.dart';
import 'features/shell/scaffold_with_nav.dart';
import 'features/watch/watch_page.dart';
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
            GoRoute(path: '/watch', builder: (_, __) => const WatchPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/saved', builder: (_, __) => const SavedPage()),
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
    GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
    GoRoute(path: '/briefing', builder: (_, __) => const BriefingPage()),
    GoRoute(path: '/insights', builder: (_, __) => const InsightsPage()),
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
