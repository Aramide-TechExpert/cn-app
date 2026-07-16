import '../models/article.dart';
import '../models/cluster.dart';

/// News region segments — the "editions" a user can make their local feed.
/// Chosen in setup Step 3 (or Settings → Preferences); stored in profile
/// metadata as `preferred_region` (+ optional `preferred_country` for
/// country-level localization inside the segment).
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

/// How a source travels:
/// - national: a country's news outlet — STRICTLY gated to users on its
///   segment (a US-preference user never sees a Philippine national outlet)
/// - global: international desks (BBC World, Al Jazeera, DW…) — everyone
/// - topical: subject verticals (tech, science, finance, sports,
///   entertainment, health, climate) — everyone, any region
enum SourceKind { national, global, topical }

class SourceInfo {
  const SourceInfo(this.country, this.segment, this.kind);
  final String country;
  final String segment;
  final SourceKind kind;
}

const _n = SourceKind.national;
const _g = SourceKind.global;
const _t = SourceKind.topical;

const Map<String, SourceInfo> _sources = {
  // ── United Kingdom (nationals) + UK-based verticals ──
  'bbc news': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'bbc business': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'bbc technology': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'sky news': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the independent': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the telegraph': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the guardian business': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the guardian tech': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'bbc sport': SourceInfo('United Kingdom', 'United Kingdom', _t),
  'sky sports': SourceInfo('United Kingdom', 'United Kingdom', _t),
  'nature': SourceInfo('United Kingdom', 'United Kingdom', _t),
  'the register': SourceInfo('United Kingdom', 'United Kingdom', _t),
  'guardian environment': SourceInfo('United Kingdom', 'United Kingdom', _t),
  // ── Global / international desks ──
  'bbc world': SourceInfo('United Kingdom', 'United Kingdom', _g),
  'the guardian world': SourceInfo('United Kingdom', 'United Kingdom', _g),
  'sky news world': SourceInfo('United Kingdom', 'United Kingdom', _g),
  'nyt world': SourceInfo('United States', 'United States', _g),
  'al jazeera': SourceInfo('Qatar', 'Middle East', _g),
  'dw (deutsche welle)': SourceInfo('Germany', 'Europe', _g),
  'france 24': SourceInfo('France', 'Europe', _g),
  'euronews': SourceInfo('France', 'Europe', _g),
  // ── United States (nationals) ──
  'npr news': SourceInfo('United States', 'United States', _n),
  'npr business': SourceInfo('United States', 'United States', _n),
  'npr technology': SourceInfo('United States', 'United States', _n),
  'cnn': SourceInfo('United States', 'United States', _n),
  'cbs news': SourceInfo('United States', 'United States', _n),
  'nbc news': SourceInfo('United States', 'United States', _n),
  'abc news': SourceInfo('United States', 'United States', _n),
  'fox news': SourceInfo('United States', 'United States', _n),
  'new york times': SourceInfo('United States', 'United States', _n),
  'nyt technology': SourceInfo('United States', 'United States', _n),
  'time': SourceInfo('United States', 'United States', _n),
  'axios': SourceInfo('United States', 'United States', _n),
  'politico': SourceInfo('United States', 'United States', _n),
  'the hill': SourceInfo('United States', 'United States', _n),
  // ── US-based verticals (topical — everyone gets these) ──
  'cnbc top news': SourceInfo('United States', 'United States', _t),
  'marketwatch': SourceInfo('United States', 'United States', _t),
  'fortune': SourceInfo('United States', 'United States', _t),
  'business insider': SourceInfo('United States', 'United States', _t),
  'yahoo finance': SourceInfo('United States', 'United States', _t),
  'variety': SourceInfo('United States', 'United States', _t),
  'deadline': SourceInfo('United States', 'United States', _t),
  'rolling stone': SourceInfo('United States', 'United States', _t),
  'techcrunch': SourceInfo('United States', 'United States', _t),
  'the verge': SourceInfo('United States', 'United States', _t),
  'ars technica': SourceInfo('United States', 'United States', _t),
  'engadget': SourceInfo('United States', 'United States', _t),
  'wired': SourceInfo('United States', 'United States', _t),
  'mit technology review': SourceInfo('United States', 'United States', _t),
  'venturebeat': SourceInfo('United States', 'United States', _t),
  'ieee spectrum': SourceInfo('United States', 'United States', _t),
  'hacker news': SourceInfo('United States', 'United States', _t),
  'coindesk': SourceInfo('United States', 'United States', _t),
  'decrypt': SourceInfo('United States', 'United States', _t),
  'quanta magazine': SourceInfo('United States', 'United States', _t),
  'sciencedaily': SourceInfo('United States', 'United States', _t),
  'live science': SourceInfo('United States', 'United States', _t),
  'phys.org': SourceInfo('United States', 'United States', _t),
  'inside climate news': SourceInfo('United States', 'United States', _t),
  'grist': SourceInfo('United States', 'United States', _t),
  'stat news': SourceInfo('United States', 'United States', _t),
  'kff health news': SourceInfo('United States', 'United States', _t),
  'zdnet': SourceInfo('United States', 'United States', _t),
  // ── Canada ──
  'cbc news': SourceInfo('Canada', 'Canada', _n),
  'global news': SourceInfo('Canada', 'Canada', _n),
  // ── Europe (nationals) ──
  'the local germany': SourceInfo('Germany', 'Europe', _n),
  'rte': SourceInfo('Ireland', 'Europe', _n),
  'ansa english': SourceInfo('Italy', 'Europe', _n),
  'dutchnews': SourceInfo('Netherlands', 'Europe', _n),
  'notes from poland': SourceInfo('Poland', 'Europe', _n),
  'the moscow times': SourceInfo('Russia', 'Europe', _n),
  // ── Africa (nationals) ──
  'punch': SourceInfo('Nigeria', 'Africa', _n),
  'premium times': SourceInfo('Nigeria', 'Africa', _n),
  'vanguard': SourceInfo('Nigeria', 'Africa', _n),
  'myjoyonline': SourceInfo('Ghana', 'Africa', _n),
  'nation africa': SourceInfo('Kenya', 'Africa', _n),
  'the standard': SourceInfo('Kenya', 'Africa', _n),
  'daily maverick': SourceInfo('South Africa', 'Africa', _n),
  'bbc africa': SourceInfo('Kenya', 'Africa', _n),
  'allafrica': SourceInfo('Nigeria', 'Africa', _n),
  // ── Middle East (nationals) ──
  'times of israel': SourceInfo('Israel', 'Middle East', _n),
  'arab news': SourceInfo('Saudi Arabia', 'Middle East', _n),
  'the national': SourceInfo('United Arab Emirates', 'Middle East', _n),
  'hurriyet daily news': SourceInfo('Turkey', 'Middle East', _n),
  'daily sabah': SourceInfo('Turkey', 'Middle East', _n),
  // ── India ──
  'times of india': SourceInfo('India', 'India', _n),
  'ndtv': SourceInfo('India', 'India', _n),
  'hindustan times': SourceInfo('India', 'India', _n),
  'the economic times': SourceInfo('India', 'India', _n),
  // ── Asia-Pacific (nationals) ──
  'south china morning post': SourceInfo('Hong Kong', 'Asia-Pacific', _n),
  'the japan times': SourceInfo('Japan', 'Asia-Pacific', _n),
  'the straits times': SourceInfo('Singapore', 'Asia-Pacific', _n),
  'cna': SourceInfo('Singapore', 'Asia-Pacific', _n),
  'the korea herald': SourceInfo('South Korea', 'Asia-Pacific', _n),
  'bangkok post': SourceInfo('Thailand', 'Asia-Pacific', _n),
  'philippine daily inquirer': SourceInfo('Philippines', 'Asia-Pacific', _n),
  'vnexpress': SourceInfo('Vietnam', 'Asia-Pacific', _n),
  'dawn': SourceInfo('Pakistan', 'Asia-Pacific', _n),
  'the daily star': SourceInfo('Bangladesh', 'Asia-Pacific', _n),
  'malay mail': SourceInfo('Malaysia', 'Asia-Pacific', _n),
  'antara news': SourceInfo('Indonesia', 'Asia-Pacific', _n),
  // ── Australia & NZ ──
  'sydney morning herald': SourceInfo('Australia', 'Australia & NZ', _n),
  'abc australia': SourceInfo('Australia', 'Australia & NZ', _n),
  'rnz': SourceInfo('New Zealand', 'Australia & NZ', _n),
  // ── Latin America ──
  'telemundo': SourceInfo('Mexico', 'Latin America', _n),
  'mexico news daily': SourceInfo('Mexico', 'Latin America', _n),
  'buenos aires times': SourceInfo('Argentina', 'Latin America', _n),
  'mercopress': SourceInfo('Uruguay', 'Latin America', _n),
  'rio times': SourceInfo('Brazil', 'Latin America', _n),
  'the city paper': SourceInfo('Colombia', 'Latin America', _n),
};

