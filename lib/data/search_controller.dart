import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../utils/source_regions.dart';
import 'auth_controller.dart';
import 'feed_controller.dart' show apiClientProvider;

/// Current search query (debounced by the UI before being set here).
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Results for the current query. Empty under 2 chars. Africa-gated, but the
/// relevance ORDER is kept (no segment partition on search).
final searchResultsProvider =
    FutureProvider.autoDispose<List<Article>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.length < 2) return const [];
  final results = await ref.read(apiClientProvider).search(q);
  return gateSourcesForUser(results,
      meta: ref.read(currentUserProvider)?.userMetadata);
});
