import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/source_signals.dart';
import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../utils/format.dart';

/// A small pill used by the signal badges. Sized down per design.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg, this.icon});
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: fg),
            const SizedBox(width: 2),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

class ImpactBadge extends StatelessWidget {
  const ImpactBadge({super.key, required this.impact});
  final String impact;
  @override
  Widget build(BuildContext context) {
    final col = context.colors.impact(impact);
    return _Pill(
      label: impact.toUpperCase(),
      bg: col.withValues(alpha: 0.16),
      fg: col,
    );
  }
}

class TrustPill extends StatelessWidget {
  const TrustPill({super.key, required this.score});
  final int? score;
  @override
  Widget build(BuildContext context) {
    if (score == null || score == 0) return const SizedBox.shrink();
    const green = Color(0xFF30A46C);
    return _Pill(
      label: '$score%',
      bg: green.withValues(alpha: 0.16),
      fg: green,
      icon: Icons.verified_outlined,
    );
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Pill(
      label: categoryLabel(slug).toUpperCase(),
      bg: c.bgInset,
      fg: c.textSecondary,
    );
  }
}

/// Trimmed signal cluster: category · impact · trust. (Bias + fact-check removed.)
class SignalRow extends StatelessWidget {
  const SignalRow({super.key, required this.article, this.spacing = 5});
  final Article article;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (article.categories.isNotEmpty) CategoryChip(slug: article.categories.first),
        ImpactBadge(impact: article.impact),
        TrustPill(score: article.trustScore),
      ],
    );
  }
}

/// Canonical site domain for a known ingest source name — cluster surfaces
/// only carry source NAMES (no article url), so this keeps them on real
/// favicons instead of the initial-monogram fallback. Matched by substring,
/// most-specific rules first (e.g. "cnbc" before "nbc").
String? domainForSource(String source) {
  final s = source.toLowerCase();
  for (final rule in _sourceDomains) {
    if (s.contains(rule.$1)) return rule.$2;
  }
  return null;
}