SourceInfo? sourceInfo(String source) => _sources[source.toLowerCase()];

/// Countries offered for country-level localization inside a segment (only
/// countries we actually have national outlets for). Single-country segments
/// (US, UK, Canada, India) need no picker.
const Map<String, List<String>> segmentCountries = {
  'Europe': ['Germany', 'Ireland', 'Italy', 'Netherlands', 'Poland', 'Russia'],
  'Africa': ['Nigeria', 'Ghana', 'Kenya', 'South Africa'],
  'Middle East': ['Israel', 'Saudi Arabia', 'United Arab Emirates', 'Turkey'],
  'Asia-Pacific': [
    'Japan', 'South Korea', 'Singapore', 'Hong Kong', 'Thailand',
    'Philippines', 'Indonesia', 'Malaysia', 'Vietnam', 'Pakistan',
    'Bangladesh',
  ],
  'Australia & NZ': ['Australia', 'New Zealand'],
  'Latin America': ['Mexico', 'Argentina', 'Brazil', 'Colombia', 'Uruguay'],
};

/// Country → segment, for device-location detection. Broader than the source
/// roster: any detected country should land in the right edition even before
/// we carry its national outlets.
const Map<String, String> countryToSegment = {
  'United States': 'United States',
  'United Kingdom': 'United Kingdom',
  'Canada': 'Canada',
  'India': 'India',
  // Europe
  'Germany': 'Europe', 'France': 'Europe', 'Ireland': 'Europe',
  'Italy': 'Europe', 'Netherlands': 'Europe', 'Poland': 'Europe',
  'Russia': 'Europe', 'Spain': 'Europe', 'Portugal': 'Europe',
  'Sweden': 'Europe', 'Norway': 'Europe', 'Denmark': 'Europe',
  'Finland': 'Europe', 'Belgium': 'Europe', 'Austria': 'Europe',
  'Switzerland': 'Europe', 'Greece': 'Europe', 'Czechia': 'Europe',
  'Ukraine': 'Europe', 'Romania': 'Europe', 'Hungary': 'Europe',
  // Africa
  'Nigeria': 'Africa', 'Ghana': 'Africa', 'Kenya': 'Africa',
  'South Africa': 'Africa', 'Egypt': 'Africa', 'Ethiopia': 'Africa',
  'Uganda': 'Africa', 'Tanzania': 'Africa', 'Cameroon': 'Africa',
  'Senegal': 'Africa', 'Zimbabwe': 'Africa', 'Zambia': 'Africa',
  'Rwanda': 'Africa', 'Morocco': 'Africa', 'Algeria': 'Africa',
  'Tunisia': 'Africa', "Côte d'Ivoire": 'Africa', 'Ivory Coast': 'Africa',
  // Middle East
  'Israel': 'Middle East', 'Saudi Arabia': 'Middle East',
  'United Arab Emirates': 'Middle East', 'Qatar': 'Middle East',
  'Turkey': 'Middle East', 'Kuwait': 'Middle East', 'Jordan': 'Middle East',
  'Lebanon': 'Middle East', 'Bahrain': 'Middle East', 'Oman': 'Middle East',
  // Asia-Pacific
  'Japan': 'Asia-Pacific', 'South Korea': 'Asia-Pacific',
  'Singapore': 'Asia-Pacific', 'Hong Kong': 'Asia-Pacific',
  'China': 'Asia-Pacific', 'Taiwan': 'Asia-Pacific',
  'Thailand': 'Asia-Pacific', 'Philippines': 'Asia-Pacific',
  'Indonesia': 'Asia-Pacific', 'Malaysia': 'Asia-Pacific',
  'Vietnam': 'Asia-Pacific', 'Pakistan': 'Asia-Pacific',
  'Bangladesh': 'Asia-Pacific', 'Sri Lanka': 'Asia-Pacific',
  'Nepal': 'Asia-Pacific',
  // Australia & NZ
  'Australia': 'Australia & NZ', 'New Zealand': 'Australia & NZ',
  // Latin America
  'Mexico': 'Latin America', 'Argentina': 'Latin America',
  'Brazil': 'Latin America', 'Colombia': 'Latin America',
  'Uruguay': 'Latin America', 'Chile': 'Latin America',
  'Peru': 'Latin America', 'Ecuador': 'Latin America',
  'Venezuela': 'Latin America', 'Bolivia': 'Latin America',
  'Paraguay': 'Latin America',
};

