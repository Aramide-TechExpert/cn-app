import 'package:url_launcher/url_launcher.dart';

import '../data/reading_history.dart';
import '../models/article.dart';

/// Link-out — the content model. Opens the publisher's page in an in-app
/// browser (Custom Tab / SFSafariViewController). We never reproduce bodies.
/// Pass [track] to record the open in "Continue reading".
Future<void> openArticle(String? url, {Article? track}) async {
  if (track != null) ReadingHistory.record(track);
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  } catch (_) {
    // Fall back to the platform default handler.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // no-op
    }
  }
}
