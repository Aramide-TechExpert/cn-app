import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../utils/interleave.dart';
import '../utils/source_regions.dart';
import 'auth_controller.dart';
import 'feed_controller.dart' show apiClientProvider, applyRegionPreference;

/// A small pool of playable news videos used for the Shorts rail + Reel.
/// Source-interleaved so one publisher's clips don't fill the whole rail.
/// Fetches deep (the strict gate + playability checks both thin the pool).
final videoPoolProvider = FutureProvider.autoDispose<List<Article>>((ref) async {
  final page = await ref.read(apiClientProvider).feed(limit: 24, video: true);
  final playable = applyRegionPreference(
      ref, page.items.where((a) => a.hasPlayableVideo && a.hasImage).toList());
  return interleaveBySource(playable, flush: true).emitted;
});

/// Distinct source names for the News Feed source picker (most frequent
/// first). Strictly gated: other regions' national outlets never appear.
final sourcesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final names = await ref.read(apiClientProvider).sources();
  final meta = ref.read(currentUserProvider)?.userMetadata;
  return names.where((s) => sourceVisible(s, meta)).toList();
});

/// Active filters for the News Feed (Discover). Mirrors the web feed filter bar:
/// category, sort, and impact level. Null = "All".
class NewsFilters {
  const NewsFilters(
      {this.category,
      this.sort = 'latest',
      this.impact,
      this.video = false,
      this.source,
      this.since});
  final String? category; // slug, null = all
  final String sort; // 'latest' | 'trending'
  final String? impact; // 'Critical'|'High'|'Medium'|'Low', null = all
  final bool video; // true = only articles with a playable video
  final String? source; // exact source name, null = all
  final String? since; // '1h'|'24h'|'7d', null = any time

  NewsFilters copyWith({
    Object? category = _unset,
    String? sort,
    Object? impact = _unset,
    bool? video,
    Object? source = _unset,
    Object? since = _unset,
  }) {
    return NewsFilters(
      category: category == _unset ? this.category : category as String?,
      sort: sort ?? this.sort,
      impact: impact == _unset ? this.impact : impact as String?,
      video: video ?? this.video,
      source: source == _unset ? this.source : source as String?,
      since: since == _unset ? this.since : since as String?,
    );
  }

  static const _unset = Object();
}

/// Cursor-paginated, filterable feed over `/api/v1/feed`. Category + sort go to
/// the API; impact is filtered client-side (no API param yet).
final newsFeedControllerProvider =
    AsyncNotifierProvider<NewsFeedController, List<Article>>(
        NewsFeedController.new);

class NewsFeedController extends AsyncNotifier<List<Article>> {
  NewsFilters _filters = const NewsFilters();
  String? _cursor;
  bool _hasMore = true;
  bool _loadingMore = false;
  List<Article> _deferred = const [];

  NewsFilters get filters => _filters;
  bool get hasMore => _hasMore;

  bool _passesImpact(Article a) =>
      _filters.impact == null || a.impact == _filters.impact;

  Future<List<Article>> _fetch({String? cursor}) async {
    final meta = ref.read(currentUserProvider)?.userMetadata;
    final collected = <Article>[];
    var next = cursor;
    // The strict source gate can wipe out entire pages (feeds are newest-
    // first, and ingestion bursts make whole pages one or two publishers),
    // so keep pulling until enough VISIBLE stories accumulate or the
    // corpus ends. Bounded hops keep a worst-case refresh cheap.
    for (var hop = 0; hop < 5; hop++) {
      final page = await ref.read(apiClientProvider).feed(
            cursor: next,
            limit: 20,
            category: _filters.category,
            source: _filters.source,
            sort: _filters.sort == 'latest' ? null : _filters.sort,
            since: _filters.since,
            video: _filters.video,
          );
      next = page.nextCursor;
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null;
      collected.addAll(page.items.where(_passesImpact));
      if (_filters.source != null || !_hasMore) break;
      if (gateSourcesForUser(collected, meta: meta).length >= 8) break;
    }
    // One source at a time — except in the single-source filter view, where
    // interleaving is meaningless and deferral would starve the list. The
    // strict gate still applies (the picker hides gated sources anyway).
    if (_filters.source != null) {
      return gateSourcesForUser(collected, meta: meta);
    }
    final r = interleaveBySource(
        applyRegionPreference(ref, [..._deferred, ...collected]),
        flush: !_hasMore);
    _deferred = r.deferred;
    return r.emitted;
  }

  @override
  Future<List<Article>> build() {
    _deferred = const [];
    return _fetch();
  }

  Future<void> setFilters(NewsFilters next) async {
    _filters = next;
    _cursor = null;
    _hasMore = true;
    _deferred = const [];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    _deferred = const [];
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final more = await _fetch(cursor: _cursor);
      state = AsyncData([...(state.value ?? const []), ...more]);
    } catch (_) {
      // keep current list; a later scroll retries
    } finally {
      _loadingMore = false;
    }
  }
}
