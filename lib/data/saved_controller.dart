import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import 'auth_controller.dart';
import 'engagement_controller.dart';
import 'feed_controller.dart' show apiClientProvider;

/// The signed-in user's bookmarked articles. Resolves each bookmarked dbId via
/// `/api/v1/articles/:id`. Rebuilds when the bookmark set changes.
final savedArticlesProvider =
    FutureProvider.autoDispose<List<Article>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];

  final engagement = await ref.watch(engagementProvider.future);
  final ids = engagement.bookmarked.toList();
  if (ids.isEmpty) return const [];

  final api = ref.read(apiClientProvider);
  final results = await Future.wait(ids.map((id) => api.article(id)));
  return results.whereType<Article>().toList();
});
