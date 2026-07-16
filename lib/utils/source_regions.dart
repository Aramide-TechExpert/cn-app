import '../models/article.dart';

/// Home country + region for every ingest source (by its HQ / primary
/// audience). Powers the "My country & region first" preference from setup:
/// pages get stably partitioned so local outlets lead each source-interleave
/// cycle, without ever hiding the rest of the world.
class SourceRegion {
  const SourceRegion(this.country, this.region);
  final String country;
  final String region; // matches setup regions: Africa · Americas · Asia-Pacific · Europe · Middle East
}

const _uk = SourceRegion('United Kingdom', 'Europe');
const _us = SourceRegion('United States', 'Americas');
const _india = SourceRegion('India', 'Asia-Pacific');

const Map<String, SourceRegion> _sourceRegions = {
  // United Kingdom
  'bbc news': _uk, 'bbc world': _uk, 'bbc business': _uk,
  'bbc technology': _uk, 'bbc sport': _uk,
  'the guardian world': _uk, 'the guardian business': _uk,
  'the guardian tech': _uk, 'guardian environment': _uk,
  'sky news': _uk, 'sky news world': _uk, 'sky sports': _uk,
  'the independent': _uk, 'the telegraph': _uk,
  'nature': _uk, 'the register': _uk,
  // United States
  'npr news': _us, 'npr business': _us, 'npr technology': _us,
  'cnn': _us, 'cbs news': _us, 'nbc news': _us, 'abc news': _us,
  'fox news': _us, 'new york times': _us, 'nyt world': _us,
  'nyt technology': _us, 'time': _us, 'telemundo': _us,
  'axios': _us, 'politico': _us, 'the hill': _us,
  'cnbc top news': _us, 'marketwatch': _us, 'fortune': _us,
  'business insider': _us, 'yahoo finance': _us,
  'variety': _us, 'deadline': _us, 'rolling stone': _us,
  'techcrunch': _us, 'the verge': _us, 'ars technica': _us,
  'engadget': _us, 'wired': _us, 'mit technology review': _us,
  'venturebeat': _us, 'ieee spectrum': _us, 'hacker news': _us,
  'coindesk': _us, 'decrypt': _us, 'quanta magazine': _us,
  'sciencedaily': _us, 'live science': _us, 'phys.org': _us,
  'inside climate news': _us, 'grist': _us, 'stat news': _us,
  'kff health news': _us, 'zdnet': _us,
  // Europe (non-UK)
  'dw (deutsche welle)': SourceRegion('Germany', 'Europe'),
  'france 24': SourceRegion('France', 'Europe'),
  'euronews': SourceRegion('France', 'Europe'),
  // Middle East
  'al jazeera': SourceRegion('Qatar', 'Middle East'),
  'times of israel': SourceRegion('Israel', 'Middle East'),
  'arab news': SourceRegion('Saudi Arabia', 'Middle East'),
  'the national': SourceRegion('United Arab Emirates', 'Middle East'),
  // Asia-Pacific
  'south china morning post': SourceRegion('Hong Kong', 'Asia-Pacific'),
  'sydney morning herald': SourceRegion('Australia', 'Asia-Pacific'),
  'abc australia': SourceRegion('Australia', 'Asia-Pacific'),
  'times of india': _india, 'ndtv': _india, 'hindustan times': _india,
  'the economic times': _india,
  'the japan times': SourceRegion('Japan', 'Asia-Pacific'),
  'the straits times': SourceRegion('Singapore', 'Asia-Pacific'),
  'cna': SourceRegion('Singapore', 'Asia-Pacific'),
  'the korea herald': SourceRegion('South Korea', 'Asia-Pacific'),
  'bangkok post': SourceRegion('Thailand', 'Asia-Pacific'),
  'philippine daily inquirer': SourceRegion('Philippines', 'Asia-Pacific'),
  'rnz': SourceRegion('New Zealand', 'Asia-Pacific'),
  // Americas (non-US)
  'cbc news': SourceRegion('Canada', 'Americas'),
  'global news': SourceRegion('Canada', 'Americas'),
  'mexico news daily': SourceRegion('Mexico', 'Americas'),
  'buenos aires times': SourceRegion('Argentina', 'Americas'),
  'mercopress': SourceRegion('Uruguay', 'Americas'),
};

SourceRegion? regionOfSource(String source) =>
    _sourceRegions[source.toLowerCase()];

/// Stable partition: articles from the user's country first, then their
/// region, then everywhere else. Order within each tier is preserved, and the
/// result feeds interleaveBySource, so local outlets lead each cycle without
/// pushing the rest of the world out of the feed.
List<Article> regionFirst(
  List<Article> items, {
  String? country,
  String? region,
}) {
  if (country == null && region == null) return items;
  final local = <Article>[];
  final nearby = <Article>[];
  final rest = <Article>[];
  for (final a in items) {
    final r = regionOfSource(a.source);
    if (r == null) {
      rest.add(a);
    } else if (country != null && r.country == country) {
      local.add(a);
    } else if (region != null && r.region == region) {
      nearby.add(a);
    } else {
      rest.add(a);
    }
  }
  return [...local, ...nearby, ...rest];
}
