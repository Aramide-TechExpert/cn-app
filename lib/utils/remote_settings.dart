/// Remote product settings from Clustez Control (`/api/v1/app-settings`).
/// Fetched fire-and-forget at launch and merged over these compiled-in
/// defaults — offline or on failure the defaults apply, which match the
/// server's own defaults exactly. Read via [remote].
library;

import 'package:flutter/foundation.dart' show ValueNotifier;

/// This build's version — keep in sync with pubspec.yaml `version:`.
const String appVersion = '1.0.0';

class RemoteSettings {
  const RemoteSettings({
    this.videos = true,
    this.comments = true,
    this.tts = true,
    this.clusters = true,
    this.widgets = true,
    this.engagement = true,
    this.bento = true,
    this.interleave = true,
    this.homePageSize = 24,
    this.defaultTheme = 'system',
    this.defaultsHome = const [],
    this.defaultsFeed = const [],
    this.defaultsVideos = const [],
    this.excludeHome = const [],
    this.excludeFeed = const [],
    this.excludeVideos = const [],
    this.pinnedSources = const [],
    this.spotlightSources = const [],
    this.statsStrip = true,
    this.spotlightCount = 5,
    this.railCount = 6,
    this.shortsCount = 10,
    this.sectionOrder = const ['spotlight', 'forYou', 'trending', 'shorts'],
    this.defaultView = 'mixed',
    this.feedView = 'mixed',
  });

  final bool videos;
  final bool comments;
  final bool tts;
  final bool clusters;
  final bool widgets;
  final bool engagement;
  final bool bento;
  final bool interleave;
  final int homePageSize;
  final String defaultTheme; // system | dark | light
  final List<String> defaultsHome;
  final List<String> defaultsFeed;
  final List<String> defaultsVideos;

  /// Admin switch-offs per surface — STRICT for users with no preference
  /// set (an excluded source never appears there); any user preference
  /// takes full precedence and these never run against it.
  final List<String> excludeHome;
  final List<String> excludeFeed;
  final List<String> excludeVideos;
  final List<String> pinnedSources;
  final List<String> spotlightSources;
  final bool statsStrip;
  final int spotlightCount;
  final int railCount;
  final int shortsCount;
  final List<String> sectionOrder;
  final String defaultView; // mixed | magazine | grid | list
  final String feedView; // News Feed page (independent of Home)

  static RemoteSettings fromJson(Map<String, dynamic> json) {
    final s = json['settings'];
    if (s is! Map) return const RemoteSettings();
    final f = s['features'];
    final feed = s['feed'];
    bool flag(dynamic section, String key, bool fallback) =>
        section is Map && section[key] is bool
            ? section[key] as bool
            : fallback;
    return RemoteSettings(
      videos: flag(f, 'videos', true),
      comments: flag(f, 'comments', true),
      tts: flag(f, 'tts', true),
      clusters: flag(f, 'clusters', true),
      widgets: flag(f, 'widgets', true),
      engagement: flag(f, 'engagement', true),
      bento: flag(feed, 'bento', true),
      interleave: flag(feed, 'interleave', true),
      homePageSize: feed is Map && feed['homePageSize'] is num
          ? (feed['homePageSize'] as num).toInt().clamp(6, 50)
          : 24,
      defaultsHome: switch (s['layout']) {
        {'defaultsHome': final List p} => [for (final x in p) if (x is String) x],
        _ => const [],
      },
      defaultsFeed: switch (s['layout']) {
        {'defaultsFeed': final List p} => [for (final x in p) if (x is String) x],
        _ => const [],
      },
      defaultsVideos: switch (s['layout']) {
        {'defaultsVideos': final List p} => [for (final x in p) if (x is String) x],
        _ => const [],
      },
      excludeHome: switch (s['layout']) {
        {'excludeHome': final List p} => [for (final x in p) if (x is String) x],
        _ => const [],
      },
      excludeFeed: switch (s['layout']) {
        {'excludeFeed': final List p} => [for (final x in p) if (x is String) x],
        _ => const [],
      },
      excludeVideos: switch (s['layout']) {
        {'excludeVideos': final List p} => [for (final x in p) if (x is String) x],
        _ => const [],
      },
      pinnedSources: switch (s['layout']) {
        {'pinnedSources': final List p} => [for (final x in p) if (x is String) x],
        _ => const [],
      },
      spotlightSources: switch (s['layout']) {
        {'spotlightSources': final List p} => [for (final x in p) if (x is String) x],
        _ => const [],
      },
      statsStrip: switch (s['layout']) {
        {'statsStrip': final bool b} => b,
        _ => true,
      },
      spotlightCount: switch (s['layout']) {
        {'spotlightCount': final num n} => n.toInt().clamp(1, 10),
        _ => 5,
      },
      railCount: switch (s['layout']) {
        {'railCount': final num n} => n.toInt().clamp(0, 12),
        _ => 6,
      },
      shortsCount: switch (s['layout']) {
        {'shortsCount': final num n} => n.toInt().clamp(0, 20),
        _ => 10,
      },
      sectionOrder: switch (s['layout']) {
        {'sectionOrder': final List p} when p.isNotEmpty => [
          for (final x in p)
            if (x is String) x,
        ],
        _ => const ['spotlight', 'forYou', 'trending', 'shorts'],
      },
      feedView: switch (s['layout']) {
        {'feedView': final String v}
            when ['mixed', 'magazine', 'grid', 'list'].contains(v) =>
          v,
        _ => 'mixed',
      },
      defaultView: switch (s['layout']) {
        {'defaultView': final String v}
            when ['mixed', 'magazine', 'grid', 'list'].contains(v) =>
          v,
        _ => 'mixed',
      },
      defaultTheme: switch (s['appearance']) {
        {'defaultTheme': final String t}
            when ['system', 'dark', 'light'].contains(t) =>
          t,
        _ => 'system',
      },
    );
  }
}

