import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_controller.dart';
import '../../data/feed_controller.dart' show apiClientProvider;
import '../../data/personalization_controller.dart';
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../utils/source_regions.dart';
import '../../theme/tokens.dart';
import '../feed/widgets/card_variants.dart';
import '../shell/sign_in_required.dart';

/// Watchlists — named tag sets (`watchlists`). Mirrors the web /watchlists:
/// create, delete, and view matching stories. Supabase-direct under RLS.
class WatchlistsPage extends ConsumerWidget {
  const WatchlistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final lists = ref.watch(watchlistsControllerProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Watchlists', style: AppText.title.copyWith(color: c.text)),
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: c.brand,
              onPressed: () => _showCreate(context, ref),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New', style: TextStyle(color: Colors.white)),
            ),
      body: user == null
          ? const SignInRequired(
              feature: 'watchlists',
              message: 'Sign in to track topics and get matching stories.')
          : lists.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (_, __) => Center(
                  child: Text("Couldn't load watchlists.",
                      style: AppText.body.copyWith(color: c.textSecondary))),
              data: (items) => items.isEmpty
                  ? _Empty()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, AppSpace.md, AppSpace.lg, 96),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpace.md),
                      itemBuilder: (_, i) => _WatchlistTile(watchlist: items[i]),
                    ),
            ),
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    var breaking = false;
    var highImpact = false;
    var saving = false;
    final c = context.colors;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bgElevated,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpace.lg,
          right: AppSpace.lg,
          top: AppSpace.lg,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpace.lg,
        ),
        child: StatefulBuilder(
          builder: (sheetCtx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New watchlist',
                  style: AppText.headline.copyWith(color: c.text)),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: nameCtrl,
                style: AppText.body.copyWith(color: c.text),
                decoration: InputDecoration(
                  hintText: 'Name (e.g. AI policy)',
                  filled: true,
                  fillColor: c.bgInset,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: tagsCtrl,
                style: AppText.body.copyWith(color: c.text),
                decoration: InputDecoration(
                  hintText: 'Keywords, comma-separated',
                  filled: true,
                  fillColor: c.bgInset,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeColor: c.brand,
                value: breaking,
                onChanged: (v) => setSheet(() => breaking = v),
                title: Text('Breaking only',
                    style: AppText.body.copyWith(color: c.text)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeColor: c.brand,
                value: highImpact,
                onChanged: (v) => setSheet(() => highImpact = v),
                title: Text('High impact only',
                    style: AppText.body.copyWith(color: c.text)),
              ),
              const SizedBox(height: AppSpace.sm),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final tags = tagsCtrl.text
                            .split(',')
                            .map((t) => t.trim())
                            .where((t) => t.isNotEmpty)
                            .toList();
                        if (name.isEmpty || tags.isEmpty) return;
                        setSheet(() => saving = true);
                        await ref
                            .read(watchlistsControllerProvider.notifier)
                            .create(
                              name: name,
                              tags: tags,
                              breaking: breaking,
                              highImpact: highImpact,
                            );
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
                style: FilledButton.styleFrom(
                    backgroundColor: c.brand,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder()),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create watchlist'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bookmark_added_outlined, size: 40, color: c.textFaint),
          const SizedBox(height: AppSpace.md),
          Text('No watchlists yet',
              style: AppText.headline.copyWith(color: c.text)),
          const SizedBox(height: AppSpace.sm),
          Text('Tap “New” to track keywords and see matching stories.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: c.textSecondary)),
        ]),
      ),
    );
  }
}

class _WatchlistTile extends ConsumerWidget {
  const _WatchlistTile({required this.watchlist});
  final Watchlist watchlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Dismissible(
      key: ValueKey(watchlist.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.lg),
        color: c.critical,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) =>
          ref.read(watchlistsControllerProvider.notifier).remove(watchlist.id),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WatchlistDetailPage(watchlist: watchlist))),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(border: Border.all(color: c.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(watchlist.name,
                      style: AppText.bodyStrong.copyWith(color: c.text)),
                ),
                if (watchlist.matchCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    color: c.brandSoft,
                    child: Text('${watchlist.matchCount} matches',
                        style: AppText.micro.copyWith(color: c.brand)),
                  ),
              ]),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in watchlist.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      color: c.bgInset,
                      child: Text(t,
                          style: AppText.caption.copyWith(color: c.textSecondary)),
                    ),
                  if (watchlist.breakingFilter)
                    _Flag(label: 'BREAKING', color: c.breaking),
                  if (watchlist.highImpactFilter)
                    _Flag(label: 'HIGH IMPACT', color: c.high),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: color.withValues(alpha: 0.16),
        child: Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800, color: color)),
      );
}

/// Matching stories for a watchlist — searches the corpus for its tags.
class WatchlistDetailPage extends ConsumerWidget {
  const WatchlistDetailPage({super.key, required this.watchlist});
  final Watchlist watchlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final query = watchlist.tags.join(' ');
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(watchlist.name, style: AppText.title.copyWith(color: c.text)),
      ),
      body: FutureBuilder<List<Article>>(
        future: ref.read(apiClientProvider).search(query, limit: 30).then(
            (r) => gateAfricaSources(r,
                meta: ref.read(currentUserProvider)?.userMetadata)),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          var items = snap.data ?? const <Article>[];
          if (watchlist.breakingFilter) {
            items = items.where((a) => a.isBreaking).toList();
          }
          if (watchlist.highImpactFilter) {
            items = items
                .where((a) => a.impact == 'Critical' || a.impact == 'High')
                .toList();
          }
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x2),
                child: Text('No matching stories right now.',
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: c.textSecondary)),
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => items[i].hasImage
                ? DefaultCard(article: items[i])
                : ListCard(article: items[i]),
          );
        },
      ),
    );
  }
}
