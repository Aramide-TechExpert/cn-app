import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import 'auth_controller.dart';
import 'discover_controller.dart';
import 'feed_controller.dart';
import 'news_feed_controller.dart';
import 'personalization_controller.dart';
import 'search_controller.dart';

/// Invalidate every content surface so the whole app refetches and reshapes
/// to the CURRENT preferences (region segment, Africa gate, sources): Home,
/// News Feed, Reel/Shorts, source picker, For You + What you missed,
/// Clusters, Briefing, trending, topic pages, search.
void _invalidateContent(void Function(ProviderOrFamily) invalidate) {
  invalidate(feedControllerProvider); // Home + Reel (stack feed)
  invalidate(newsFeedControllerProvider); // News Feed (filters reset too)
  invalidate(videoPoolProvider); // Shorts rail
  invalidate(sourcesProvider); // source picker (Africa gate)
  invalidate(forYouFeedProvider); // For You → cascades to What you missed
  invalidate(clustersProvider); // Clusters page (shaped per user)
  invalidate(statsProvider);
  invalidate(widgetsDataProvider);
  invalidate(briefingProvider);
  invalidate(trendingProvider);
  invalidate(topicFeedProvider); // every open topic page
  invalidate(searchResultsProvider);
}

/// Watched once from the app root. Fires the full content refresh on every
/// auth transition — preference/profile saves (userUpdated), sign in, sign
/// out — so finishing the setup wizard or editing preferences in Settings
/// re-arranges the entire app in real time, no manual pull-to-refresh.
final preferenceRefreshListener = Provider<void>((ref) {
  ref.listen(authStateProvider, (prev, next) {
    final event = next.valueOrNull?.event;
    if (event == AuthChangeEvent.userUpdated ||
        event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.signedOut) {
      _invalidateContent(ref.invalidate);
    }
  });
});