const List<(String, String)> _sourceDomains = [
  ('bbc', 'bbc.co.uk'),
  ('guardian', 'theguardian.com'),
  ('al jazeera', 'aljazeera.com'),
  ('npr', 'npr.org'),
  ('cnbc', 'cnbc.com'),
  // 'cbc' AFTER 'cnbc' — it's a substring of it.
  ('cbc', 'cbc.ca'),
  ('cnn', 'cnn.com'),
  // Network-specific rules BEFORE their bare-network substrings.
  ('cbs sports', 'cbssports.com'),
  ('cbs', 'cbsnews.com'),
  ('telemundo', 'telemundo.com'),
  ('msnbc', 'msnbc.com'),
  ('nbc sports', 'nbcsports.com'),
  ('nbc', 'nbcnews.com'),
  ('abc australia', 'abc.net.au'),
  ('abc', 'abcnews.go.com'),
  ('axios', 'axios.com'),
  // 'politico europe' must precede the bare 'politico' substring.
  ('politico europe', 'politico.eu'),
  ('politico', 'politico.com'),
  // 'the hill times' (CA) must precede the bare 'the hill' substring.
  ('the hill times', 'hilltimes.com'),
  ('the hill', 'thehill.com'),
  ('deutsche welle', 'dw.com'),
  ('france 24', 'france24.com'),
  ('south china', 'scmp.com'),
  ('sydney morning', 'smh.com.au'),
  ('times of india', 'timesofindia.indiatimes.com'),
  ('japan times', 'japantimes.co.jp'),
  ('marketwatch', 'marketwatch.com'),
  ('fortune', 'fortune.com'),
  ('techcrunch', 'techcrunch.com'),
  ('verge', 'theverge.com'),
  ('ars technica', 'arstechnica.com'),
  ('engadget', 'engadget.com'),
  ('wired', 'wired.com'),
  ('technology review', 'technologyreview.com'),
  ('venturebeat', 'venturebeat.com'),
  ('ieee', 'spectrum.ieee.org'),
  ('hacker news', 'news.ycombinator.com'),
  ('nasa', 'nasa.gov'),
  ('esa ', 'esa.int'),
  ('nsf', 'nsf.gov'),
  ('dvids', 'dvidshub.net'),
  ('voa', 'voanews.com'),
  ('coindesk', 'coindesk.com'),
  ('decrypt', 'decrypt.co'),
  ('quanta', 'quantamagazine.org'),
  ('nature', 'nature.com'),
  ('phys.org', 'phys.org'),
  ('inside climate', 'insideclimatenews.org'),
  ('grist', 'grist.org'),
  ('stat news', 'statnews.com'),
  ('kff', 'kffhealthnews.org'),
  ('fox sports', 'foxsports.com'),
  ('fox', 'foxnews.com'),
  ('new york post', 'nypost.com'),
  ('new york times', 'nytimes.com'),
  ('nyt', 'nytimes.com'),
  ('sky sports', 'skysports.com'),
  ('sky news', 'news.sky.com'),
  ('independent', 'independent.co.uk'),
  ('telegraph', 'telegraph.co.uk'),
  ('euronews', 'euronews.com'),
  ('straits times', 'straitstimes.com'),
  ('ndtv', 'ndtv.com'),
  ('hindustan', 'hindustantimes.com'),
  ('economic times', 'economictimes.indiatimes.com'),
  ('times of israel', 'timesofisrael.com'),
  ('business insider', 'businessinsider.com'),
  ('yahoo sports', 'sports.yahoo.com'),
  ('yahoo news', 'news.yahoo.com'),
  ('yahoo', 'finance.yahoo.com'),
  ('espn', 'espn.com'),
  ('variety', 'variety.com'),
  ('deadline', 'deadline.com'),
  ('rolling stone', 'rollingstone.com'),
  ('sciencedaily', 'sciencedaily.com'),
  ('live science', 'livescience.com'),
  ('register', 'theregister.com'),
  ('zdnet', 'zdnet.com'),
  ('global news', 'globalnews.ca'),
  ('mexico news daily', 'mexiconewsdaily.com'),
  ('buenos aires', 'batimes.com.ar'),
  ('mercopress', 'en.mercopress.com'),
  ('arab news', 'arabnews.com'),
  ('the national', 'thenationalnews.com'),
  ('korea herald', 'koreaherald.com'),
  ('cna', 'channelnewsasia.com'),
  ('bangkok post', 'bangkokpost.com'),
  ('inquirer', 'inquirer.net'),
  ('rnz', 'rnz.co.nz'),
  ('punch', 'punchng.com'),
  ('premium times', 'premiumtimesng.com'),
  ('vanguard', 'vanguardngr.com'),
  ('nation africa', 'nation.africa'),
  ('daily maverick', 'dailymaverick.co.za'),
  ('allafrica', 'allafrica.com'),
  ('myjoyonline', 'myjoyonline.com'),
  ('the standard', 'standardmedia.co.ke'),
  ('vnexpress', 'e.vnexpress.net'),
  ('dawn', 'dawn.com'),
  // Bangladesh's 'the daily star' must precede the UK 'daily star' substring.
  ('the daily star', 'thedailystar.net'),
  ('daily star', 'dailystar.co.uk'),
  ('malay mail', 'malaymail.com'),
  ('antara', 'en.antaranews.com'),
  ('hurriyet', 'hurriyetdailynews.com'),
  ('daily sabah', 'dailysabah.com'),
  ('rte', 'rte.ie'),
  ('moscow times', 'themoscowtimes.com'),
  ('ansa', 'ansa.it'),
  ('dutchnews', 'dutchnews.nl'),
  ('notes from poland', 'notesfrompoland.com'),
  // 'the local to' (Toronto) must precede the bare 'the local' substring.
  ('the local to', 'thelocal.to'),
  ('the local', 'thelocal.de'),
  ('rio times', 'riotimesonline.com'),
  ('city paper', 'thecitypaperbogota.com'),
  ('daily post', 'dailypost.ng'),
  ('daily trust', 'dailytrust.com'),
  ('channels tv', 'channelstv.com'),
  ('businessday', 'businessday.ng'),
  ('legit', 'legit.ng'),
  ('sahara reporters', 'saharareporters.com'),
  ('thisday', 'thisdaylive.com'),
  ('tribune', 'tribuneonlineng.com'),
  ('leadership', 'leadership.ng'),
  ('3news', '3news.com'),
  ('adom', 'adomonline.com'),
  ('ghanaian times', 'ghanaiantimes.com.gh'),
  ('tuko', 'tuko.co.ke'),
  ('kbc', 'kbc.co.ke'),
  ('capital fm', 'capitalfm.co.ke'),
  ('south african', 'thesouthafrican.com'),
  ('la times', 'latimes.com'),
  ('washington post', 'washingtonpost.com'),
  ('daily mail', 'dailymail.co.uk'),
  // UK roster (2026-07-18). 'the times' + 'financial times' + 'byline times'
  // all contain 'time' — safe only because 'time' stays the LAST rule.
  ('the times', 'thetimes.com'),
  ('the sun', 'thesun.co.uk'),
  ('i news', 'inews.co.uk'),
  ('daily express', 'express.co.uk'),
  ('financial times', 'ft.com'),
  ('itv news', 'itv.com'),
  ('channel 4', 'channel4.com'),
  ('gb news', 'gbnews.com'),
  ('stv news', 'stv.tv'),
  ('the herald', 'heraldscotland.com'),
  ('northern echo', 'thenorthernecho.co.uk'),
  ('oxford mail', 'oxfordmail.co.uk'),
  ('manchester evening news', 'manchestereveningnews.co.uk'),
  ('liverpool echo', 'liverpoolecho.co.uk'),
  ('mylondon', 'mylondon.news'),
  ('the scotsman', 'scotsman.com'),
  ('yorkshire post', 'yorkshirepost.co.uk'),
  ('portsmouth', 'portsmouth.co.uk'),
  ('manchester mill', 'manchestermill.co.uk'),
  ('the economist', 'economist.com'),
  ('spectator', 'spectator.co.uk'),
  ('new statesman', 'newstatesman.com'),
  ('the week', 'theweek.com'),
  ('new european', 'theneweuropean.co.uk'),
  ('guido fawkes', 'order-order.com'),
  ('novara', 'novaramedia.com'),
  ('unherd', 'unherd.com'),
  ('opendemocracy', 'opendemocracy.net'),
  ('byline times', 'bylinetimes.com'),
  ('mirror', 'mirror.co.uk'),
  ('metro', 'metro.co.uk'),
  ('evening standard', 'standard.co.uk'),
  ('national post', 'nationalpost.com'),
  // Canada roster (2026-07-18). 'times colonist' + 'the hill times' contain
  // 'time' — safe only because 'time' stays the LAST rule.
  ('ctv news', 'ctvnews.ca'),
  ('aptn', 'aptnnews.ca'),
  ('citynews', 'citynews.ca'),
  ('cp24', 'cp24.com'),
  ('globe and mail', 'theglobeandmail.com'),
  ('toronto star', 'thestar.com'),
  ('toronto sun', 'torontosun.com'),
  ('calgary herald', 'calgaryherald.com'),
  ('edmonton journal', 'edmontonjournal.com'),
  ('ottawa citizen', 'ottawacitizen.com'),
  ('montreal gazette', 'montrealgazette.com'),
  ('vancouver sun', 'vancouversun.com'),
  ('the province', 'theprovince.com'),
  ('london free press', 'lfpress.com'),
  ('windsor star', 'windsorstar.com'),
  ('starphoenix', 'thestarphoenix.com'),
  ('leader-post', 'leaderpost.com'),
  ('times colonist', 'timescolonist.com'),
  ('winnipeg free press', 'winnipegfreepress.com'),
  ('saltwire', 'saltwire.com'),
  ('maclean', 'macleans.ca'),
  ('the walrus', 'thewalrus.ca'),
  ('ipolitics', 'ipolitics.ca'),
  ('alberta views', 'albertaviews.ca'),
  ('the logic', 'thelogic.co'),
  ('the narwhal', 'thenarwhal.ca'),
  ('the tyee', 'thetyee.ca'),
  ('canadaland', 'canadaland.com'),
  ('national observer', 'nationalobserver.com'),
  ('the breach', 'breachmedia.ca'),
  ('ricochet', 'ricochet.media'),
  ('daily hive', 'dailyhive.com'),
  ('better dwelling', 'betterdwelling.com'),
  ('rabble', 'rabble.ca'),
  ('halifax examiner', 'halifaxexaminer.ca'),
  ('the cjn', 'thecjn.ca'),
  ('the hindu', 'thehindu.com'),
  ('associated press', 'apnews.com'),
  ('reuters', 'reuters.com'),
  ('upi', 'upi.com'),
  // 'bnn bloomberg' (CA) must precede the bare 'bloomberg' substring.
  ('bnn bloomberg', 'bnnbloomberg.ca'),
  ('bloomberg', 'bloomberg.com'),
  ('wall street', 'wsj.com'),
  ('usa today', 'usatoday.com'),
  // 'huffpost uk' must precede the bare 'huffpost' substring.
  ('huffpost uk', 'huffingtonpost.co.uk'),
  ('huffpost', 'huffpost.com'),
  ('daily beast', 'thedailybeast.com'),
  ('vox', 'vox.com'),
  ('pbs', 'pbs.org'),
  ('propublica', 'propublica.org'),
  ('national review', 'nationalreview.com'),
  ('atlantic', 'theatlantic.com'),
  ('washington examiner', 'washingtonexaminer.com'),
  ('sports illustrated', 'si.com'),
  ('the athletic', 'theathletic.com'),
  ('bleacher report', 'bleacherreport.com'),
  ('hollywood reporter', 'hollywoodreporter.com'),
  ('entertainment weekly', 'ew.com'),
  ('people', 'people.com'),
  ('tmz', 'tmz.com'),
  ('billboard', 'billboard.com'),
  ('gizmodo', 'gizmodo.com'),
  ('forbes', 'forbes.com'),
  // 'time' must stay LAST — it's a substring of every "* Times" source above.
  ('time', 'time.com'),
];

