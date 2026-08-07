/// Remote product settings from Clustez Control (`/api/v1/app-settings`).
/// Fetched fire-and-forget at launch and merged over these compiled-in
/// defaults — offline or on failure the defaults apply, which match the
/// server's own defaults exactly. Read via [remote].
library;

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

void applyRemoteSettings(Map<String, dynamic> payload) {
  _remote = RemoteSettings.fromJson(payload);
  _announcement = Announcement.fromJson(payload['announcement']);
}
