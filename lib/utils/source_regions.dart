import '../models/article.dart';

/// News region segments — the "editions" a user can make their local feed.
/// Chosen in setup Step 3 (or Settings → Preferences); stored in profile
/// metadata as `preferred_region`, with `news_scope` = 'region' for any
/// segment other than Worldwide.
const newsSegments = <(String, String)>[
  ('Worldwide', '🌐'),
  ('United States', '🇺🇸'),
  ('United Kingdom', '🇬🇧'),
  ('Canada', '🇨🇦'),
  ('Europe', '🇪🇺'),
  ('Africa', '🌍'),
  ('Middle East', '🇦🇪'),
  ('India', '🇮🇳'),
  ('Asia-Pacific', '🌏'),
  ('Australia & NZ', '🇦🇺'),
  ('Latin America', '🌎'),
];

/// Segment each ingest source belongs to (by HQ / primary audience).
const Map<String, String> _sourceSegments = {
  // United Kingdom
  'bbc news': 'United Kingdom', 'bbc world': 'United Kingdom',
  'bbc business': 'United Kingdom', 'bbc technology': 'United Kingdom',
  'bbc sport': 'United Kingdom',
  'the guardian world': 'United Kingdom',
  'the guardian business': 'United Kingdom',
  'the guardian tech': 'United Kingdom',
  'guardian environment': 'United Kingdom',
  'sky news': 'United Kingdom', 'sky news world': 'United Kingdom',
  'sky sports': 'United Kingdom',
  'the independent': 'United Kingdom', 'the telegraph': 'United Kingdom',
  'nature': 'United Kingdom', 'the register': 'United Kingdom',
  // United States
  'npr news': 'United States', 'npr business': 'United States',
  'npr technology': 'United States',
  'cnn': 'United States', 'cbs news': 'United States',
  'nbc news': 'United States', 'abc news': 'United States',
  'fox news': 'United States', 'new york times': 'United States',
  'nyt world': 'United States', 'nyt technology': 'United States',
  'time': 'United States',
  'axios': 'United States', 'politico': 'United States',
  'the hill': 'United States',
  'cnbc top news': 'United States', 'marketwatch': 'United States',
  'fortune': 'United States', 'business insider': 'United States',
  'yahoo finance': 'United States',
  'variety': 'United States', 'deadline': 'United States',
  'rolling stone': 'United States',
  'techcrunch': 'United States', 'the verge': 'United States',
  'ars technica': 'United States', 'engadget': 'United States',
  'wired': 'United States', 'mit technology review': 'United States',
  'venturebeat': 'United States', 'ieee spectrum': 'United States',
  'hacker news': 'United States', 'coindesk': 'United States',
  'decrypt': 'United States', 'quanta magazine': 'United States',
  'sciencedaily': 'United States', 'live science': 'United States',
  'phys.org': 'United States', 'inside climate news': 'United States',
  'grist': 'United States', 'stat news': 'United States',
  'kff health news': 'United States', 'zdnet': 'United States',
  // Canada
  'cbc news': 'Canada', 'global news': 'Canada',
  // Europe (non-UK)
  'dw (deutsche welle)': 'Europe', 'france 24': 'Europe',
  'euronews': 'Europe',
  // Africa
  'punch': 'Africa', 'premium times': 'Africa', 'vanguard': 'Africa',
  'nation africa': 'Africa', 'daily maverick': 'Africa',
  'bbc africa': 'Africa', 'allafrica': 'Africa',
  // Middle East
  'al jazeera': 'Middle East', 'times of israel': 'Middle East',
  'arab news': 'Middle East', 'the national': 'Middle East',
  // India
  'times of india': 'India', 'ndtv': 'India', 'hindustan times': 'India',
  'the economic times': 'India',
  // Asia-Pacific
  'south china morning post': 'Asia-Pacific',
  'the japan times': 'Asia-Pacific', 'the straits times': 'Asia-Pacific',
  'cna': 'Asia-Pacific', 'the korea herald': 'Asia-Pacific',
  'bangkok post': 'Asia-Pacific', 'philippine daily inquirer': 'Asia-Pacific',
  // Australia & NZ
  'sydney morning herald': 'Australia & NZ', 'abc australia': 'Australia & NZ',
  'rnz': 'Australia & NZ',
  // Latin America
  'telemundo': 'Latin America', 'mexico news daily': 'Latin America',
  'buenos aires times': 'Latin America', 'mercopress': 'Latin America',
};

String? segmentOfSource(String source) =>
    _sourceSegments[source.toLowerCase()];

/// Stable partition: articles from the user's segment first, everything else
/// after, order preserved within each tier. The result feeds
/// interleaveBySource, so local outlets lead each cycle without pushing the
/// rest of the world out of the feed.
List<Article> segmentFirst(List<Article> items, {required String segment}) {
  final local = <Article>[];
  final rest = <Article>[];
  for (final a in items) {
    (segmentOfSource(a.source) == segment ? local : rest).add(a);
  }
  return [...local, ...rest];
}
