import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/feed_controller.dart' show apiClientProvider;
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Live list of distinct publishers currently in the feed.
final feedSourcesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final page = await ref.read(apiClientProvider).feed(limit: 100);
  final set = <String>{for (final a in page.items) if (a.source.isNotEmpty) a.source};
  final list = set.toList()..sort();
  return list;
});

/// Sources & attribution — mirrors the web /legal/sources page: how Cluster News
/// uses public feeds, attribution/link-out policy, the live source list, and
/// the takedown contact.
class LegalSourcesPage extends ConsumerWidget {
  const LegalSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sources = ref.watch(feedSourcesProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Sources & attribution',
            style: AppText.title.copyWith(color: c.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.x3),
        children: [
          _p(c,
              'Cluster News is an AI news-intelligence app. We monitor public RSS '
              'feeds from major publishers and use AI to generate original '
              'summaries, context, and signals (impact, trust, clusters) from '
              'the facts they report. We do not republish source articles '
              'verbatim.'),
          const SizedBox(height: AppSpace.md),
          _p(c,
              'Every story shows the original publisher and links out — '
              '"Read original at [Source]" — back to their page. Tapping any '
              'card opens the publisher directly; Cluster News never reproduces the '
              'full article body.'),
          const SizedBox(height: AppSpace.xl),
          Text('Publishers in your feed',
              style: AppText.headline.copyWith(color: c.text, fontSize: 16)),
          const SizedBox(height: AppSpace.sm),
          sources.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
            error: (_, __) => _p(c, 'Source list unavailable right now.'),
            data: (list) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in list)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: c.bgInset,
                    child: Text(s,
                        style: AppText.caption.copyWith(color: c.textSecondary)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Takedowns',
              style: AppText.headline.copyWith(color: c.text, fontSize: 16)),
          const SizedBox(height: AppSpace.sm),
          _p(c,
              'Rights-holders can request removal of any content. We respond '
              'promptly.'),
          const SizedBox(height: AppSpace.md),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
                Uri(scheme: 'mailto', path: 'takedowns@clustez.app')),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.border),
              shape: const RoundedRectangleBorder(),
              minimumSize: const Size.fromHeight(46),
            ),
            icon: Icon(Icons.mail_outline, size: 18, color: c.brand),
            label: Text('Email takedowns@clustez.app',
                style: AppText.callout.copyWith(color: c.brand)),
          ),
        ],
      ),
    );
  }

  Widget _p(ClusterNewsColors c, String text) =>
      Text(text, style: AppText.body.copyWith(color: c.textSecondary, height: 1.5));
}
