import 'package:dio/dio.dart';
import '../config.dart';
import '../models/article.dart';

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
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/feed',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
        if (category != null) 'category': category,
        if (source != null) 'source': source,
        if (sort != null) 'sort': sort,
      },
    );
    return FeedPage.fromJson(res.data ?? const {});
  }

  Future<Article?> article(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/articles/$id');
    final data = res.data?['article'];
    return data == null ? null : Article.fromJson(data as Map<String, dynamic>);
  }
}
