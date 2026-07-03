/// Compact relative time: "just now", "12m", "3h", "2d", "Mar 4".
String timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final then = DateTime.tryParse(iso);
  if (then == null) return '';
  final secs = DateTime.now().difference(then).inSeconds;
  if (secs < 45) return 'just now';
  final mins = secs / 60;
  if (mins < 60) return '${mins.round()}m';
  final hours = mins / 60;
  if (hours < 24) return '${hours.round()}h';
  final days = hours / 24;
  if (days < 7) return '${days.round()}d';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[then.month - 1]} ${then.day}';
}

/// "4 min read", or a fallback for unknown/short reads.
String readTime(int minutes) {
  if (minutes < 1) return 'Quick read';
  return '$minutes min read';
}

/// First letter for the source monogram fallback.
String initialOf(String? s) {
  final v = (s ?? '').trim();
  return v.isEmpty ? '•' : v[0].toUpperCase();
}

const _entities = {
  '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'",
  '&apos;': "'", '&nbsp;': ' ', '&hellip;': '…', '&mdash;': '—',
  '&ndash;': '–', '&rsquo;': '’', '&lsquo;': '‘', '&ldquo;': '“',
  '&rdquo;': '”', '&copy;': '©', '&reg;': '®', '&trade;': '™',
};

/// Strip scraping artifacts from titles/excerpts so they read like clean prose:
/// removes URLs, HTML tags/entities, markdown links/images/emphasis, stray
/// hashes and bracketed junk (e.g. "[…]", "[Read more]"), then collapses space.
String cleanText(String? input) {
  var t = input ?? '';
  if (t.isEmpty) return t;
  // Markdown images ![alt](url) → drop; links [text](url) → text.
  t = t.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
  t = t.replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '');
  // HTML tags.
  t = t.replaceAll(RegExp(r'<[^>]+>'), ' ');
  // Bare URLs.
  t = t.replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '');
  t = t.replaceAll(RegExp(r'\bwww\.\S+', caseSensitive: false), '');
  // HTML entities (named + numeric).
  _entities.forEach((k, v) => t = t.replaceAll(k, v));
  t = t.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m[1] ?? '');
    return code == null ? '' : String.fromCharCode(code);
  });
  // Bracketed truncation/junk: [...] [+123 chars] […] (…).
  t = t.replaceAll(RegExp(r'[\[\(]\s*(?:…|\.\.\.|\+[^\]\)]*)\s*[\]\)]'), '');
  // Markdown emphasis/code markers and stray hashes before words.
  t = t.replaceAll(RegExp(r'[*_`~]{1,3}'), '');
  t = t.replaceAll(RegExp(r'(^|\s)#{1,6}\s*'), r' ');
  t = t.replaceAll(RegExp(r'#(?=\w)'), '');
  // Leftover markdown quote/list markers at line starts.
  t = t.replaceAll(RegExp(r'(^|\n)\s*[>\-\*]\s+'), ' ');
  // WordPress RSS footer boilerplate ("The post X appeared first on Y").
  t = t.replaceAll(
      RegExp(r'\s*The post\b.*?\bappeared first on\b[^.]*\.?',
          caseSensitive: false, dotAll: true),
      '');
  // Collapse whitespace, then drop the space before punctuation. Use
  // replaceAllMapped so the captured punctuation is KEPT — a plain replaceAll
  // with r'$1' inserts a literal "$1" (Dart replaceAll has no backreferences).
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (m) => m[1]!);
  return t.trim();
}

/// Deterministic hue (0–360) from a string — stable monogram tint per source.
int hueFromString(String? seed) {
  final s = seed ?? '';
  int h = 0;
  for (var i = 0; i < s.length; i++) {
    h = (h * 31 + s.codeUnitAt(i)) % 360;
  }
  return h;
}