/// Publisher favicon — Google's favicon service keyed on the article's source
/// domain, with a tinted monogram fallback while loading / on failure.
class SourceFavicon extends StatelessWidget {
  const SourceFavicon({super.key, required this.url, required this.source, this.size = 16});
  final String? url;
  final String source;
  final double size;

  static String? _host(String? u) {
    if (u == null || u.isEmpty) return null;
    final h = Uri.tryParse(u)?.host ?? '';
    return h.isEmpty ? null : h;
  }

  @override
  Widget build(BuildContext context) {
    final hue = hueFromString(source).toDouble();
    final mono = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HSLColor.fromAHSL(1, hue, 0.5, 0.45).toColor(),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(initialOf(source),
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.6,
              fontWeight: FontWeight.w800)),
    );
    final host = _host(url) ?? domainForSource(source);
    if (host == null) return mono;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: CachedNetworkImage(
        imageUrl: 'https://www.google.com/s2/favicons?domain=$host&sz=64',
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => mono,
        errorWidget: (_, __, ___) => mono,
      ),
    );
  }
}

/// Source attribution line: favicon · source · time (· read time).
class SourceLine extends StatelessWidget {
  const SourceLine({super.key, required this.article, this.showReadTime = false});
  final Article article;
  final bool showReadTime;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = StringBuffer(timeAgo(article.publishedAt));
    if (showReadTime && article.readingMinutes > 0) {
      meta.write(' · ${readTime(article.readingMinutes)}');
    }
    return Row(
      children: [
        SourceFavicon(
            url: article.sourceUrl, source: article.source, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(article.source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption
                  .copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        Text('· ${meta.toString()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: c.textFaint)),
      ],
    );
  }
}
