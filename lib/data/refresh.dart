import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, Supabase;

import '../utils/remote_settings.dart';
import '../utils/source_regions.dart';
import 'api_client.dart';
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
  _lastContentRefresh = DateTime.now();
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

DateTime _lastRemoteFetch = DateTime.fromMillisecondsSinceEpoch(0);
String _lastRemoteJson = '';
String _lastUserMetaJson = '';

/// When the whole app last refetched its content. Cold start loads fresh, so
/// main() calls [markContentFresh]; thereafter every full refresh (config
/// change, auth transition, resume-staleness) updates it via [_invalidateContent].
DateTime _lastContentRefresh = DateTime.fromMillisecondsSinceEpoch(0);

/// Mark content as freshly loaded (called at cold start — the feed loads with
/// the app). Prevents the first resume from refetching needlessly.
void markContentFresh() => _lastContentRefresh = DateTime.now();

/// The Feed went stale for returning users: the backend purges articles on a
/// 12h window, but the app holds its last-loaded snapshot, so a user coming
/// back after hours/days saw stories that no longer exist (they 404 on tap)
/// — "stale feeds that never purge out" (owner report 2026-11-25). On resume,
/// if content hasn't refreshed within [maxAge], invalidate every surface so
/// the whole app refetches. Time-gated so rapid app-switching never hammers
/// egress (the backend is on a tight Supabase egress budget).
void refreshContentIfStale(
  void Function(ProviderOrFamily) invalidate, {
  Duration maxAge = const Duration(minutes: 15),
}) {
  if (DateTime.now().difference(_lastContentRefresh) < maxAge) return;
  _invalidateContent(invalidate);
}

/// Fetch + apply the Control-panel config (settings + classifier deltas).
/// Called at cold start AND every time the app returns to the foreground
/// (throttled), so admin changes land on running apps without a force-quit
/// — the panel's changes were previously only picked up at cold launch,
/// which real users almost never do. When the payload actually changed
/// since the last fetch, every content surface is invalidated so the new
/// gates/settings take effect immediately.
Future<void> fetchAndApplyRemoteConfig(
  ApiClient api, {
  void Function(ProviderOrFamily)? invalidateOnChange,
  Duration minInterval = Duration.zero,
}) async {
  if (DateTime.now().difference(_lastRemoteFetch) < minInterval) return;
  _lastRemoteFetch = DateTime.now();
  try {
    final settings = await api.appSettings();
    final sourceMap = await api.sourceMap();
    final payload = '${jsonEncode(settings)}|${jsonEncode(sourceMap)}';
    final changed = _lastRemoteJson.isNotEmpty && payload != _lastRemoteJson;
    _lastRemoteJson = payload;
    applyRemoteSettings(settings);
    applyServedSourceMap(sourceMap);
    if (changed && invalidateOnChange != null) {
      _invalidateContent(invalidateOnChange);
    }
  } catch (_) {
    // Offline / transient — current (or compiled) config stays in force.
  }
  // Preference sync ([QA-S1.3] finding 2026-08-15): a session only learns
  // about SERVER-side metadata changes (preferences saved from another
  // device / the API) on token refresh — up to an hour stale. Refresh the
  // session here (launch + resume) and re-shape all content the moment
  // the account's preferences actually changed.
  try {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) {
      final res = await auth.refreshSession();
      final metaJson = jsonEncode(res.user?.userMetadata ?? const {});
      final changed =
          _lastUserMetaJson.isNotEmpty && metaJson != _lastUserMetaJson;
      _lastUserMetaJson = metaJson;
      if (changed && invalidateOnChange != null) {
        _invalidateContent(invalidateOnChange);
      }
    }
  } catch (_) {
    // Offline — the stored session's preferences stay in force.
  }
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
