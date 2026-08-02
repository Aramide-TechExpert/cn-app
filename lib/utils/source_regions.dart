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
  const SourceInfo(this.country, this.segment, this.kind, {this.local = false});
  final String country;
  final String segment;
  final SourceKind kind;

  /// Publishes in the country's own language (not English). Shown ONLY to
  /// users whose picked country matches — locals read in their local
  /// language; everyone else keeps an English feed.
  final bool local;
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
  'daily mail': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the mirror': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'metro': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'evening standard': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the guardian business': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the guardian tech': SourceInfo('United Kingdom', 'United Kingdom', _n),
  // Full roster from the user's UK publisher list (2026-07-18) — all
  // strictly gated nationals, incl. FT/Economist per the no-mixing rule.
  'the times': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the sun': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'i news': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'daily express': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'daily star': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'financial times': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'itv news': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'channel 4 news': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'gb news': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'stv news': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the herald': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the northern echo': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'oxford mail': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'manchester evening news': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'liverpool echo': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'mylondon': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the scotsman': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the yorkshire post': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the news portsmouth': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the manchester mill': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the economist': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the spectator': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'new statesman': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the week': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'the new european': SourceInfo('United Kingdom', 'United Kingdom', _n),
  // Politico Europe moved UK → Europe 2026-07-18 (Brussels/EU-institutions
  // core; it headlines the user's pan-European list).
  'politico europe': SourceInfo('Europe', 'Europe', _n),
  'guido fawkes': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'novara media': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'unherd': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'huffpost uk': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'opendemocracy': SourceInfo('United Kingdom', 'United Kingdom', _n),
  'byline times': SourceInfo('United Kingdom', 'United Kingdom', _n),
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
  // Wire services are global by nature — every region keeps them.
  'associated press': SourceInfo('United States', 'United States', _g),
  'reuters': SourceInfo('United Kingdom', 'United Kingdom', _g),
  'upi': SourceInfo('United States', 'United States', _g),
  'bloomberg': SourceInfo('United States', 'United States', _g),
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
  'la times': SourceInfo('United States', 'United States', _n),
  'washington post': SourceInfo('United States', 'United States', _n),
  'wall street journal': SourceInfo('United States', 'United States', _n),
  'usa today': SourceInfo('United States', 'United States', _n),
  'msnbc': SourceInfo('United States', 'United States', _n),
  'huffpost': SourceInfo('United States', 'United States', _n),
  'the daily beast': SourceInfo('United States', 'United States', _n),
  'vox': SourceInfo('United States', 'United States', _n),
  'yahoo news': SourceInfo('United States', 'United States', _n),
  'pbs newshour': SourceInfo('United States', 'United States', _n),
  'propublica': SourceInfo('United States', 'United States', _n),
  'new york post': SourceInfo('United States', 'United States', _n),
  'national review': SourceInfo('United States', 'United States', _n),
  'the atlantic': SourceInfo('United States', 'United States', _n),
  'washington examiner': SourceInfo('United States', 'United States', _n),
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
  'espn': SourceInfo('United States', 'United States', _t),
  'sports illustrated': SourceInfo('United States', 'United States', _t),
  'the athletic': SourceInfo('United States', 'United States', _t),
  'bleacher report': SourceInfo('United States', 'United States', _t),
  'cbs sports': SourceInfo('United States', 'United States', _t),
  'fox sports': SourceInfo('United States', 'United States', _t),
  'nbc sports': SourceInfo('United States', 'United States', _t),
  'yahoo sports': SourceInfo('United States', 'United States', _t),
  'hollywood reporter': SourceInfo('United States', 'United States', _t),
  'entertainment weekly': SourceInfo('United States', 'United States', _t),
  'people': SourceInfo('United States', 'United States', _t),
  'tmz': SourceInfo('United States', 'United States', _t),
  'billboard': SourceInfo('United States', 'United States', _t),
  'gizmodo': SourceInfo('United States', 'United States', _t),
  'forbes': SourceInfo('United States', 'United States', _t),
  // ── Canada ──
  'cbc news': SourceInfo('Canada', 'Canada', _n),
  'global news': SourceInfo('Canada', 'Canada', _n),
  'national post': SourceInfo('Canada', 'Canada', _n),
  // Full roster from the user's Canada publisher list (2026-07-18) — all
  // strictly gated nationals.
  'ctv news': SourceInfo('Canada', 'Canada', _n),
  'aptn news': SourceInfo('Canada', 'Canada', _n),
  'citynews': SourceInfo('Canada', 'Canada', _n),
  'bnn bloomberg': SourceInfo('Canada', 'Canada', _n),
  'cp24': SourceInfo('Canada', 'Canada', _n),
  'the globe and mail': SourceInfo('Canada', 'Canada', _n),
  'toronto star': SourceInfo('Canada', 'Canada', _n),
  'toronto sun': SourceInfo('Canada', 'Canada', _n),
  'calgary herald': SourceInfo('Canada', 'Canada', _n),
  'edmonton journal': SourceInfo('Canada', 'Canada', _n),
  'ottawa citizen': SourceInfo('Canada', 'Canada', _n),
  'montreal gazette': SourceInfo('Canada', 'Canada', _n),
  'vancouver sun': SourceInfo('Canada', 'Canada', _n),
  'the province': SourceInfo('Canada', 'Canada', _n),
  'london free press': SourceInfo('Canada', 'Canada', _n),
  'windsor star': SourceInfo('Canada', 'Canada', _n),
  'saskatoon starphoenix': SourceInfo('Canada', 'Canada', _n),
  'regina leader-post': SourceInfo('Canada', 'Canada', _n),
  'times colonist': SourceInfo('Canada', 'Canada', _n),
  'winnipeg free press': SourceInfo('Canada', 'Canada', _n),
  'saltwire': SourceInfo('Canada', 'Canada', _n),
  "maclean's": SourceInfo('Canada', 'Canada', _n),
  'the walrus': SourceInfo('Canada', 'Canada', _n),
  'the hill times': SourceInfo('Canada', 'Canada', _n),
  'ipolitics': SourceInfo('Canada', 'Canada', _n),
  'alberta views': SourceInfo('Canada', 'Canada', _n),
  'the logic': SourceInfo('Canada', 'Canada', _n),
  'the narwhal': SourceInfo('Canada', 'Canada', _n),
  'the tyee': SourceInfo('Canada', 'Canada', _n),
  'canadaland': SourceInfo('Canada', 'Canada', _n),
  'national observer': SourceInfo('Canada', 'Canada', _n),
  'the local to': SourceInfo('Canada', 'Canada', _n),
  'the breach': SourceInfo('Canada', 'Canada', _n),
  'ricochet': SourceInfo('Canada', 'Canada', _n),
  'daily hive': SourceInfo('Canada', 'Canada', _n),
  'better dwelling': SourceInfo('Canada', 'Canada', _n),
  'rabble.ca': SourceInfo('Canada', 'Canada', _n),
  'halifax examiner': SourceInfo('Canada', 'Canada', _n),
  'the cjn': SourceInfo('Canada', 'Canada', _n),
  // ── Europe (nationals) ──
  'the local germany': SourceInfo('Germany', 'Europe', _n),
  'rte': SourceInfo('Ireland', 'Europe', _n),
  'ansa english': SourceInfo('Italy', 'Europe', _n),
  'dutchnews': SourceInfo('Netherlands', 'Europe', _n),
  'notes from poland': SourceInfo('Poland', 'Europe', _n),
  'the moscow times': SourceInfo('Russia', 'Europe', _n),
  // Full roster from the user's Europe publisher list (2026-07-18) —
  // English editions of national outlets, all strictly gated nationals.
  'euractiv': SourceInfo('Europe', 'Europe', _n),
  'euobserver': SourceInfo('Europe', 'Europe', _n),
  'balkan insight': SourceInfo('Europe', 'Europe', _n),
  'spiegel international': SourceInfo('Germany', 'Europe', _n),
  'rfi': SourceInfo('France', 'Europe', _n),
  'le monde': SourceInfo('France', 'Europe', _n),
  'el país': SourceInfo('Spain', 'Europe', _n),
  'yle news': SourceInfo('Finland', 'Europe', _n),
  'iceland monitor': SourceInfo('Iceland', 'Europe', _n),
  'tvp world': SourceInfo('Poland', 'Europe', _n),
  'kathimerini': SourceInfo('Greece', 'Europe', _n),
  'times of malta': SourceInfo('Malta', 'Europe', _n),
  'luxembourg times': SourceInfo('Luxembourg', 'Europe', _n),
  'telex': SourceInfo('Hungary', 'Europe', _n),
  'the irish times': SourceInfo('Ireland', 'Europe', _n),
  'irish examiner': SourceInfo('Ireland', 'Europe', _n),
  'irish independent': SourceInfo('Ireland', 'Europe', _n),
  'kyiv independent': SourceInfo('Ukraine', 'Europe', _n),
  'ukrayinska pravda': SourceInfo('Ukraine', 'Europe', _n),
  'ukrinform': SourceInfo('Ukraine', 'Europe', _n),
  'meduza': SourceInfo('Russia', 'Europe', _n),
  'novaya gazeta europe': SourceInfo('Russia', 'Europe', _n),
  // Country-depth pass (2026-07-18): every country ≥2 English outlets so
  // the strict single-country roster is never thin.
  'the local france': SourceInfo('France', 'Europe', _n),
  'the local spain': SourceInfo('Spain', 'Europe', _n),
  'the local italy': SourceInfo('Italy', 'Europe', _n),
  'the local sweden': SourceInfo('Sweden', 'Europe', _n),
  'the local denmark': SourceInfo('Denmark', 'Europe', _n),
  'the local norway': SourceInfo('Norway', 'Europe', _n),
  'the local austria': SourceInfo('Austria', 'Europe', _n),
  'the local switzerland': SourceInfo('Switzerland', 'Europe', _n),
  'nl times': SourceInfo('Netherlands', 'Europe', _n),
  'brussels times': SourceInfo('Belgium', 'Europe', _n),
  'copenhagen post': SourceInfo('Denmark', 'Europe', _n),
  'helsinki times': SourceInfo('Finland', 'Europe', _n),
  'sweden herald': SourceInfo('Sweden', 'Europe', _n),
  'norway today': SourceInfo('Norway', 'Europe', _n),
  'the first news': SourceInfo('Poland', 'Europe', _n),
  'prague morning': SourceInfo('Czechia', 'Europe', _n),
  'brno daily': SourceInfo('Czechia', 'Europe', _n),
  'vindobona': SourceInfo('Austria', 'Europe', _n),
  'swissinfo': SourceInfo('Switzerland', 'Europe', _n),
  'the portugal news': SourceInfo('Portugal', 'Europe', _n),
  'portugal resident': SourceInfo('Portugal', 'Europe', _n),
  'greek reporter': SourceInfo('Greece', 'Europe', _n),
  'hungary today': SourceInfo('Hungary', 'Europe', _n),
  'daily news hungary': SourceInfo('Hungary', 'Europe', _n),
  'romania insider': SourceInfo('Romania', 'Europe', _n),
  "nine o'clock": SourceInfo('Romania', 'Europe', _n),
  'cyprus mail': SourceInfo('Cyprus', 'Europe', _n),
  'in-cyprus': SourceInfo('Cyprus', 'Europe', _n),
  'malta today': SourceInfo('Malta', 'Europe', _n),
  'rtl today': SourceInfo('Luxembourg', 'Europe', _n),
  'iceland review': SourceInfo('Iceland', 'Europe', _n),
  // Native-language outlets (2026-07-18, user decision: "use every
  // sources... they're reading in their locals") — local: true means
  // visible ONLY when the user's picked country matches.
  'tagesschau': SourceInfo('Germany', 'Europe', _n, local: true),
  'bild': SourceInfo('Germany', 'Europe', _n, local: true),
  'die welt': SourceInfo('Germany', 'Europe', _n, local: true),
  'süddeutsche zeitung': SourceInfo('Germany', 'Europe', _n, local: true),
  'faz': SourceInfo('Germany', 'Europe', _n, local: true),
  'die zeit': SourceInfo('Germany', 'Europe', _n, local: true),
  'handelsblatt': SourceInfo('Germany', 'Europe', _n, local: true),
  'stern': SourceInfo('Germany', 'Europe', _n, local: true),
  'n-tv': SourceInfo('Germany', 'Europe', _n, local: true),
  'france info': SourceInfo('France', 'Europe', _n, local: true),
  'le figaro': SourceInfo('France', 'Europe', _n, local: true),
  'libération': SourceInfo('France', 'Europe', _n, local: true),
  'les échos': SourceInfo('France', 'Europe', _n, local: true),
  'le parisien': SourceInfo('France', 'Europe', _n, local: true),
  'mediapart': SourceInfo('France', 'Europe', _n, local: true),
  'bfm tv': SourceInfo('France', 'Europe', _n, local: true),
  'rai news': SourceInfo('Italy', 'Europe', _n, local: true),
  'corriere della sera': SourceInfo('Italy', 'Europe', _n, local: true),
  'la repubblica': SourceInfo('Italy', 'Europe', _n, local: true),
  'la stampa': SourceInfo('Italy', 'Europe', _n, local: true),
  'il sole 24 ore': SourceInfo('Italy', 'Europe', _n, local: true),
  'il fatto quotidiano': SourceInfo('Italy', 'Europe', _n, local: true),
  'tgcom24': SourceInfo('Italy', 'Europe', _n, local: true),
  'rtve': SourceInfo('Spain', 'Europe', _n, local: true),
  'el mundo': SourceInfo('Spain', 'Europe', _n, local: true),
  'abc españa': SourceInfo('Spain', 'Europe', _n, local: true),
  'la vanguardia': SourceInfo('Spain', 'Europe', _n, local: true),
  'eldiario.es': SourceInfo('Spain', 'Europe', _n, local: true),
  'expansión': SourceInfo('Spain', 'Europe', _n, local: true),
  'nos': SourceInfo('Netherlands', 'Europe', _n, local: true),
  'de volkskrant': SourceInfo('Netherlands', 'Europe', _n, local: true),
  'de telegraaf': SourceInfo('Netherlands', 'Europe', _n, local: true),
  'nrc': SourceInfo('Netherlands', 'Europe', _n, local: true),
  'het laatste nieuws': SourceInfo('Belgium', 'Europe', _n, local: true),
  'de morgen': SourceInfo('Belgium', 'Europe', _n, local: true),
  'vrt nws': SourceInfo('Belgium', 'Europe', _n, local: true),
  'rtbf': SourceInfo('Belgium', 'Europe', _n, local: true),
  'svt nyheter': SourceInfo('Sweden', 'Europe', _n, local: true),
  'aftonbladet': SourceInfo('Sweden', 'Europe', _n, local: true),
  'svenska dagbladet': SourceInfo('Sweden', 'Europe', _n, local: true),
  'dagens nyheter': SourceInfo('Sweden', 'Europe', _n, local: true),
  'expressen': SourceInfo('Sweden', 'Europe', _n, local: true),
  'nrk': SourceInfo('Norway', 'Europe', _n, local: true),
  'vg': SourceInfo('Norway', 'Europe', _n, local: true),
  'aftenposten': SourceInfo('Norway', 'Europe', _n, local: true),
  'dr nyheder': SourceInfo('Denmark', 'Europe', _n, local: true),
  'politiken': SourceInfo('Denmark', 'Europe', _n, local: true),
  'jyllands-posten': SourceInfo('Denmark', 'Europe', _n, local: true),
  'ekstra bladet': SourceInfo('Denmark', 'Europe', _n, local: true),
  'helsingin sanomat': SourceInfo('Finland', 'Europe', _n, local: true),
  'ilta-sanomat': SourceInfo('Finland', 'Europe', _n, local: true),
  'tvp info': SourceInfo('Poland', 'Europe', _n, local: true),
  'gazeta wyborcza': SourceInfo('Poland', 'Europe', _n, local: true),
  'onet': SourceInfo('Poland', 'Europe', _n, local: true),
  'rzeczpospolita': SourceInfo('Poland', 'Europe', _n, local: true),
  'čt24': SourceInfo('Czechia', 'Europe', _n, local: true),
  'idnes': SourceInfo('Czechia', 'Europe', _n, local: true),
  'lidové noviny': SourceInfo('Czechia', 'Europe', _n, local: true),
  'orf': SourceInfo('Austria', 'Europe', _n, local: true),
  'kronen zeitung': SourceInfo('Austria', 'Europe', _n, local: true),
  'kurier': SourceInfo('Austria', 'Europe', _n, local: true),
  'die presse': SourceInfo('Austria', 'Europe', _n, local: true),
  'nzz': SourceInfo('Switzerland', 'Europe', _n, local: true),
  'blick': SourceInfo('Switzerland', 'Europe', _n, local: true),
  'le temps': SourceInfo('Switzerland', 'Europe', _n, local: true),
  '20 minuten': SourceInfo('Switzerland', 'Europe', _n, local: true),
  'rtp': SourceInfo('Portugal', 'Europe', _n, local: true),
  'expresso': SourceInfo('Portugal', 'Europe', _n, local: true),
  'ert': SourceInfo('Greece', 'Europe', _n, local: true),
  'to vima': SourceInfo('Greece', 'Europe', _n, local: true),
  'ta nea': SourceInfo('Greece', 'Europe', _n, local: true),
  '24.hu': SourceInfo('Hungary', 'Europe', _n, local: true),
  'libertatea': SourceInfo('Romania', 'Europe', _n, local: true),
  'hotnews': SourceInfo('Romania', 'Europe', _n, local: true),
  'g4media': SourceInfo('Romania', 'Europe', _n, local: true),
  'suspilne': SourceInfo('Ukraine', 'Europe', _n, local: true),
  'phileleftheros': SourceInfo('Cyprus', 'Europe', _n, local: true),
  'morgunblaðið': SourceInfo('Iceland', 'Europe', _n, local: true),
  'rúv': SourceInfo('Iceland', 'Europe', _n, local: true),
  'la presse': SourceInfo('Canada', 'Canada', _n, local: true),
  'le devoir': SourceInfo('Canada', 'Canada', _n, local: true),
  'le journal de montréal': SourceInfo('Canada', 'Canada', _n, local: true),
  'tva nouvelles': SourceInfo('Canada', 'Canada', _n, local: true),
  'radio-canada': SourceInfo('Canada', 'Canada', _n, local: true),
  // ── Africa (nationals) ──
  'punch': SourceInfo('Nigeria', 'Africa', _n),
  'premium times': SourceInfo('Nigeria', 'Africa', _n),
  'vanguard': SourceInfo('Nigeria', 'Africa', _n),
  'daily post': SourceInfo('Nigeria', 'Africa', _n),
  'daily trust': SourceInfo('Nigeria', 'Africa', _n),
  'channels tv': SourceInfo('Nigeria', 'Africa', _n),
  'businessday ng': SourceInfo('Nigeria', 'Africa', _n),
  'legit.ng': SourceInfo('Nigeria', 'Africa', _n),
  'sahara reporters': SourceInfo('Nigeria', 'Africa', _n),
  'thisday': SourceInfo('Nigeria', 'Africa', _n),
  'tribune online': SourceInfo('Nigeria', 'Africa', _n),
  'leadership': SourceInfo('Nigeria', 'Africa', _n),
  'myjoyonline': SourceInfo('Ghana', 'Africa', _n),
  '3news': SourceInfo('Ghana', 'Africa', _n),
  'adom online': SourceInfo('Ghana', 'Africa', _n),
  'ghanaian times': SourceInfo('Ghana', 'Africa', _n),
  'nation africa': SourceInfo('Kenya', 'Africa', _n),
  'the standard': SourceInfo('Kenya', 'Africa', _n),
  'tuko': SourceInfo('Kenya', 'Africa', _n),
  'kbc': SourceInfo('Kenya', 'Africa', _n),
  'capital fm': SourceInfo('Kenya', 'Africa', _n),
  'daily maverick': SourceInfo('South Africa', 'Africa', _n),
  'the south african': SourceInfo('South Africa', 'Africa', _n),
  // Pan-African outlets: country == segment → visible to every Africa
  // user regardless of country pick.
  'bbc africa': SourceInfo('Africa', 'Africa', _n),
  'allafrica': SourceInfo('Africa', 'Africa', _n),
  'africanews': SourceInfo('Africa', 'Africa', _n),
  'the africa report': SourceInfo('Africa', 'Africa', _n),
  'cnbc africa': SourceInfo('Africa', 'Africa', _n),
  'apa news': SourceInfo('Africa', 'Africa', _n),
  'the eastafrican': SourceInfo('Africa', 'Africa', _n),
  // Full roster from the user's Africa publisher list (2026-07-18) —
  // per-country tags for the strict single-country rosters.
  'the guardian nigeria': SourceInfo('Nigeria', 'Africa', _n),
  'the nation nigeria': SourceInfo('Nigeria', 'Africa', _n),
  'the sun nigeria': SourceInfo('Nigeria', 'Africa', _n),
  'independent nigeria': SourceInfo('Nigeria', 'Africa', _n),
  'nairametrics': SourceInfo('Nigeria', 'Africa', _n),
  'thecable': SourceInfo('Nigeria', 'Africa', _n),
  'tvc news': SourceInfo('Nigeria', 'Africa', _n),
  'arise news': SourceInfo('Nigeria', 'Africa', _n),
  'nta': SourceInfo('Nigeria', 'Africa', _n),
  'humangle': SourceInfo('Nigeria', 'Africa', _n),
  'icir': SourceInfo('Nigeria', 'Africa', _n),
  'dataphyte': SourceInfo('Nigeria', 'Africa', _n),
  'pulse nigeria': SourceInfo('Nigeria', 'Africa', _n),
  'financial watch': SourceInfo('Nigeria', 'Africa', _n),
  'nan': SourceInfo('Nigeria', 'Africa', _n),
  'graphic online': SourceInfo('Ghana', 'Africa', _n),
  'ghanaweb': SourceInfo('Ghana', 'Africa', _n),
  'citi newsroom': SourceInfo('Ghana', 'Africa', _n),
  'pulse ghana': SourceInfo('Ghana', 'Africa', _n),
  'yen.com.gh': SourceInfo('Ghana', 'Africa', _n),
  'modernghana': SourceInfo('Ghana', 'Africa', _n),
  'peacefmonline': SourceInfo('Ghana', 'Africa', _n),
  'ghana news agency': SourceInfo('Ghana', 'Africa', _n),
  'daily guide': SourceInfo('Ghana', 'Africa', _n),
  'the chronicle ghana': SourceInfo('Ghana', 'Africa', _n),
  'business & financial times': SourceInfo('Ghana', 'Africa', _n),
  'the fourth estate': SourceInfo('Ghana', 'Africa', _n),
  'starr fm': SourceInfo('Ghana', 'Africa', _n),
  'le soleil': SourceInfo('Senegal', 'Africa', _n, local: true),
  'aps senegal': SourceInfo('Senegal', 'Africa', _n, local: true),
  'fraternité matin': SourceInfo("Côte d'Ivoire", 'Africa', _n, local: true),
  'aip': SourceInfo("Côte d'Ivoire", 'Africa', _n, local: true),
  "l'observateur paalga": SourceInfo('Burkina Faso', 'Africa', _n, local: true),
  'lefaso.net': SourceInfo('Burkina Faso', 'Africa', _n, local: true),
  'la nouvelle tribune': SourceInfo('Benin', 'Africa', _n, local: true),
  'abp benin': SourceInfo('Benin', 'Africa', _n, local: true),
  'daily observer liberia': SourceInfo('Liberia', 'Africa', _n),
  'frontpage africa': SourceInfo('Liberia', 'Africa', _n),
  'awoko': SourceInfo('Sierra Leone', 'Africa', _n),
  'sierra leone telegraph': SourceInfo('Sierra Leone', 'Africa', _n),
  'foroyaa': SourceInfo('Gambia', 'Africa', _n),
  'the point gambia': SourceInfo('Gambia', 'Africa', _n),
  'news24': SourceInfo('South Africa', 'Africa', _n),
  'iol': SourceInfo('South Africa', 'Africa', _n),
  'timeslive': SourceInfo('South Africa', 'Africa', _n),
  'the citizen': SourceInfo('South Africa', 'Africa', _n),
  'mail & guardian': SourceInfo('South Africa', 'Africa', _n),
  'sowetanlive': SourceInfo('South Africa', 'Africa', _n),
  'businesstech': SourceInfo('South Africa', 'Africa', _n),
  'businesslive': SourceInfo('South Africa', 'Africa', _n),
  'mybroadband': SourceInfo('South Africa', 'Africa', _n),
  'moneyweb': SourceInfo('South Africa', 'Africa', _n),
  'daily investor': SourceInfo('South Africa', 'Africa', _n),
  'enca': SourceInfo('South Africa', 'Africa', _n),
  'sabc news': SourceInfo('South Africa', 'Africa', _n),
  'eyewitness news': SourceInfo('South Africa', 'Africa', _n),
  'daily sun': SourceInfo('South Africa', 'Africa', _n),
  'isolezwe': SourceInfo('South Africa', 'Africa', _n, local: true),
  'the herald zimbabwe': SourceInfo('Zimbabwe', 'Africa', _n),
  'newsday zimbabwe': SourceInfo('Zimbabwe', 'Africa', _n),
  'the chronicle zimbabwe': SourceInfo('Zimbabwe', 'Africa', _n),
  'zambia daily mail': SourceInfo('Zambia', 'Africa', _n),
  'times of zambia': SourceInfo('Zambia', 'Africa', _n),
  'news diggers': SourceInfo('Zambia', 'Africa', _n),
  'the namibian': SourceInfo('Namibia', 'Africa', _n),
  'namibian sun': SourceInfo('Namibia', 'Africa', _n),
  'mmegi': SourceInfo('Botswana', 'Africa', _n),
  'the voice botswana': SourceInfo('Botswana', 'Africa', _n),
  'the nation malawi': SourceInfo('Malawi', 'Africa', _n),
  'nyasa times': SourceInfo('Malawi', 'Africa', _n),
  'times of eswatini': SourceInfo('Eswatini', 'Africa', _n),
  'eswatini observer': SourceInfo('Eswatini', 'Africa', _n),
  'jornal de angola': SourceInfo('Angola', 'Africa', _n, local: true),
  'angop': SourceInfo('Angola', 'Africa', _n, local: true),
  'kenyans.co.ke': SourceInfo('Kenya', 'Africa', _n),
  'the star kenya': SourceInfo('Kenya', 'Africa', _n),
  'citizen digital': SourceInfo('Kenya', 'Africa', _n),
  'business daily africa': SourceInfo('Kenya', 'Africa', _n),
  'kenyan wall street': SourceInfo('Kenya', 'Africa', _n),
  'people daily': SourceInfo('Kenya', 'Africa', _n),
  'the citizen tanzania': SourceInfo('Tanzania', 'Africa', _n),
  'mwananchi': SourceInfo('Tanzania', 'Africa', _n, local: true),
  'daily monitor': SourceInfo('Uganda', 'Africa', _n),
  'new vision': SourceInfo('Uganda', 'Africa', _n),
  'the reporter ethiopia': SourceInfo('Ethiopia', 'Africa', _n),
  'fana': SourceInfo('Ethiopia', 'Africa', _n),
  'garowe online': SourceInfo('Somalia', 'Africa', _n),
  'shabelle media': SourceInfo('Somalia', 'Africa', _n),
  'sudan tribune': SourceInfo('Sudan', 'Africa', _n),
  'radio dabanga': SourceInfo('Sudan', 'Africa', _n),
  'ahram online': SourceInfo('Egypt', 'Africa', _n),
  'egypt independent': SourceInfo('Egypt', 'Africa', _n),
  'mada masr': SourceInfo('Egypt', 'Africa', _n),
  'al-masry al-youm': SourceInfo('Egypt', 'Africa', _n, local: true),
  'le matin maroc': SourceInfo('Morocco', 'Africa', _n, local: true),
  'morocco world news': SourceInfo('Morocco', 'Africa', _n),
  'el watan': SourceInfo('Algeria', 'Africa', _n, local: true),
  'el moudjahid': SourceInfo('Algeria', 'Africa', _n, local: true),
  'la presse de tunisie': SourceInfo('Tunisia', 'Africa', _n, local: true),
  'business news tunisie': SourceInfo('Tunisia', 'Africa', _n, local: true),
  'libya observer': SourceInfo('Libya', 'Africa', _n),
  'libya herald': SourceInfo('Libya', 'Africa', _n),
  'cameroon tribune': SourceInfo('Cameroon', 'Africa', _n),
  'crtv': SourceInfo('Cameroon', 'Africa', _n),
  'le potentiel': SourceInfo('DR Congo', 'Africa', _n, local: true),
  'radio okapi': SourceInfo('DR Congo', 'Africa', _n, local: true),
  'les dépêches de brazzaville': SourceInfo('Republic of the Congo', 'Africa', _n, local: true),
  'alwihda info': SourceInfo('Chad', 'Africa', _n, local: true),
  "l'express de madagascar": SourceInfo('Madagascar', 'Africa', _n, local: true),
  'midi madagasikara': SourceInfo('Madagascar', 'Africa', _n, local: true),
  "l'express maurice": SourceInfo('Mauritius', 'Africa', _n, local: true),
  'le mauricien': SourceInfo('Mauritius', 'Africa', _n, local: true),
  // ── Middle East (nationals) — full roster 2026-08-02 ──
  // Pan-regional tier (country == segment: serves every ME country)
  'al arabiya': SourceInfo('Middle East', 'Middle East', _n),
  'al-monitor': SourceInfo('Middle East', 'Middle East', _n),
  'asharq al-awsat': SourceInfo('Middle East', 'Middle East', _n),
  'middle east eye': SourceInfo('Middle East', 'Middle East', _n),
  'al-quds al-arabi': SourceInfo('Middle East', 'Middle East', _n, local: true),
  'sky news arabia': SourceInfo('Middle East', 'Middle East', _n, local: true),
  'asharq news': SourceInfo('Middle East', 'Middle East', _n, local: true),
  // United Arab Emirates
  'the national': SourceInfo('United Arab Emirates', 'Middle East', _n),
  'gulf news': SourceInfo('United Arab Emirates', 'Middle East', _n),
  'khaleej times': SourceInfo('United Arab Emirates', 'Middle East', _n),
  'arabian business': SourceInfo('United Arab Emirates', 'Middle East', _n),
  'wam': SourceInfo('United Arab Emirates', 'Middle East', _n),
  'al-bayan': SourceInfo('United Arab Emirates', 'Middle East', _n, local: true),
  'emarat al youm': SourceInfo('United Arab Emirates', 'Middle East', _n, local: true),
  // Saudi Arabia
  'arab news': SourceInfo('Saudi Arabia', 'Middle East', _n),
  'saudi press agency': SourceInfo('Saudi Arabia', 'Middle East', _n),
  'al riyadh': SourceInfo('Saudi Arabia', 'Middle East', _n, local: true),
  'okaz': SourceInfo('Saudi Arabia', 'Middle East', _n, local: true),
  'al-watan saudi': SourceInfo('Saudi Arabia', 'Middle East', _n, local: true),
  'al eqtisadiah': SourceInfo('Saudi Arabia', 'Middle East', _n, local: true),
  'sabq': SourceInfo('Saudi Arabia', 'Middle East', _n, local: true),
  // Egypt — tagged Africa (its home segment) but also surfaces under
  // Middle East via _secondSegment (the user's ME list includes Egypt)
  // (al-masry al-youm already tagged in the Africa block above)
  'al-ahram': SourceInfo('Egypt', 'Africa', _n, local: true),
  'al-akhbar egypt': SourceInfo('Egypt', 'Africa', _n, local: true),
  'youm7': SourceInfo('Egypt', 'Africa', _n, local: true),
  // Qatar
  'the peninsula': SourceInfo('Qatar', 'Middle East', _n),
  'gulf times': SourceInfo('Qatar', 'Middle East', _n),
  'al-raya': SourceInfo('Qatar', 'Middle East', _n, local: true),
  // Kuwait
  'arab times': SourceInfo('Kuwait', 'Middle East', _n),
  'al-anba': SourceInfo('Kuwait', 'Middle East', _n, local: true),
  // Bahrain
  'gulf daily news': SourceInfo('Bahrain', 'Middle East', _n),
  'akhbar al-khaleej': SourceInfo('Bahrain', 'Middle East', _n, local: true),
  'al ayam bahrain': SourceInfo('Bahrain', 'Middle East', _n, local: true),
  'bahrain news agency': SourceInfo('Bahrain', 'Middle East', _n, local: true),
  // Oman
  'times of oman': SourceInfo('Oman', 'Middle East', _n),
  'oman observer': SourceInfo('Oman', 'Middle East', _n),
  // Lebanon
  'al-akhbar': SourceInfo('Lebanon', 'Middle East', _n, local: true),
  'an-nahar': SourceInfo('Lebanon', 'Middle East', _n, local: true),
  "l'orient-le jour": SourceInfo('Lebanon', 'Middle East', _n, local: true),
  // Jordan
  'the jordan times': SourceInfo('Jordan', 'Middle East', _n),
  'al-ghad': SourceInfo('Jordan', 'Middle East', _n, local: true),
  // Syria
  'sana': SourceInfo('Syria', 'Middle East', _n),
  'al-watan syria': SourceInfo('Syria', 'Middle East', _n, local: true),
  // Iraq
  'rudaw': SourceInfo('Iraq', 'Middle East', _n),
  'al mada': SourceInfo('Iraq', 'Middle East', _n, local: true),
  // Israel
  'times of israel': SourceInfo('Israel', 'Middle East', _n),
  'the jerusalem post': SourceInfo('Israel', 'Middle East', _n),
  'haaretz': SourceInfo('Israel', 'Middle East', _n),
  'ynetnews': SourceInfo('Israel', 'Middle East', _n),
  // Palestine
  'wafa news agency': SourceInfo('Palestine', 'Middle East', _n),
  "ma'an news agency": SourceInfo('Palestine', 'Middle East', _n, local: true),
  // Turkey
  'hurriyet daily news': SourceInfo('Turkey', 'Middle East', _n),
  'daily sabah': SourceInfo('Turkey', 'Middle East', _n),
  'trt world': SourceInfo('Turkey', 'Middle East', _n),
  'anadolu agency': SourceInfo('Turkey', 'Middle East', _n),
  // Iran
  'tehran times': SourceInfo('Iran', 'Middle East', _n),
  'irna': SourceInfo('Iran', 'Middle East', _n),
  // ── India — full roster 2026-08-02 (single-country segment: locals
  // show to every India user, like French outlets do for Canada) ──
  'times of india': SourceInfo('India', 'India', _n),
  'ndtv': SourceInfo('India', 'India', _n),
  'hindustan times': SourceInfo('India', 'India', _n),
  'the economic times': SourceInfo('India', 'India', _n),
  'the hindu': SourceInfo('India', 'India', _n),
  'the indian express': SourceInfo('India', 'India', _n),
  'business standard': SourceInfo('India', 'India', _n),
  'the telegraph india': SourceInfo('India', 'India', _n),
  'deccan herald': SourceInfo('India', 'India', _n),
  'the asian age': SourceInfo('India', 'India', _n),
  'india today': SourceInfo('India', 'India', _n),
  'cnn-news18': SourceInfo('India', 'India', _n),
  'cnbc-tv18': SourceInfo('India', 'India', _n),
  'republic tv': SourceInfo('India', 'India', _n),
  'pti': SourceInfo('India', 'India', _n),
  'ani': SourceInfo('India', 'India', _n),
  'uni india': SourceInfo('India', 'India', _n),
  'the wire': SourceInfo('India', 'India', _n),
  'the news minute': SourceInfo('India', 'India', _n),
  'scroll.in': SourceInfo('India', 'India', _n),
  'newslaundry': SourceInfo('India', 'India', _n),
  'the quint': SourceInfo('India', 'India', _n),
  'aaj tak': SourceInfo('India', 'India', _n, local: true),
  'dainik jagran': SourceInfo('India', 'India', _n, local: true),
  'dainik bhaskar': SourceInfo('India', 'India', _n, local: true),
  'amar ujala': SourceInfo('India', 'India', _n, local: true),
  'hindustan hindi': SourceInfo('India', 'India', _n, local: true),
  'navbharat times': SourceInfo('India', 'India', _n, local: true),
  'anandabazar patrika': SourceInfo('India', 'India', _n, local: true),
  'malayala manorama': SourceInfo('India', 'India', _n, local: true),
  'eenadu': SourceInfo('India', 'India', _n, local: true),
  'daily thanthi': SourceInfo('India', 'India', _n, local: true),
  'lokmat': SourceInfo('India', 'India', _n, local: true),
  'gujarat samachar': SourceInfo('India', 'India', _n, local: true),
  'punjab kesari': SourceInfo('India', 'India', _n, local: true),
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
  'Europe': [
    'Austria', 'Belgium', 'Cyprus', 'Czechia', 'Denmark', 'Finland',
    'France', 'Germany', 'Greece', 'Hungary', 'Iceland', 'Ireland', 'Italy',
    'Luxembourg', 'Malta', 'Netherlands', 'Norway', 'Poland', 'Portugal',
    'Romania', 'Russia', 'Spain', 'Sweden', 'Switzerland', 'Ukraine',
  ],
  'Africa': [
    'Nigeria', 'Ghana', 'Kenya', 'South Africa', 'Senegal', "Côte d'Ivoire",
    'Burkina Faso', 'Benin', 'Liberia', 'Sierra Leone', 'Gambia',
    'Zimbabwe', 'Zambia', 'Namibia', 'Botswana', 'Malawi', 'Eswatini',
    'Angola', 'Tanzania', 'Uganda', 'Ethiopia', 'Somalia', 'Sudan',
    'Egypt', 'Morocco', 'Algeria', 'Tunisia', 'Libya', 'Cameroon',
    'DR Congo', 'Madagascar', 'Mauritius',
  ],
  'Middle East': [
    'United Arab Emirates', 'Saudi Arabia', 'Qatar', 'Kuwait', 'Bahrain',
    'Oman', 'Egypt', 'Lebanon', 'Jordan', 'Syria', 'Iraq', 'Israel',
    'Palestine', 'Turkey', 'Iran',
  ],
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
  'Iceland': 'Europe', 'Malta': 'Europe', 'Luxembourg': 'Europe',
  'Serbia': 'Europe', 'Cyprus': 'Europe',
  // Africa
  'Nigeria': 'Africa', 'Ghana': 'Africa', 'Kenya': 'Africa',
  'South Africa': 'Africa', 'Egypt': 'Africa', 'Ethiopia': 'Africa',
  'Uganda': 'Africa', 'Tanzania': 'Africa', 'Cameroon': 'Africa',
  'Senegal': 'Africa', 'Zimbabwe': 'Africa', 'Zambia': 'Africa',
  'Rwanda': 'Africa', 'Morocco': 'Africa', 'Algeria': 'Africa',
  'Tunisia': 'Africa', "Côte d'Ivoire": 'Africa', 'Ivory Coast': 'Africa',
  'Burkina Faso': 'Africa', 'Benin': 'Africa', 'Liberia': 'Africa',
  'Sierra Leone': 'Africa', 'Gambia': 'Africa', 'Namibia': 'Africa',
  'Botswana': 'Africa', 'Malawi': 'Africa', 'Eswatini': 'Africa',
  'Angola': 'Africa', 'Somalia': 'Africa', 'Sudan': 'Africa',
  'Libya': 'Africa', 'DR Congo': 'Africa',
  'Republic of the Congo': 'Africa', 'Chad': 'Africa',
  'Madagascar': 'Africa', 'Mauritius': 'Africa',
  // Middle East
  'Israel': 'Middle East', 'Saudi Arabia': 'Middle East',
  'United Arab Emirates': 'Middle East', 'Qatar': 'Middle East',
  'Turkey': 'Middle East', 'Kuwait': 'Middle East', 'Jordan': 'Middle East',
  'Lebanon': 'Middle East', 'Bahrain': 'Middle East', 'Oman': 'Middle East',
  'Syria': 'Middle East', 'Iraq': 'Middle East', 'Palestine': 'Middle East',
  'Iran': 'Middle East', 'Yemen': 'Middle East',
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

