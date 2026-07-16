import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../models/briefing.dart';
import '../models/cluster.dart';
import '../models/stats.dart';
import '../models/widgets_data.dart';
import '../utils/source_regions.dart';
import 'auth_controller.dart';
import 'feed_controller.dart' show apiClientProvider;

final clustersProvider = FutureProvider.autoDispose<List<StoryCluster>>(
  (ref) => ref.read(apiClientProvider).clusters(),
);

final statsProvider = FutureProvider.autoDispose<CorpusStats>(
  (ref) => ref.read(apiClientProvider).stats(),
);

final widgetsDataProvider = FutureProvider.autoDispose<WidgetsData>(
  (ref) => ref.read(apiClientProvider).widgets(),
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
  (ref, slug) async {
    final items = await ref.read(apiClientProvider).categoryFeed(slug);
    return gateAfricaSources(items,
        meta: ref.read(currentUserProvider)?.userMetadata);
  },
);
