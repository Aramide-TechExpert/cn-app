import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/article.dart';
import '../utils/interleave.dart';
import '../utils/source_regions.dart';
import 'api_client.dart';
import 'auth_controller.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// When the signed-in user picked "My country & region first" in setup,
/// lead each page with their local and regional outlets (stable partition
/// ahead of the source interleave). Worldwide scope or signed-out: unchanged.
List<Article> applyRegionPreference(Ref ref, List<Article> items) {
  final meta = ref.read(currentUserProvider)?.userMetadata;
  if (meta?['news_scope'] != 'region') return items;
  return regionFirst(
    items,
    country: meta?['preferred_country'] as String?,
    region: meta?['preferred_region'] as String?,
  );
}

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

  Future<List<Article>> _firstPage() async {
    _deferred = const [];
    // Larger first page so Home can fill hero + rail + bento + latest.
    final page =
        await ref.read(apiClientProvider).feed(limit: 24, since: _since);
    _cursor = page.nextCursor;
    _hasMore = page.nextCursor != null;
    final r = interleaveBySource(applyRegionPreference(ref, page.items),
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
      final page = await ref.read(apiClientProvider).feed(
            cursor: _cursor,
            limit: 12,
            since: _since,
          );
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null;
      final r = interleaveBySource(
          applyRegionPreference(ref, [..._deferred, ...page.items]),
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
