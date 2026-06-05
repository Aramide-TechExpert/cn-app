/// Ported from the web src/lib/sources/{bias,fact-check}.ts — the trust signals
/// shown on every card. (Trust score itself comes from the API: Article.trustScore.)

enum Bias { left, leanLeft, center, leanRight, right, unknown }

const Map<String, Bias> _biasMap = {
  // Left
  'msnbc': Bias.left, 'the nation': Bias.left, 'mother jones': Bias.left,
  'huffpost': Bias.left, 'salon': Bias.left,
  // Lean-left
  'the new york times': Bias.leanLeft, 'nyt': Bias.leanLeft,
  'the washington post': Bias.leanLeft, 'washington post': Bias.leanLeft,
  'cnn': Bias.leanLeft, 'the guardian': Bias.leanLeft, 'nbc news': Bias.leanLeft,
  'abc news': Bias.leanLeft, 'cbs news': Bias.leanLeft,
  'the atlantic': Bias.leanLeft, 'politico': Bias.leanLeft, 'vox': Bias.leanLeft,
  'axios': Bias.leanLeft, 'time': Bias.leanLeft, 'the verge': Bias.leanLeft,
  // Center
  'reuters': Bias.center, 'associated press': Bias.center, 'ap news': Bias.center,
  'ap': Bias.center, 'bbc': Bias.center, 'bbc news': Bias.center,
  'bloomberg': Bias.center, 'the wall street journal': Bias.center,
  'wsj': Bias.center, 'the economist': Bias.center, 'financial times': Bias.center,
  'ft': Bias.center, 'npr': Bias.center, 'al jazeera': Bias.center,
  'ars technica': Bias.center, 'techcrunch': Bias.center, 'wired': Bias.center,
  'the information': Bias.center, 'engadget': Bias.center,
  'mit technology review': Bias.center,
  // Lean-right
  'the wall street journal opinion': Bias.leanRight, 'the dispatch': Bias.leanRight,
  'the washington times': Bias.leanRight, 'national review': Bias.leanRight,
  'reason': Bias.leanRight, 'new york post': Bias.leanRight,
  'the telegraph': Bias.leanRight, 'the daily telegraph': Bias.leanRight,
  // Right
  'fox news': Bias.right, 'the daily wire': Bias.right, 'breitbart': Bias.right,
  'the federalist': Bias.right, 'newsmax': Bias.right, 'oann': Bias.right,
};

const Set<String> _factCheckOutlets = {
  'reuters', 'associated press', 'ap news', 'ap', 'bbc', 'bbc news',
  'the new york times', 'nyt', 'the washington post', 'washington post',
  'the guardian', 'factcheck.org', 'snopes', 'politifact', 'afp fact check',
  'lead stories', 'full fact', 'the conversation',
};

final RegExp _suffix = RegExp(
  r'\s+(top\s+(stories|news)|world|us|uk|business|tech|technology|opinion|news|feed|rss|latest)$',
  caseSensitive: false,
);

List<String> _normalize(String source) {
  final base = source.toLowerCase().trim();
  final stripped = base.replaceAll(_suffix, '');
  final cands = <String>{base, stripped};
  final words = stripped.split(RegExp(r'\s+'));
  while (words.length > 1) {
    words.removeLast();
    cands.add(words.join(' '));
  }
  return cands.toList();
}

Bias biasFor(String source) {
  if (source.isEmpty) return Bias.unknown;
  for (final k in _normalize(source)) {
    final b = _biasMap[k];
    if (b != null) return b;
  }
  return Bias.unknown;
}

String biasLabel(Bias b) => switch (b) {
      Bias.left => 'Left',
      Bias.leanLeft => 'Lean left',
      Bias.center => 'Center',
      Bias.leanRight => 'Lean right',
      Bias.right => 'Right',
      Bias.unknown => 'Unrated',
    };

bool isFactChecked(String source) {
  for (final k in _normalize(source)) {
    if (_factCheckOutlets.contains(k)) return true;
  }
  return false;
}

/// Humanize a category slug: 'world-news' -> 'World News'.
String categoryLabel(String slug) => slug
    .split('-')
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
