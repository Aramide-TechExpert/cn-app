import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_controller.dart';

/// The signed-in user's liked + bookmarked article dbIds.
class EngagementState {
  final Set<String> liked;
  final Set<String> bookmarked;
  const EngagementState({this.liked = const {}, this.bookmarked = const {}});

  EngagementState copyWith({Set<String>? liked, Set<String>? bookmarked}) =>
      EngagementState(
        liked: liked ?? this.liked,
        bookmarked: bookmarked ?? this.bookmarked,
      );
}

/// Channel 1 — reads/writes go DIRECT to Supabase under RLS (article_likes /
/// bookmarks are auth.uid()-scoped). Keyed by the article DB uuid (dbId).
/// Reloads automatically when the signed-in user changes.
final engagementProvider =
    AsyncNotifierProvider<EngagementController, EngagementState>(
  EngagementController.new,
);

class EngagementController extends AsyncNotifier<EngagementState> {
  SupabaseClient get _c => ref.read(supabaseProvider);

  @override
  Future<EngagementState> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const EngagementState();

    final likes = await _c
        .from('article_likes')
        .select('article_id')
        .eq('user_id', user.id);
    final marks =
        await _c.from('bookmarks').select('article_id').eq('user_id', user.id);

    Set<String> ids(dynamic rows) =>
        (rows as List).map((r) => r['article_id'] as String).toSet();

    return EngagementState(liked: ids(likes), bookmarked: ids(marks));
  }

  Future<void> toggleLike(String dbId) =>
      _toggle('article_likes', dbId, like: true);

  Future<void> toggleBookmark(String dbId) =>
      _toggle('bookmarks', dbId, like: false);

  Future<void> _toggle(String table, String dbId, {required bool like}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final current = state.value ?? const EngagementState();
    final set = like ? current.liked : current.bookmarked;
    final on = !set.contains(dbId);

    final next = {...set};
    if (on) {
      next.add(dbId);
    } else {
      next.remove(dbId);
    }
    // optimistic
    state = AsyncData(
      like ? current.copyWith(liked: next) : current.copyWith(bookmarked: next),
    );

    try {
      if (on) {
        await _c.from(table).insert({'user_id': user.id, 'article_id': dbId});
      } else {
        await _c
            .from(table)
            .delete()
            .eq('user_id', user.id)
            .eq('article_id', dbId);
      }
    } on PostgrestException catch (e) {
      if (e.code != '23505') state = AsyncData(current); // rollback real errors
    } catch (_) {
      state = AsyncData(current); // rollback
    }
  }
}
