import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import 'feed_controller.dart' show apiClientProvider;

/// Active filters for the News Feed (Discover). Mirrors the web feed filter bar:
/// category, sort, and impact level. Null = "All".
class NewsFilters {
  const NewsFilters(
      {this.category, this.sort = 'latest', this.impact, this.video = false});
  final String? category; // slug, null = all
  final String sort; // 'latest' | 'trending'
  final String? impact; // 'Critical'|'High'|'Medium'|'Low', null = all
  final bool video; // true = only articles with a playable video

  NewsFilters copyWith({
    Object? category = _unset,
    String? sort,
    Object? impact = _unset,
    bool? video,
  }) {
    return NewsFilters(
      category: category == _unset ? this.category : category as String?,
      sort: sort ?? this.sort,
      impact: impact == _unset ? this.impact : impact as String?,
      video: video ?? this.video,
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

  NewsFilters get filters => _filters;
  bool get hasMore => _hasMore;

  bool _passesImpact(Article a) =>
      _filters.impact == null || a.impact == _filters.impact;

  Future<List<Article>> _fetch({String? cursor}) async {
    final page = await ref.read(apiClientProvider).feed(
          cursor: cursor,
          limit: 20,
          category: _filters.category,
          sort: _filters.sort == 'latest' ? null : _filters.sort,
          video: _filters.video,
        );
    _cursor = page.nextCursor;
    _hasMore = page.nextCursor != null;
    return page.items.where(_passesImpact).toList();
  }

  @override
  Future<List<Article>> build() => _fetch();

  Future<void> setFilters(NewsFilters next) async {
    _filters = next;
    _cursor = null;
    _hasMore = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
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
