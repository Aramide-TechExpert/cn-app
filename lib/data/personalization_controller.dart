import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../utils/source_regions.dart';
import 'auth_controller.dart';
import 'feed_controller.dart' show apiClientProvider, applySurfaceGate;
import '../utils/remote_settings.dart';
import 'reading_history.dart';

/// "For You" — articles merged from the user's followed categories
/// (personalized Home rail). Empty when signed out / no interests.
/// EVERY followed topic feeds the rail ([QA-S1.1] decision 2026-08-14 —
/// previously capped at the first 4); fetches run in parallel and the
/// merged rail still trims to its display size below.
// Keep-alive ([QA-S1.3] fix): autoDispose made the rail vanish and reload
// ("in and out") on every rebuild — the rail now holds its last content
// while refreshing; the preference listener still invalidates it.
final forYouFeedProvider = FutureProvider<List<Article>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final followed = await ref.watch(interestsControllerProvider.future);
  if (followed.isEmpty) return const [];
  final api = ref.read(apiClientProvider);
  final slugs = followed.toList();
  final lists = await Future.wait(
    slugs.map((s) async {
      try {
        return await api.categoryFeed(s, limit: 6);
      } catch (_) {
        return <Article>[];
      }
    }),
  );
  final seen = <String>{};
  final merged = <Article>[];
  for (final list in lists) {
    for (final a in list) {
      if (seen.add(a.id)) merged.add(a);
    }
  }
  merged.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  // The rail lives on Home — FULL shaping applies ([QA-S1.3] ruling
  // 2026-08-15): location gate first, then the STRICT favorites
  // allow-list, then tiering — identical to every other feed surface.
  // The admin surface gate still applies for no-preference users.
  return applySurfaceGate(
          ref,
          shapeArticlesForUser(merged, meta: user.userMetadata),
          remote.defaultsHome,
          remote.excludeHome)
      .take(12)
      .toList();
});

/// "What you missed" — followed-topic stories the user hasn't opened yet
/// (For-You minus locally-read). Dashboard section.
final whatYouMissedProvider = FutureProvider.autoDispose<List<Article>>((ref) async {
  final forYou = await ref.watch(forYouFeedProvider.future);
  final readIds = ReadingHistory.items.value.map((a) => a.id).toSet();
  return forYou.where((a) => !readIds.contains(a.id)).take(8).toList();
});

/// A selectable category (followed via `user_interests`). slug is the FK into
/// the `categories` table.
class CategoryOption {
  const CategoryOption(this.slug, this.name);
  final String slug;
  final String name;
}

/// Fallback if the categories table read is blocked/offline (mirrors the live
/// list 2026-06-13). Normally we fetch fresh so new categories appear.
const _fallbackCategories = <CategoryOption>[
  CategoryOption('ai', 'AI & Innovation'),
  CategoryOption('world-news', 'World News'),
  CategoryOption('politics', 'Politics'),
  CategoryOption('business', 'Business'),
  CategoryOption('finance', 'Finance & Economy'),
  CategoryOption('technology', 'Technology'),
  CategoryOption('science', 'Science & Research'),
  CategoryOption('health', 'Health & Medicine'),
  CategoryOption('climate', 'Climate & Environment'),
  CategoryOption('sports', 'Sports'),
  CategoryOption('entertainment', 'Entertainment'),
  CategoryOption('startups', 'Startups'),
  CategoryOption('cybersecurity', 'Cybersecurity'),
];

final categoriesProvider = FutureProvider<List<CategoryOption>>((ref) async {
  try {
    // Presentation is admin-controlled (Clustez Control → Categories):
    // sort_order drives display order, hidden drops a topic from pickers
    // (existing follows/assignments keep working).
    final rows = await ref
        .read(supabaseProvider)
        .from('categories')
        .select('slug, name, hidden')
        .order('sort_order')
        .order('name');
    final list = (rows as List)
        .where((r) => r['hidden'] != true)
        .map((r) => CategoryOption(r['slug'] as String, r['name'] as String))
        .toList();
    return list.isEmpty ? _fallbackCategories : list;
  } catch (_) {
    return _fallbackCategories;
  }
});

/// Followed category slugs (`user_interests`). Empty when signed out.
final interestsControllerProvider =
    AsyncNotifierProvider<InterestsController, Set<String>>(
        InterestsController.new);

class InterestsController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return {};
    final rows = await ref
        .read(supabaseProvider)
        .from('user_interests')
        .select('category_slug')
        .eq('user_id', user.id);
    return (rows as List).map((r) => r['category_slug'] as String).toSet();
  }

  Future<void> toggle(String slug) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final db = ref.read(supabaseProvider);
    final current = {...(state.value ?? const <String>{})};
    final following = current.contains(slug);
    // Optimistic update.
    state = AsyncData(
        following ? (current..remove(slug)) : (current..add(slug)));
    try {
      if (following) {
        await db
            .from('user_interests')
            .delete()
            .eq('user_id', user.id)
            .eq('category_slug', slug);
      } else {
        await db.from('user_interests').insert(
            {'user_id': user.id, 'category_slug': slug});
      }
    } catch (_) {
      // Revert on failure.
      final reverted = {...(state.value ?? const <String>{})};
      following ? reverted.add(slug) : reverted.remove(slug);
      state = AsyncData(reverted);
    }
  }
}

/// A saved watchlist (`watchlists`): named set of tags + optional filters.
class Watchlist {
  const Watchlist({
    required this.id,
    required this.name,
    required this.tags,
    this.breakingFilter = false,
    this.highImpactFilter = false,
    this.matchCount = 0,
  });
  final String id;
  final String name;
  final List<String> tags;
  final bool breakingFilter;
  final bool highImpactFilter;
  final int matchCount;

  factory Watchlist.fromJson(Map<String, dynamic> j) => Watchlist(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        tags: ((j['tags'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        breakingFilter: j['breaking_filter'] == true,
        highImpactFilter: j['high_impact_filter'] == true,
        matchCount: (j['match_count'] as num?)?.toInt() ?? 0,
      );
}

final watchlistsControllerProvider =
    AsyncNotifierProvider<WatchlistsController, List<Watchlist>>(
        WatchlistsController.new);

class WatchlistsController extends AsyncNotifier<List<Watchlist>> {
  @override
  Future<List<Watchlist>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];
    final rows = await ref
        .read(supabaseProvider)
        .from('watchlists')
        .select('id, name, tags, breaking_filter, high_impact_filter, match_count')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Watchlist.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({
    required String name,
    required List<String> tags,
    bool breaking = false,
    bool highImpact = false,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(supabaseProvider).from('watchlists').insert({
      'user_id': user.id,
      'name': name,
      'tags': tags,
      'breaking_filter': breaking,
      'high_impact_filter': highImpact,
    });
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String id) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref
        .read(supabaseProvider)
        .from('watchlists')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
    ref.invalidateSelf();
    await future;
  }
}
