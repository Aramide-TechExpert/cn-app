import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/article.dart';
import '../utils/interleave.dart';
import '../utils/source_regions.dart';
import 'api_client.dart';
import 'auth_controller.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Strict preference shaping for any article list: national outlets from
/// other regions are DROPPED (a US-preference user never sees a Philippine
/// national outlet), then the kept articles are tiered — user's country
/// first, their region, global desks, topical verticals — ahead of the
/// source interleave.
List<Article> applyRegionPreference(Ref ref, List<Article> items) =>
    shapeArticlesForUser(items,
        meta: ref.read(currentUserProvider)?.userMetadata);

/// Home feed: keyset-cursor infinite list over `/api/v1/feed`. The cursor +
/// has-more flags live on the notifier; the public state is the article list.
/// Every page is source-interleaved (one source at a time) with the surplus
/// of burst-posting publishers deferred into the next page's mix.
final feedControllerProvider =
    AsyncNotifierProvider<FeedController, List<Article>>(FeedController.new);

class FeedController extends AsyncNotifier<List<Article>> {
  String? _cursor;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _since; // '1h'|'24h'|'7d', null = any time (Home time filter)
  List<Article> _deferred = const [];

  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  String? get since => _since;

  /// Fetch pages until at least [minVisible] stories survive the strict
  /// source gate (or the corpus ends). Feeds are newest-first and ingestion
  /// bursts make whole pages one or two publishers, so a single gated page
  /// can come back empty. Bounded hops keep a worst-case refresh cheap.
  Future<List<Article>> _collect({
    String? cursor,
    required int limit,
    required int minVisible,
  }) async {
    final collected = <Article>[];
    var next = cursor;
    // Server-side region pre-filter (defense in depth + denser pages);
    // the strict per-country gate still applies client-side.
    final region =
        activeSegment(ref.read(currentUserProvider)?.userMetadata);
    for (var hop = 0; hop < 5; hop++) {
      final page = await ref
          .read(apiClientProvider)
          .feed(cursor: next, limit: limit, since: _since, region: region);
      next = page.nextCursor;
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null;
      collected.addAll(page.items);
      if (!_hasMore) break;
      if (applyRegionPreference(ref, collected).length >= minVisible) break;
    }
    return collected;
  }

  Future<List<Article>> _firstPage() async {
    _deferred = const [];
    // Larger first page so Home can fill hero + rail + bento + latest.
    final items = await _collect(limit: 24, minVisible: 12);
    final r = interleaveBySource(applyRegionPreference(ref, items),
        flush: !_hasMore);
    _deferred = r.deferred;
    return r.emitted;
  }

  @override
  Future<List<Article>> build() => _firstPage();

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final items =
          await _collect(cursor: _cursor, limit: 12, minVisible: 6);
      final r = interleaveBySource(
          applyRegionPreference(ref, [..._deferred, ...items]),
          flush: !_hasMore);
      _deferred = r.deferred;
      state = AsyncData([...(state.value ?? const []), ...r.emitted]);
    } catch (_) {
      // keep current list; a later scroll retries
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    state = await AsyncValue.guard(_firstPage);
  }

  /// Home time filter — refetches the feed with the new lower bound.
  Future<void> setSince(String? since) async {
    if (_since == since) return;
    _since = since;
    _cursor = null;
    _hasMore = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_firstPage);
  }
}
