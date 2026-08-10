import 'package:go_router/go_router.dart';

import 'utils/remote_settings.dart';
import 'features/alerts/alerts_page.dart';
import 'features/auth/sign_in_page.dart';
import 'features/briefing/briefing_page.dart';
import 'features/clusters/clusters_page.dart';
import 'features/discover/cluster_detail_page.dart';
import 'features/discover/discover_page.dart';
import 'features/discover/topic_page.dart';
import 'features/feed/home_page.dart';
import 'features/feed/stack_feed_page.dart';
import 'features/insights/insights_page.dart';
import 'features/legal/legal_sources_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/onboarding/setup_flow_page.dart';
import 'features/personalization/interests_page.dart';
import 'features/personalization/watchlists_page.dart';
import 'features/saved/saved_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/settings_page.dart';
import 'features/shell/scaffold_with_nav.dart';
import 'features/you/you_page.dart';

/// App routes: a 5-tab stateful shell (Home · News Feed · Clusters · Briefing ·
/// You). Saved, Search, Insights and detail screens are pushed on top.
final router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNav(navigationShell: navigationShell),
      // Footer order: Home · Feed · Reel (center) · Clusters · Briefing.
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
            GoRoute(path: '/stack', builder: (_, __) => const StackFeedPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
                path: '/clusters',
                // Remote kill switch is strict: the route itself is gated,
                // not just the drawer link (deep links included).
                redirect: (_, __) => remote.clusters ? null : '/',
                builder: (_, __) => const ClustersPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/briefing', builder: (_, __) => const BriefingPage()),
          ],
        ),
      ],
    ),
    GoRoute(path: '/sign-in', builder: (_, __) => const SignInPage()),
    GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
    GoRoute(path: '/saved', builder: (_, __) => const SavedPage()),
    GoRoute(path: '/insights', builder: (_, __) => const InsightsPage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    // You / account — reachable from the drawer, no longer a footer tab.
    GoRoute(path: '/you', builder: (_, __) => const YouPage()),
    GoRoute(path: '/interests', builder: (_, __) => const InterestsPage()),
    GoRoute(path: '/watchlists', builder: (_, __) => const WatchlistsPage()),
    GoRoute(path: '/alerts', builder: (_, __) => const AlertsPage()),
    GoRoute(
        path: '/legal-sources',
        builder: (_, __) => const LegalSourcesPage()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
    GoRoute(
      path: '/setup',
      builder: (_, s) =>
          SetupFlowPage(edit: s.uri.queryParameters['edit'] == '1'),
    ),
    GoRoute(
      path: '/cluster/:id',
      redirect: (_, __) => remote.clusters ? null : '/',
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
