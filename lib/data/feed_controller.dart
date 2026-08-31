import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/article.dart';
import '../utils/interleave.dart';
import '../utils/remote_settings.dart';
import '../utils/source_regions.dart';
import 'api_client.dart';
import 'auth_controller.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Strict preference shaping for any article list: national outlets from
/// other regions are DROPPED (a US-preference user never sees a Philippine
/// national outlet), then the kept articles are tiered — user's country
/// first, their region, global desks, topical verticals — ahead of the
/// source interleave.
List<Article> applyRegionPreference(Ref ref, List<Article> items) =>
    shapeArticlesForUser(items,
        meta: ref.read(currentUserProvider)?.userMetadata);

/// CMS per-surface gate, applied ONLY to users with NO preference set (no
/// region scope and no favorite publishers) — any user preference takes
/// full precedence and this never runs against it.
/// BOTH layers are STRICT (2026-08-10, after mixed sources leaked through
/// the old blank-page fallback whenever a fetched batch held none of the
/// picks):
/// - [defaults]: allow-list — when set, ONLY these sources pass; a batch
///   with none of them yields empty, never the unfiltered mix.
/// - [excludes]: switch-offs — an excluded source never appears, even if
///   it's also in the defaults.
/// The fetch loops compensate by digging deeper when a gate is active, so
/// pages fill with picks instead of leaking others.
List<Article> applySurfaceGate(Ref ref, List<Article> items,
    List<String> defaults, List<String> excludes) {
  if (defaults.isEmpty && excludes.isEmpty) return items;
  if (hasSourcePreference(ref.read(currentUserProvider)?.userMetadata)) {
    return items;
  }
  var out = items;
  if (defaults.isNotEmpty) {
    final allow = defaults.toSet();
    out = out.where((a) => allow.contains(a.source)).toList();
  }
  if (excludes.isNotEmpty) {
    final block = excludes.toSet();
    out = out.where((a) => !block.contains(a.source)).toList();
  }
  return out;
}

/// True when the user has ANY source-shaping preference (region scope or
/// favorite publishers) — the admin surface gates never run against them.
/// The ONE definition of "has a preference": every gate must share it.
bool hasSourcePreference(Map<String, dynamic>? meta) =>
    activeSegment(meta) != null ||
    ((meta?['preferred_sources'] as List?)?.isNotEmpty ?? false);

/// The admin surface gate over SOURCE NAMES — pickers must only offer what
/// the gated feed can actually show. [QA-S2.15]: the News Feed picker
/// previously bypassed both layers, so a no-preference user could select
/// (and see) a defaulted-out or switched-off source.
List<String> gateSourceNames(List<String> names, Map<String, dynamic>? meta,
    List<String> defaults, List<String> excludes) {
  if (hasSourcePreference(meta) || (defaults.isEmpty && excludes.isEmpty)) {
    return names;
  }
  final allow = defaults.toSet();
  final block = excludes.toSet();
  return [
    for (final n in names)
      if ((allow.isEmpty || allow.contains(n)) && !block.contains(n)) n
  ];
}

/// Home feed: keyset-cursor infinite list over `/api/v1/feed`. The cursor +
/// has-more flags live on the notifier; the public state is the article list.
/// Every page is source-interleaved (one source at a time) with the surplus
/// of burst-posting publishers deferred into the next page's mix.
final feedControllerProvider =
    AsyncNotifierProvider<FeedController, List<Article>>(FeedController.new);

class FeedController extends AsyncNotifier<List<Article>> {
  String? _cursor;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _since; // '1h'|'24h'|'7d', null = any time (Home time filter)
  List<Article> _deferred = const [];

  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  String? get since => _since;

  /// Fetch pages until at least [minVisible] stories survive the strict
  /// source gate (or the corpus ends). Feeds are newest-first and ingestion
  /// bursts make whole pages one or two publishers, so a single gated page
  /// can come back empty. Bounded hops keep a worst-case refresh cheap.
  Future<List<Article>> _collect({
    String? cursor,
    required int limit,
    required int minVisible,
  }) async {
    final collected = <Article>[];
    var next = cursor;
    // Server-side region pre-filter (defense in depth + denser pages);
    // the strict per-country gate still applies client-side. MULTI-scope
    // users send every selected segment (server returns the union); no
    // scopes means the curated Worldwide tier, not everything.
    final meta = ref.read(currentUserProvider)?.userMetadata;
    final scopeSegments =
        activeScopes(meta).map((s) => s.segment).toSet().toList();
    final region = scopeSegments.isEmpty ? 'Worldwide' : null;
    // Strict favorites go to the SERVER too — dense favorites-only pages
    // in one hop instead of ten sifting hops.
    final favs = ((meta?['preferred_sources'] as List?) ?? const [])
        .cast<String>()
        .toList();
    // With an admin surface gate active the newest slice is often mostly
    // non-picks — dig deeper so pages fill with picks instead of running
    // two cards long. minVisible is measured AFTER the full gate.
    // Favorites are server-filtered now — pages arrive dense, so the deep
    // hop budget is only for the ADMIN gates (which stay client-side).
    final gated =
        remote.defaultsHome.isNotEmpty || remote.excludeHome.isNotEmpty;
    final maxHops = gated ? 10 : 5;
    for (var hop = 0; hop < maxHops; hop++) {
      final page = await ref.read(apiClientProvider).feed(
          cursor: next,
          limit: limit,
          since: _since,
          region: region,
          regions: scopeSegments,
          sources: favs);
      next = page.nextCursor;
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null;
      collected.addAll(page.items);
      if (!_hasMore) break;
      if (applySurfaceGate(ref, applyRegionPreference(ref, collected),
              remote.defaultsHome, remote.excludeHome)
          .length >=
          minVisible) {
        break;
      }
    }
    return collected;
  }

  Future<List<Article>> _firstPage() async {
    _deferred = const [];
    // Larger first page so Home can fill hero + rail + bento + latest.
    // Size is a remote knob (Clustez Control → Features).
    final items =
        await _collect(limit: remote.homePageSize, minVisible: 12);
    final r = interleaveBySource(
        applySurfaceGate(ref, applyRegionPreference(ref, items),
            remote.defaultsHome, remote.excludeHome),
        flush: !_hasMore);
    _deferred = r.deferred;
    return r.emitted;
  }

  @override
  Future<List<Article>> build() => _firstPage();

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final items =
          await _collect(cursor: _cursor, limit: 12, minVisible: 6);
      final r = interleaveBySource(
          applySurfaceGate(
              ref,
              applyRegionPreference(ref, [..._deferred, ...items]),
              remote.defaultsHome,
              remote.excludeHome),
          flush: !_hasMore);
      _deferred = r.deferred;
      state = AsyncData([...(state.value ?? const []), ...r.emitted]);
    } catch (_) {
      // keep current list; a later scroll retries
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    state = await AsyncValue.guard(_firstPage);
  }

  /// Home time filter — refetches the feed with the new lower bound.
  Future<void> setSince(String? since) async {
    if (_since == since) return;
    _since = since;
    _cursor = null;
    _hasMore = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_firstPage);
  }
}
