import '../utils/format.dart';

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
  final bool hasVideo;
  final String? videoUrl;

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
    this.hasVideo = false,
    this.videoUrl,
  });

  bool get hasImage => image.isNotEmpty;
  /// True only when the source carries a self-hosted, directly-playable video
  /// (set at ingest; never YouTube/Vimeo) — gates inline playback.
  bool get hasPlayableVideo => videoUrl != null && videoUrl!.isNotEmpty;
  /// The excerpt shown on every card. Prefers a distinct blurb (summary →
  /// excerpt → whatHappened → whyItMatters), skipping any that merely repeats
  /// the title; falls back to a title-duplicate only as a last resort so a card
  /// is never left title-only when any text exists.
  String? get blurb {
    final candidates = [summary, excerpt, whatHappened, whyItMatters];
    final t = title.trim().toLowerCase();
    for (final s in candidates) {
      final v = (s ?? '').trim();
      if (v.isNotEmpty && v.toLowerCase() != t) return v;
    }
    for (final s in candidates) {
      final v = (s ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  factory Article.fromJson(Map<String, dynamic> j) {
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return Article(
      id: (j['id'] ?? '').toString(),
      dbId: j['dbId'] as String?,
      // Sanitize display text (strip URLs/HTML/markdown/hashes so cards read
      // like clean prose, not scraped source).
      title: cleanText((j['title'] ?? '').toString()),
      excerpt: cleanText((j['excerpt'] ?? '').toString()),
      image: (j['image'] ?? '').toString(),
      source: (j['source'] ?? '').toString(),
      sourceUrl: j['sourceUrl'] as String?,
      publishedAt: (j['publishedAt'] ?? '').toString(),
      readingMinutes: (j['readingMinutes'] as num?)?.toInt() ?? 0,
      categories: strList(j['categories']),
      impact: (j['impact'] ?? 'Low').toString(),
      isBreaking: j['isBreaking'] == true,
      summary: cleanText(j['summary'] as String?),
      whatHappened: cleanText(j['whatHappened'] as String?),
      whyItMatters: cleanText(j['whyItMatters'] as String?),
      topics: strList(j['topics']),
      trustScore: (j['trustScore'] as num?)?.toInt(),
      likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
      hasVideo: j['hasVideo'] == true,
      videoUrl: j['videoUrl'] as String?,
    );
  }

  /// Compact JSON for local persistence (reading history) — the fields cards
  /// need to render without a refetch.
  Map<String, dynamic> toJson() => {
        'id': id,
        'dbId': dbId,
        'title': title,
        'excerpt': excerpt,
        'image': image,
        'source': source,
        'sourceUrl': sourceUrl,
        'publishedAt': publishedAt,
        'readingMinutes': readingMinutes,
        'categories': categories,
        'impact': impact,
        'isBreaking': isBreaking,
        'summary': summary,
        'topics': topics,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'hasVideo': hasVideo,
        'videoUrl': videoUrl,
      };
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