/// ISO 3166 alpha-2 → country name, for location providers that only return
/// a code (country.is).
const Map<String, String> isoToCountry = {
  'NG': 'Nigeria', 'GH': 'Ghana', 'KE': 'Kenya', 'ZA': 'South Africa',
  'EG': 'Egypt', 'ET': 'Ethiopia', 'UG': 'Uganda', 'TZ': 'Tanzania',
  'CM': 'Cameroon', 'SN': 'Senegal', 'ZW': 'Zimbabwe', 'ZM': 'Zambia',
  'RW': 'Rwanda', 'MA': 'Morocco', 'DZ': 'Algeria', 'TN': 'Tunisia',
  'CI': 'Ivory Coast', 'BF': 'Burkina Faso', 'BJ': 'Benin',
  'LR': 'Liberia', 'SL': 'Sierra Leone', 'GM': 'Gambia', 'NA': 'Namibia',
  'BW': 'Botswana', 'MW': 'Malawi', 'SZ': 'Eswatini', 'AO': 'Angola',
  'SO': 'Somalia', 'SD': 'Sudan', 'LY': 'Libya', 'CD': 'DR Congo',
  'CG': 'Republic of the Congo', 'TD': 'Chad', 'MG': 'Madagascar',
  'MU': 'Mauritius',
  'US': 'United States', 'GB': 'United Kingdom', 'CA': 'Canada',
  'IN': 'India',
  'DE': 'Germany', 'FR': 'France', 'IE': 'Ireland', 'IT': 'Italy',
  'NL': 'Netherlands', 'PL': 'Poland', 'RU': 'Russia', 'ES': 'Spain',
  'PT': 'Portugal', 'SE': 'Sweden', 'NO': 'Norway', 'DK': 'Denmark',
  'FI': 'Finland', 'BE': 'Belgium', 'AT': 'Austria', 'CH': 'Switzerland',
  'GR': 'Greece', 'CZ': 'Czechia', 'UA': 'Ukraine', 'RO': 'Romania',
  'HU': 'Hungary', 'IS': 'Iceland', 'MT': 'Malta', 'LU': 'Luxembourg',
  'RS': 'Serbia', 'CY': 'Cyprus',
  'IL': 'Israel', 'SA': 'Saudi Arabia', 'AE': 'United Arab Emirates',
  'QA': 'Qatar', 'TR': 'Turkey', 'KW': 'Kuwait', 'JO': 'Jordan',
  'LB': 'Lebanon', 'BH': 'Bahrain', 'OM': 'Oman', 'SY': 'Syria',
  'IQ': 'Iraq', 'PS': 'Palestine', 'IR': 'Iran', 'YE': 'Yemen',
  'JP': 'Japan', 'KR': 'South Korea', 'SG': 'Singapore', 'HK': 'Hong Kong',
  'CN': 'China', 'TW': 'Taiwan', 'TH': 'Thailand', 'PH': 'Philippines',
  'ID': 'Indonesia', 'MY': 'Malaysia', 'VN': 'Vietnam', 'PK': 'Pakistan',
  'BD': 'Bangladesh', 'LK': 'Sri Lanka', 'NP': 'Nepal',
  'AU': 'Australia', 'NZ': 'New Zealand',
  'MX': 'Mexico', 'AR': 'Argentina', 'BR': 'Brazil', 'CO': 'Colombia',
  'UY': 'Uruguay', 'CL': 'Chile', 'PE': 'Peru', 'EC': 'Ecuador',
  'VE': 'Venezuela', 'BO': 'Bolivia', 'PY': 'Paraguay',
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
/// - a picked country narrows further: ONLY that country's nationals show
///   (single-country roster, user decision 2026-07-18); "All <segment>"
///   (no country) keeps every national in the segment
/// Countries that belong to two segments: Egypt sits in both the Africa and
/// Middle East pickers, so its outlets pass the segment check for either.
const Map<String, String> _secondSegment = {'Egypt': 'Middle East'};

bool _inSegment(SourceInfo i, String segment) =>
    i.segment == segment || _secondSegment[i.country] == segment;

bool sourceVisible(String source, Map<String, dynamic>? meta) {
  final i = sourceInfo(source);
  if (i == null || i.kind != SourceKind.national) return true;
  final segment = activeSegment(meta);
  if (segment == null) return i.segment != 'Africa' && !i.local;
  if (!_inSegment(i, segment)) return false;
  final country = activeCountry(meta);
  // No country picked: English nationals only — except single-country
  // segments (US/UK/Canada/India), where the segment IS the country, so
  // its local-language outlets (e.g. French Canada) are in scope.
  if (country == null) return !i.local || i.country == segment;
  // Country picked: only that country's outlets — plus pan-segment
  // outlets (country == segment, e.g. Africanews, Politico Europe),
  // which serve every country in their region.
  return i.country == country || i.country == segment;
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
