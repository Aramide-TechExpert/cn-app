/// Mirrors the `/api/v1` Article payload (see API_V1.md in the backend repo).
/// `id` is external_id ?? uuid (routing/display); `dbId` is the uuid used to
/// key likes/bookmarks/comments.
class Article {
  final String id;
  final String? dbId;
  final String title;
  final String excerpt;
  final String image;
  final String source;
  final String? sourceUrl;
  final String publishedAt;
  final int readingMinutes;
  final List<String> categories;
  final String impact;
  final bool isBreaking;
  final String? summary;
  final String? whatHappened;
  final String? whyItMatters;
  final List<String> topics;
  final int? trustScore;
  final int likeCount;
  final int commentCount;

  const Article({
    required this.id,
    this.dbId,
    required this.title,
    required this.excerpt,
    required this.image,
    required this.source,
    this.sourceUrl,
    required this.publishedAt,
    required this.readingMinutes,
    required this.categories,
    required this.impact,
    required this.isBreaking,
    this.summary,
    this.whatHappened,
    this.whyItMatters,
    required this.topics,
    this.trustScore,
    required this.likeCount,
    required this.commentCount,
  });

  bool get hasImage => image.isNotEmpty;
  String? get blurb => (summary != null && summary!.isNotEmpty)
      ? summary
      : (excerpt.isNotEmpty ? excerpt : null);

  factory Article.fromJson(Map<String, dynamic> j) {
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return Article(
      id: (j['id'] ?? '').toString(),
      dbId: j['dbId'] as String?,
      title: (j['title'] ?? '').toString(),
      excerpt: (j['excerpt'] ?? '').toString(),
      image: (j['image'] ?? '').toString(),
      source: (j['source'] ?? '').toString(),
      sourceUrl: j['sourceUrl'] as String?,
      publishedAt: (j['publishedAt'] ?? '').toString(),
      readingMinutes: (j['readingMinutes'] as num?)?.toInt() ?? 0,
      categories: strList(j['categories']),
      impact: (j['impact'] ?? 'Low').toString(),
      isBreaking: j['isBreaking'] == true,
      summary: j['summary'] as String?,
      whatHappened: j['whatHappened'] as String?,
      whyItMatters: j['whyItMatters'] as String?,
      topics: strList(j['topics']),
      trustScore: (j['trustScore'] as num?)?.toInt(),
      likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Cursor-paginated feed page from `GET /feed`.
class FeedPage {
  final List<Article> items;
  final String? nextCursor;

  const FeedPage({required this.items, required this.nextCursor});

  factory FeedPage.fromJson(Map<String, dynamic> j) {
    final list = (j['items'] as List?) ?? const [];
    return FeedPage(
      items: list
          .map((e) => Article.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: j['nextCursor'] as String?,
    );
  }
}
