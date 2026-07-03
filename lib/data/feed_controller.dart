import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/article.dart';
import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Home feed: keyset-cursor infinite list over `/api/v1/feed`. The cursor +
/// has-more flags live on the notifier; the public state is the article list.
final feedControllerProvider =
    AsyncNotifierProvider<FeedController, List<Article>>(FeedController.new);

class FeedController extends AsyncNotifier<List<Article>> {
  String? _cursor;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _since; // '1h'|'24h'|'7d', null = any time (Home time filter)

  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  String? get since => _since;

  @override
  Future<List<Article>> build() async {
    // Larger first page so Home can fill hero + rail + bento + latest.
    final page =
        await ref.read(apiClientProvider).feed(limit: 24, since: _since);
    _cursor = page.nextCursor;
    _hasMore = page.nextCursor != null;
    return page.items;
  }

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
      state = AsyncData([...(state.value ?? const []), ...page.items]);
    } catch (_) {
      // keep current list; a later scroll retries
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    state = await AsyncValue.guard(() async {
      final page =
          await ref.read(apiClientProvider).feed(limit: 24, since: _since);
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null;
      return page.items;
    });
  }

  /// Home time filter — refetches the feed with the new lower bound.
  Future<void> setSince(String? since) async {
    if (_since == since) return;
    _since = since;
    _cursor = null;
    _hasMore = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page =
          await ref.read(apiClientProvider).feed(limit: 24, since: _since);
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null;
      return page.items;
    });
  }
}
