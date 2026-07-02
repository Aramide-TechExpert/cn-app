import 'package:dio/dio.dart';
import '../config.dart';
import '../models/article.dart';
import '../models/briefing.dart';
import '../models/cluster.dart';
import '../models/stats.dart';
import '../models/widgets_data.dart';

/// Typed client for the Clustez mobile backend (`/api/v1`) — channel 2 of the
/// hybrid model (public feed + secret-backed aggregates). User-owned writes go
/// direct to Supabase elsewhere.
class ApiClient {
  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Config.apiBase,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ));

  final Dio _dio;

  Future<FeedPage> feed({
    String? cursor,
    int limit = 12,
    String? category,
    String? source,
    String? sort,
    String? since,
    bool video = false,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/feed',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
        if (category != null) 'category': category,
        if (source != null) 'source': source,
        if (sort != null) 'sort': sort,
        if (since != null) 'since': since,
        if (video) 'video': '1',
      },
    );
    return FeedPage.fromJson(res.data ?? const {});
  }

  Future<Article?> article(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/articles/$id');
    final data = res.data?['article'];
    return data == null ? null : Article.fromJson(data as Map<String, dynamic>);
  }

  Future<List<StoryCluster>> clusters() async {
    final res = await _dio.get<Map<String, dynamic>>('/clusters');
    final list = (res.data?['clusters'] as List?) ?? const [];
    return list
        .map((e) => StoryCluster.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClusterDetail?> cluster(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/clusters/$id');
    final data = res.data;
    if (data == null || data['cluster'] == null) return null;
    final articles = (data['articles'] as List?) ?? const [];
    return ClusterDetail(
      cluster: StoryCluster.fromJson(data['cluster'] as Map<String, dynamic>),
      articles: articles
          .map((e) => Article.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<WidgetsData> widgets() async {
    final res = await _dio.get<Map<String, dynamic>>('/widgets');
    return WidgetsData.fromJson(res.data ?? const {});
  }

  Future<CorpusStats> stats() async {
    final res = await _dio.get<Map<String, dynamic>>('/stats');
    return CorpusStats.fromJson(
        (res.data?['stats'] as Map<String, dynamic>?) ?? const {});
  }

  /// Distinct article source names, most frequent first — for the News Feed
  /// source picker. Pairs with feed(source: ...).
  Future<List<String>> sources({int limit = 40}) async {
    final res = await _dio.get<Map<String, dynamic>>('/sources',
        queryParameters: {'limit': limit});
    final list = (res.data?['sources'] as List?) ?? const [];
    return list
        .map((e) => (e as Map<String, dynamic>)['source']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<DailyBriefing?> briefing() async {
    final res = await _dio.get<Map<String, dynamic>>('/briefing');
    final b = res.data?['briefing'];
    return b == null ? null : DailyBriefing.fromJson(b as Map<String, dynamic>);
  }

  Future<List<TrendingTopic>> trending() async {
    final res = await _dio.get<Map<String, dynamic>>('/right-rail');
    final list = (res.data?['trending'] as List?) ?? const [];
    return list
        .map((e) => TrendingTopic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Full-text search. Empty for queries under 2 chars.
  Future<List<Article>> search(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final res = await _dio.get<Map<String, dynamic>>(
      '/search',
      queryParameters: {'q': q, 'limit': limit},
    );
    final list = (res.data?['results'] as List?) ?? const [];
    return list
        .map((e) => Article.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// One page of a category feed (used by the topic screen). No cursor yet.
  Future<List<Article>> categoryFeed(String slug, {int limit = 20}) async {
    final page = await feed(category: slug, limit: limit);
    return page.items;
  }

  /// Batch fetch by DB uuid (used by Saved) — one request for all bookmarks.
  Future<List<Article>> articlesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final res = await _dio.get<Map<String, dynamic>>(
      '/articles',
      queryParameters: {'ids': ids.join(',')},
    );
    final list = (res.data?['articles'] as List?) ?? const [];
    return list
        .map((e) => Article.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
