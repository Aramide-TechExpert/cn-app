import 'dart:async' show StreamSubscription;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
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
import 'features/story/digest_page.dart';
import 'features/story/story_page.dart';

/// Re-runs the router's redirect on every auth event (sign-in, sign-out,
/// metadata updates like setup_complete) so the setup gate reacts live.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    if (Config.hasSupabase) {
      _sub = Supabase.instance.client.auth.onAuthStateChange
          .listen((_) => notifyListeners());
    }
  }
  StreamSubscription<AuthState>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// App routes: a 5-tab stateful shell (Home · News Feed · Clusters · Briefing ·
/// You). Saved, Search, Insights and detail screens are pushed on top.
final router = GoRouter(
  initialLocation: '/',
  refreshListenable: _AuthRefresh(),
  // HARD setup gate (owner 2026-10-19: "all signup should be strictly gated
  // to user flow and preferences — it's a must"): any signed-in account that
  // hasn't finished the setup wizard is routed there no matter how the
  // session arrived (fresh signup, email-confirm relaunch, account switch,
  // deep link). The sign-in page's own redirect stays as the fast path.
  redirect: (_, state) {
    if (!Config.hasSupabase) return null;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    if (user.userMetadata?['setup_complete'] == true) return null;
    final loc = state.matchedLocation;
    const allowed = ['/setup', '/sign-in', '/onboarding', '/legal-sources'];
    if (allowed.any(loc.startsWith)) return null;
    return '/setup';
  },
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
            // Digest/Fresh-stories lands INSIDE the Feed branch so the app
            // footer menu stays visible (owner 2026-10-27) — push() stacks it
            // over /discover, so back pops to the Feed tab.
            GoRoute(
              path: '/digest',
              builder: (_, s) =>
                  DigestPage(ids: s.uri.queryParameters['ids'] ?? ''),
            ),
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
      path: '/story/:id',
      builder: (_, s) => StoryPage(
        id: s.pathParameters['id']!,
        fallbackLink: s.uri.queryParameters['link'],
      ),
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
