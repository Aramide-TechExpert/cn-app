import '../models/article.dart';

final RegExp _videoHost = RegExp(
  r'(youtube\.com|youtu\.be|vimeo\.com|tiktok\.com|dailymotion\.com)',
  caseSensitive: false,
);

/// Heuristic: does this article point at a video? (source URL host, or a
/// source labelled like "Reuters (YT)"). Mirrors the RN isVideoArticle.
bool isVideoArticle(Article a) {
  final url = a.sourceUrl ?? '';
  if (url.isNotEmpty && _videoHost.hasMatch(url)) return true;
  final s = a.source.toLowerCase();
  return s.contains('(yt)') || s.contains('youtube');
}

final RegExp _ytId = RegExp(
  r'(?:youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|embed/|live/)|youtu\.be/)([A-Za-z0-9_-]{11})',
);

/// Extract the 11-char YouTube video id from a URL (watch/shorts/embed/live/
/// youtu.be), or null if it isn't a recognizable YouTube link.
String? youtubeIdFor(String? url) {
  if (url == null || url.isEmpty) return null;
  return _ytId.firstMatch(url)?.group(1);
}
