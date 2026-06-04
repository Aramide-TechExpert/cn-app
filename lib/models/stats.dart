/// Corpus snapshot from GET /api/v1/stats (for the Insights screen).
class CorpusStats {
  final int total;
  final int breaking;
  final int critical;
  final int high;
  final int medium;
  final int low;

  const CorpusStats({
    required this.total,
    required this.breaking,
    required this.critical,
    required this.high,
    required this.medium,
    required this.low,
  });

  factory CorpusStats.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return CorpusStats(
      total: n('total'),
      breaking: n('breaking'),
      critical: n('critical'),
      high: n('high'),
      medium: n('medium'),
      low: n('low'),
    );
  }
}