/// The user's active segment: null when signed out, worldwide, or unset.
String? activeSegment(Map<String, dynamic>? meta) {
  if (meta?['news_scope'] != 'region') return null;
  final s = meta?['preferred_region'] as String?;
  return (s == null || s.isEmpty || s == 'Worldwide') ? null : s;
}

/// The user's country inside their segment (only meaningful when scoped).
String? activeCountry(Map<String, dynamic>? meta) {
  if (activeSegment(meta) == null) return null;
  final c = meta?['preferred_country'] as String?;
  return (c == null || c.isEmpty) ? null : c;
}

/// STRICT source visibility:
/// - global + topical + unknown sources: visible to everyone
/// - national outlets: visible ONLY to users on their segment; with no
///   segment (worldwide / signed out) every national except Africa's is
///   visible (Africa stays fully gated per the standing decision)
bool sourceVisible(String source, Map<String, dynamic>? meta) {
  final i = sourceInfo(source);
  if (i == null || i.kind != SourceKind.national) return true;
  final segment = activeSegment(meta);
  if (segment == null) return i.segment != 'Africa';
  return i.segment == segment;
}

/// Drop articles from sources the user must not see (strict gate).
List<Article> gateSourcesForUser(
  List<Article> items, {
  required Map<String, dynamic>? meta,
}) =>
    items.where((a) => sourceVisible(a.source, meta)).toList();

