import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/auth_controller.dart';
import '../../../data/engagement_controller.dart';
import '../../../models/article.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../utils/format.dart';
import '../../../utils/link_out.dart';
import '../../comments/comments_page.dart';

/// Native long-press action sheet for an article (drag-handle modal sheet +
/// haptics + OS share). Open · Bookmark · Share · Copy link.
Future<void> showArticleActions(
  BuildContext context,
  WidgetRef ref,
  Article article,
) async {
  HapticFeedback.mediumImpact();
  final c = context.colors;
  final dbId = article.dbId;
  final messenger = ScaffoldMessenger.of(context);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bgElevated,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (sheetCtx) {
      final marked = dbId != null &&
          (ref.read(engagementProvider).valueOrNull?.bookmarked.contains(dbId) ??
              false);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(color: c.text)),
                  const SizedBox(height: 2),
                  Text('${article.source} · ${timeAgo(article.publishedAt)}',
                      style: AppText.caption.copyWith(color: c.textFaint)),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            _ActionTile(
              icon: Icons.open_in_new,
              label: 'Open story',
              onTap: () {
                Navigator.pop(sheetCtx);
                openArticle(article.sourceUrl, track: article);
              },
            ),
            if (dbId != null)
              _ActionTile(
                icon: Icons.mode_comment_outlined,
                label: article.commentCount > 0
                    ? 'Comments (${article.commentCount})'
                    : 'Comments',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CommentsPage(article: article),
                  ));
                },
              ),
            if (dbId != null)
              _ActionTile(
                icon: marked ? Icons.bookmark : Icons.bookmark_outline,
                label: marked ? 'Remove bookmark' : 'Bookmark',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  if (ref.read(currentUserProvider) == null) {
                    context.push('/sign-in');
                    return;
                  }
                  HapticFeedback.selectionClick();
                  ref.read(engagementProvider.notifier).toggleBookmark(dbId);
                },
              ),
            _ActionTile(
              icon: Icons.ios_share,
              label: 'Share',
              onTap: () {
                Navigator.pop(sheetCtx);
                final url = article.sourceUrl;
                if (url != null && url.isNotEmpty) {
                  Share.share('${article.title}\n$url');
                }
              },
            ),
            _ActionTile(
              icon: Icons.link,
              label: 'Copy link',
              onTap: () {
                Navigator.pop(sheetCtx);
                final url = article.sourceUrl;
                if (url != null && url.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: url));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      );
    },
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      leading: Icon(icon, color: c.text),
      title: Text(label, style: AppText.body.copyWith(color: c.text)),
      onTap: onTap,
    );
  }
}
