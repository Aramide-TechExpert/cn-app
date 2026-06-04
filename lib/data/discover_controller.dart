import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../models/briefing.dart';
import '../models/cluster.dart';
import '../models/stats.dart';
import 'feed_controller.dart' show apiClientProvider;

final clustersProvider = FutureProvider.autoDispose<List<StoryCluster>>(
  (ref) => ref.read(apiClientProvider).clusters(),
);

final statsProvider = FutureProvider.autoDispose<CorpusStats>(
  (ref) => ref.read(apiClientProvider).stats(),
);

final briefingProvider = FutureProvider.autoDispose<DailyBriefing?>(
  (ref) => ref.read(apiClientProvider).briefing(),
);

final trendingProvider = FutureProvider.autoDispose<List<TrendingTopic>>(
  (ref) => ref.read(apiClientProvider).trending(),
);

final clusterDetailProvider =
    FutureProvider.autoDispose.family<ClusterDetail?, String>(
  (ref, id) => ref.read(apiClientProvider).cluster(id),
);

final topicFeedProvider =
    FutureProvider.autoDispose.family<List<Article>, String>(
  (ref, slug) => ref.read(apiClientProvider).categoryFeed(slug),
);