/// Ordering tier for a scoped user (lower = earlier):
/// 0 country national · 1 segment national · 2 global · 3 topical/unknown
int _tier(String source, String? segment, String? country) {
  final i = sourceInfo(source);
  if (i == null) return 3;
  if (i.kind == SourceKind.national) {
    if (country != null && i.country == country) return 0;
    return 1;
  }
  return i.kind == SourceKind.global ? 2 : 3;
}

/// Full preference shaping: strict gate, then a stable 4-tier partition so
/// the user's country outlets lead, their region next, then global desks,
/// then topical verticals. Feeds interleaveBySource afterwards.
List<Article> shapeArticlesForUser(
  List<Article> items, {
  required Map<String, dynamic>? meta,
}) {
  final kept = gateSourcesForUser(items, meta: meta);
  final segment = activeSegment(meta);
  if (segment == null) return kept;
  final country = activeCountry(meta);
  final tiers = [<Article>[], <Article>[], <Article>[], <Article>[]];
  for (final a in kept) {
    tiers[_tier(a.source, segment, country)].add(a);
  }
  return [for (final t in tiers) ...t];
}

/// Cluster-level preference shaping for the Clusters page: hide clusters
/// whose sources are ALL invisible to this user; lead with clusters that
/// include the user's country, then segment, outlets.
List<StoryCluster> shapeClustersForUser(
  List<StoryCluster> clusters, {
  required Map<String, dynamic>? meta,
}) {
  final visible = [
    for (final c in clusters)
      if (c.sources.isEmpty || c.sources.any((s) => sourceVisible(s, meta)))
        c,
  ];
  final segment = activeSegment(meta);
  if (segment == null) return visible;
  final country = activeCountry(meta);
  int clusterTier(StoryCluster c) {
    var best = 3;
    for (final s in c.sources) {
      final t = _tier(s, segment, country);
      if (t < best) best = t;
    }
    return best;
  }

  final tiers = [
    <StoryCluster>[], <StoryCluster>[], <StoryCluster>[], <StoryCluster>[],
  ];
  for (final c in visible) {
    tiers[clusterTier(c)].add(c);
  }
  return [for (final t in tiers) ...t];
}
