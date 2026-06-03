import 'package:url_launcher/url_launcher.dart';

/// Link-out — the content model. Opens the publisher's page in an in-app
/// browser (Custom Tab / SFSafariViewController). We never reproduce bodies.
Future<void> openArticle(String? url) async {
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
