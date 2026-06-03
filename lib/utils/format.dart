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

/// Deterministic hue (0–360) from a string — stable monogram tint per source.
int hueFromString(String? seed) {
  final s = seed ?? '';
  int h = 0;
  for (var i = 0; i < s.length; i++) {
    h = (h * 31 + s.codeUnitAt(i)) % 360;
  }
  return h;
}
