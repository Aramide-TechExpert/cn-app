import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/link_out.dart';
import '../../utils/remote_settings.dart';

const _kDismissedAnnouncement = 'clusternews:dismissed-announcement';

/// Admin-authored banner from Cluster News Control. Renders nothing when no
/// announcement is active or this device dismissed the current message id
/// (a re-published announcement gets a new id and reappears).
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  bool _dismissed = true; // hidden until the prefs check completes

  @override
  void initState() {
    super.initState();
    // Re-check when served config lands/refreshes: a cold start mounts this
    // BEFORE the launch fetch, so without this an active announcement would
    // stay hidden all session (_dismissed starts true and never re-derives).
    remoteConfigGeneration.addListener(_check);
    _check();
  }

  @override
  void dispose() {
    remoteConfigGeneration.removeListener(_check);
    super.dispose();
  }

  Future<void> _check() async {
    final a = remoteAnnouncement;
    if (a == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() =>
        _dismissed = prefs.getString(_kDismissedAnnouncement) == a.id);
  }

  Future<void> _dismiss(String id) async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDismissedAnnouncement, id);
  }

  @override
  Widget build(BuildContext context) {
    final a = remoteAnnouncement;
    if (a == null || _dismissed) return const SizedBox.shrink();
    final c = context.colors;
    final (bg, fg) = switch (a.level) {
      'critical' => (const Color(0xFF7F1D1D), Colors.white),
      'warning' => (const Color(0xFF78350F), Colors.white),
      _ => (c.brand.withValues(alpha: 0.15), c.text),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md, vertical: AppSpace.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(
            a.level == 'info'
                ? Icons.campaign_outlined
                : Icons.warning_amber_rounded,
            size: 18,
            color: fg),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: GestureDetector(
            onTap: a.url == null ? null : () => openArticle(a.url),
            child: Text(a.text,
                style: AppText.callout
                    .copyWith(color: fg, fontWeight: FontWeight.w600)),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _dismiss(a.id),
          icon: Icon(Icons.close, size: 16, color: fg),
        ),
      ]),
    );
  }
}
