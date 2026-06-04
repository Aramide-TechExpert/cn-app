/// Daily briefing (from GET /api/v1/briefing). Mirrors the web DailyBriefing.
class BriefingTopStory {
  final int number;
  final String title;
  final String summary;
  const BriefingTopStory({
    required this.number,
    required this.title,
    required this.summary,
  });

  factory BriefingTopStory.fromJson(Map<String, dynamic> j) => BriefingTopStory(
        number: (j['number'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '').toString(),
        summary: (j['summary'] ?? '').toString(),
      );
}

class DailyBriefing {
  final String date;
  final String title;
  final String summary;
  final String marketSignals;
  final List<BriefingTopStory> topStories;
  final List<String> trendingTopics;

  const DailyBriefing({
    required this.date,
    required this.title,
    required this.summary,
    required this.marketSignals,
    required this.topStories,
    required this.trendingTopics,
  });

  factory DailyBriefing.fromJson(Map<String, dynamic> j) {
    final stories = (j['topStories'] as List?) ?? const [];
    final topics = (j['trendingTopics'] as List?) ?? const [];
    return DailyBriefing(
      date: (j['date'] ?? '').toString(),
      title: (j['title'] ?? 'Daily Briefing').toString(),
      summary: (j['summary'] ?? '').toString(),
      marketSignals: (j['marketSignals'] ?? '').toString(),
      topStories: stories
          .map((e) => BriefingTopStory.fromJson(e as Map<String, dynamic>))
          .toList(),
      trendingTopics: topics.map((e) => e.toString()).toList(),
    );
  }
}
