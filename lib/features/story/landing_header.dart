import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// THE push-landing header — a single pinned app bar builder shared by BOTH
/// landing templates (StoryPage + DigestPage) so they look as "occupied" as the
/// Home/Feed tabs instead of a bare back button, AND can never drift apart.
///
/// Layout mirrors the app's tab headers: a small brand-coloured eyebrow over a
/// bold title, a back control on the left, and optional actions (search) on the
/// right. Locked chrome — both templates call this; do not hand-roll a bespoke
/// SliverAppBar on either landing (owner spec 2026-11-27).
SliverAppBar landingHeader(
  BuildContext context, {
  required String eyebrow,
  required String title,
  List<Widget> actions = const [],
}) {
  final c = context.colors;
  return SliverAppBar(
    pinned: true,
    floating: true,
    backgroundColor: c.bg,
    surfaceTintColor: Colors.transparent,
    toolbarHeight: 64,
    leading: IconButton(
      icon: Icon(Icons.arrow_back, color: c.text),
      onPressed: () => context.canPop() ? context.pop() : context.go('/'),
    ),
    titleSpacing: 0,
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: AppText.caption.copyWith(
            color: c.brand,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.title.copyWith(color: c.text),
        ),
      ],
    ),
    actions: [
      ...actions,
      IconButton(
        icon: Icon(Icons.search, color: c.text),
        onPressed: () => context.push('/search'),
      ),
      const SizedBox(width: AppSpace.xs),
    ],
  );
}
