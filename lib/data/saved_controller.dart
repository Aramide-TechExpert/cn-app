import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import 'auth_controller.dart';
import 'engagement_controller.dart';
import 'feed_controller.dart' show apiClientProvider;

/// The signed-in user's bookmarked articles. Resolves all bookmarked dbIds in
/// one batch request (`/api/v1/articles?ids=`). Rebuilds when bookmarks change.
final savedArticlesProvider =
    FutureProvider.autoDispose<List<Article>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];

  final engagement = await ref.watch(engagementProvider.future);
  final ids = engagement.bookmarked.toList();
  if (ids.isEmpty) return const [];

  return ref.read(apiClientProvider).articlesByIds(ids);
});
