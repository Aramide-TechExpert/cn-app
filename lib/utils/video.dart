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