/// Admin-authored banner from Clustez Control (null = none active).
class Announcement {
  const Announcement({
    required this.id,
    required this.text,
    required this.level,
    this.url,
  });
  final String id;
  final String text;
  final String level; // info | warning | critical
  final String? url;

  static Announcement? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = json['id'];
    final text = json['text'];
    if (id is! String || text is! String || text.isEmpty) return null;
    return Announcement(
      id: id,
      text: text,
      level: json['level'] is String ? json['level'] as String : 'info',
      url: json['url'] is String ? json['url'] as String : null,
    );
  }
}

RemoteSettings _remote = const RemoteSettings();
Announcement? _announcement;

/// The active remote settings (defaults until the launch fetch lands).
RemoteSettings get remote => _remote;

/// The active announcement banner, if any.
Announcement? get remoteAnnouncement => _announcement;

/// Maintenance message when the panel has maintenance mode ON, else null.
/// A ValueNotifier so the app shell can react after the launch fetch lands.
final ValueNotifier<String?> maintenanceNotice = ValueNotifier(null);

/// True when this build is older than the served minimum version.
final ValueNotifier<bool> updateRequired = ValueNotifier(false);

int _cmpSemver(String a, String b) {
  final pa = a.split('.').map(int.tryParse).toList();
  final pb = b.split('.').map(int.tryParse).toList();
  for (var i = 0; i < 3; i++) {
    final x = (i < pa.length ? pa[i] : 0) ?? 0;
    final y = (i < pb.length ? pb[i] : 0) ?? 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

void applyRemoteSettings(Map<String, dynamic> payload) {
  _remote = RemoteSettings.fromJson(payload);
  _announcement = Announcement.fromJson(payload['announcement']);
  final lifecycle = switch (payload['settings']) {
    {'lifecycle': final Map l} => l,
    _ => const <String, dynamic>{},
  };
  maintenanceNotice.value = lifecycle['maintenance'] == true
      ? (lifecycle['maintenanceMessage'] is String &&
              (lifecycle['maintenanceMessage'] as String).isNotEmpty
          ? lifecycle['maintenanceMessage'] as String
          : "We're doing some quick maintenance. Back shortly.")
      : null;
  final minV = lifecycle['minAppVersion'];
  updateRequired.value =
      minV is String && minV.isNotEmpty && _cmpSemver(appVersion, minV) < 0;
}
