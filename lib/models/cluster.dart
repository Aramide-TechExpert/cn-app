import 'article.dart';

/// A story cluster — "full coverage" of one story across sources.
class StoryCluster {
  final String id;
  final String title;
  final String summary;
  final List<String> categories;
  final List<String> articleIds;
  final List<String> tags;
  final String lastUpdated;

  const StoryCluster({
    required this.id,
    required this.title,
    required this.summary,
    required this.categories,
    required this.articleIds,
    required this.tags,
    required this.lastUpdated,
  });

  int get sourceCount => articleIds.length;

  factory StoryCluster.fromJson(Map<String, dynamic> j) {
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return StoryCluster(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      summary: (j['summary'] ?? '').toString(),
      categories: strList(j['categories']),
      articleIds: strList(j['articleIds']),
      tags: strList(j['tags']),
      lastUpdated: (j['lastUpdated'] ?? '').toString(),
    );
  }
}

/// A trending topic for the Discover surface.
class TrendingTopic {
  final String topic;
  final String slug;
  final int count;

  const TrendingTopic({
    required this.topic,
    required this.slug,
    required this.count,
  });

  factory TrendingTopic.fromJson(Map<String, dynamic> j) => TrendingTopic(
        topic: (j['topic'] ?? '').toString(),
        slug: (j['slug'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// A cluster plus its member articles (from GET /clusters/:id).
class ClusterDetail {
  final StoryCluster cluster;
  final List<Article> articles;
  const ClusterDetail({required this.cluster, required this.articles});
}
