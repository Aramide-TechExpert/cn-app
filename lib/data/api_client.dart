import 'package:dio/dio.dart';
import '../config.dart';
import '../models/article.dart';
import '../models/briefing.dart';
import '../models/cluster.dart';
import '../models/stats.dart';
import '../models/widgets_data.dart';

/// Typed client for the Cluster News mobile backend (`/api/v1`) — channel 2 of the
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
    // User's news segment — the server pre-filters to that region's
    // sources + globals in SQL, so pages arrive dense instead of mostly
    // dropped by the client gate (which still applies for exact country).
    String? region,
    // MULTI/cross-region preference: every selected segment — the server
    // returns the UNION (+ globals). Wins over [region] when non-empty.
    List<String>? regions,
    // STRICT favorites: pages arrive favorites-only from the server (the
    // client gate stays as the enforcement backstop).
    List<String>? sources,
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
        if (regions != null && regions.isNotEmpty)
          'regions': regions.join(',')
        else if (region != null)
          'region': region,
        if (sources != null && sources.isNotEmpty)
          'sources': sources.join(','),
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
  Future<List<String>> sources({int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>('/sources',
        queryParameters: {'limit': limit});
    final list = (res.data?['sources'] as List?) ?? const [];
    return list
        .map((e) => (e as Map<String, dynamic>)['source']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// The FULL ingest roster (every publisher Cluster News carries), not just the
  /// sources currently in the corpus — for pickers like "Favorite your
  /// publishers" that must offer a location's complete roster.
  Future<List<String>> publishers() async {
    final res = await _dio.get<Map<String, dynamic>>('/publishers');
    final list = (res.data?['publishers'] as List?) ?? const [];
    return list.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  /// Classifier deltas from the Control panel (custom sources, region
  /// re-tags, flagship forces) — merged over the built-in gate at startup.
  Future<Map<String, dynamic>> sourceMap() async {
    final res = await _dio.get<Map<String, dynamic>>('/source-map');
    return res.data ?? const {};
  }

  /// Remote product settings (feature switches, feed composition) from the
  /// Control panel — merged over compiled defaults at startup.
  Future<Map<String, dynamic>> appSettings() async {
    final res = await _dio.get<Map<String, dynamic>>('/app-settings');
    return res.data ?? const {};
  }

  /// Fire-and-forget launch ping so the Control panel can see which app
  /// versions are actually in the field before tightening the min-version
  /// gate. Never surfaces an error.
  Future<void> reportVersion(String version, String platform) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/telemetry/version',
        data: {'v': version, 'platform': platform},
      );
    } catch (_) {
      // Telemetry is best-effort.
    }
  }

  /// Latest daily briefing for a region edition (server falls back to
  /// Worldwide when that region has none yet).
  Future<DailyBriefing?> briefing({String? region}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/briefing',
      queryParameters: {
        if (region != null && region.isNotEmpty) 'region': region,
      },
    );
    final b = res.data?['briefing'];
    return b == null ? null : DailyBriefing.fromJson(b as Map<String, dynamic>);
  }

  Future<List<TrendingTopic>> trending({String? region}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/right-rail',
      queryParameters: {
        if (region != null && region.isNotEmpty) 'region': region,
      },
    );
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
  /// [sources]/[regions] push the user's strict favorites + scopes into the
  /// server so pages arrive pre-filtered (For You rail).
  Future<List<Article>> categoryFeed(String slug,
      {int limit = 20, List<String>? sources, List<String>? regions}) async {
    final page = await feed(
        category: slug, limit: limit, sources: sources, regions: regions);
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
