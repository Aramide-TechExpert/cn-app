import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import 'auth_controller.dart';

/// One alert row (`user_alerts`): a watchlist match the `match` cron produced.
/// The app reads + marks them; it never creates them.
class AlertItem {
  const AlertItem({
    required this.id,
    required this.status,
    required this.triggeredAt,
    required this.watchlistName,
    required this.article,
  });
  final String id;
  final String status; // 'unread' | 'read'
  final String triggeredAt;
  final String watchlistName;
  final Article article;

  bool get unread => status == 'unread';
}

/// Builds an Article from a snake_case `articles` DB row (the join returns DB
/// columns, not the camelCase /api/v1 shape, so Article.fromJson can't be used).
Article _articleFromRow(Map<String, dynamic> r) => Article(
      id: (r['external_id'] ?? r['id'] ?? '').toString(),
      dbId: r['id'] as String?,
      title: (r['title'] ?? '').toString(),
      excerpt: (r['excerpt'] ?? '').toString(),
      image: (r['image'] ?? '').toString(),
      source: (r['source'] ?? '').toString(),
      sourceUrl: r['source_url'] as String?,
      publishedAt: (r['published_at'] ?? '').toString(),
      readingMinutes: (r['reading_minutes'] as num?)?.toInt() ?? 0,
      categories: ((r['article_categories'] as List?) ?? const [])
          .map((c) => (c as Map)['category_slug'].toString())
          .toList(),
      impact: (r['impact'] ?? 'Low').toString(),
      isBreaking: r['is_breaking'] == true,
      topics: const [],
      likeCount: 0,
      commentCount: 0,
    );

const _alertSelect =
    'id, status, triggered_at, watchlist:watchlists(name), '
    'article:articles(id, external_id, title, excerpt, image, source, source_url, '
    'published_at, reading_minutes, impact, is_breaking, '
    'article_categories(category_slug))';

final alertsControllerProvider =
    AsyncNotifierProvider<AlertsController, List<AlertItem>>(
        AlertsController.new);

class AlertsController extends AsyncNotifier<List<AlertItem>> {
  @override
  Future<List<AlertItem>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];
    final rows = await ref
        .read(supabaseProvider)
        .from('user_alerts')
        .select(_alertSelect)
        .eq('user_id', user.id)
        .order('triggered_at', ascending: false)
        .limit(80);
    final out = <AlertItem>[];
    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      final art = m['article'];
      if (art == null) continue; // article purged
      out.add(AlertItem(
        id: m['id'] as String,
        status: (m['status'] ?? 'unread') as String,
        triggeredAt: (m['triggered_at'] ?? '') as String,
        watchlistName:
            (m['watchlist']?['name'] as String?) ?? '(deleted watchlist)',
        article: _articleFromRow(art as Map<String, dynamic>),
      ));
    }
    // Onboarding preference enforced (was saved but never consumed):
    // "high-impact only" keeps Critical/High/breaking alerts and drops
    // the rest. (alerts_breaking is reserved for push notifications.)
    if (user.userMetadata?['alerts_high_impact_only'] == true) {
      return out
          .where((a) =>
              a.article.isBreaking ||
              a.article.impact == 'Critical' ||
              a.article.impact == 'High')
          .toList();
    }
    return out;
  }

  int get unreadCount =>
      (state.value ?? const []).where((a) => a.unread).length;

  Future<void> markRead(String id) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    // Optimistic.
    state = AsyncData([
      for (final a in state.value ?? const <AlertItem>[])
        a.id == id
            ? AlertItem(
                id: a.id,
                status: 'read',
                triggeredAt: a.triggeredAt,
                watchlistName: a.watchlistName,
                article: a.article)
            : a
    ]);
    try {
      await ref
          .read(supabaseProvider)
          .from('user_alerts')
          .update({'status': 'read'})
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (_) {/* best-effort; next refresh reconciles */}
  }

  Future<void> markAllRead() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    state = AsyncData([
      for (final a in state.value ?? const <AlertItem>[])
        AlertItem(
            id: a.id,
            status: 'read',
            triggeredAt: a.triggeredAt,
            watchlistName: a.watchlistName,
            article: a.article)
    ]);
    try {
      await ref
          .read(supabaseProvider)
          .from('user_alerts')
          .update({'status': 'read'})
          .eq('user_id', user.id)
          .eq('status', 'unread');
    } catch (_) {/* best-effort */}
  }
}
