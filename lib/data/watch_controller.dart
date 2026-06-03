import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../utils/video.dart';
import 'feed_controller.dart' show apiClientProvider;

/// Watch feed: a slice of the recent feed filtered to video articles.
/// (Inline players come later; v1 link-outs to the publisher like the rest.)
final watchFeedProvider = FutureProvider.autoDispose<List<Article>>((ref) async {
  final page = await ref.read(apiClientProvider).feed(limit: 50);
  return page.items.where(isVideoArticle).toList();
});
