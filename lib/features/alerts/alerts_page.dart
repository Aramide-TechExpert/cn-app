import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/alerts_controller.dart';
import '../../data/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';
import '../../utils/link_out.dart';
import '../feed/widgets/signal_badges.dart';
import '../shell/sign_in_required.dart';

/// Alerts — watchlist matches produced by the `match` cron (`user_alerts`).
/// Read-only + mark-read; mirrors the web /alerts page.
class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final alerts = ref.watch(alertsControllerProvider);
    final unread = alerts.valueOrNull?.where((a) => a.unread).length ?? 0;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Alerts', style: AppText.title.copyWith(color: c.text)),
        actions: [
          if (user != null && unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(alertsControllerProvider.notifier).markAllRead(),
              child: Text('Mark all read',
                  style: AppText.callout.copyWith(color: c.brand)),
            ),
        ],
      ),
      body: user == null
          ? const SignInRequired(
              feature: 'alerts',
              message:
                  'Alerts notify you when new stories match your watchlists.')
          : Column(
              children: [
                _FilterBar(
                  unreadOnly: _unreadOnly,
                  unread: unread,
                  onChanged: (v) => setState(() => _unreadOnly = v),
                ),
                Expanded(
                  child: alerts.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator.adaptive()),
                    error: (_, __) => Center(
                        child: Text("Couldn't load alerts.",
                            style:
                                AppText.body.copyWith(color: c.textSecondary))),
                    data: (items) {
                      final shown = _unreadOnly
                          ? items.where((a) => a.unread).toList()
                          : items;
                      if (shown.isEmpty) return _Empty(unreadOnly: _unreadOnly);
                      return RefreshIndicator.adaptive(
                        onRefresh: () async =>
                            ref.invalidate(alertsControllerProvider),
                        child: ListView.separated(
                          itemCount: shown.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1, thickness: 1, color: c.border),
                          itemBuilder: (_, i) => _AlertTile(alert: shown[i]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar(
      {required this.unreadOnly,
      required this.unread,
      required this.onChanged});
  final bool unreadOnly;
  final int unread;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget chip(String label, bool selected, VoidCallback onTap) => Material(
          color: selected ? c.brand : c.bgInset,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg, vertical: AppSpace.sm),
              decoration: BoxDecoration(border: Border.all(color: c.border)),
              child: Text(label,
                  style: AppText.caption.copyWith(
                      color: selected ? c.onBrand : c.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
      child: Row(children: [
        chip('All', !unreadOnly, () => onChanged(false)),
        const SizedBox(width: AppSpace.sm),
        chip(unread > 0 ? 'Unread ($unread)' : 'Unread', unreadOnly,
            () => onChanged(true)),
      ]),
    );
  }
}

class _AlertTile extends ConsumerWidget {
  const _AlertTile({required this.alert});
  final AlertItem alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final a = alert.article;
    return InkWell(
      onTap: () {
        if (alert.unread) {
          ref.read(alertsControllerProvider.notifier).markRead(alert.id);
        }
        openArticle(a.sourceUrl, track: a);
      },
      child: Container(
        color: alert.unread ? c.brandSoft.withValues(alpha: 0.4) : c.bg,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: AppSpace.sm),
              decoration: BoxDecoration(
                color: alert.unread ? c.brand : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.bookmarks_outlined, size: 12, color: c.brand),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(alert.watchlistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.micro.copyWith(color: c.brand)),
                    ),
                    Text(timeAgo(alert.triggeredAt),
                        style: AppText.caption.copyWith(color: c.textFaint)),
                  ]),
                  const SizedBox(height: 4),
                  Text(a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(color: c.text)),
                  const SizedBox(height: 6),
                  Row(children: [
                    ImpactBadge(impact: a.impact),
                    const SizedBox(width: 6),
                    Expanded(child: SourceLine(article: a)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.unreadOnly});
  final bool unreadOnly;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none, size: 40, color: c.textFaint),
          const SizedBox(height: AppSpace.md),
          Text(unreadOnly ? 'No unread alerts' : 'No alerts yet',
              style: AppText.headline.copyWith(color: c.text)),
          const SizedBox(height: AppSpace.sm),
          Text('Create a watchlist — matching stories show up here.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: c.textSecondary)),
        ]),
      ),
    );
  }
}
