import '../models/article.dart';
import 'remote_settings.dart';

/// Round-robin articles by source — "one source at a time".
///
/// Feeds order by published_at, so a publisher that burst-posts (Sky Sports
/// dropping 20 items at once) dominates whole stretches of scrolling. This
/// cycles through the page's sources in first-seen order, emitting one
/// article per source per cycle, so consecutive cards are always different
/// publishers.
///
/// When only ONE source still has items left, its remainder is returned as
/// [deferred] instead of emitted — the controller carries it into the next
/// page merge so the surplus interleaves with fresh sources there. A small
/// trickle (2 items) still emits so the feed keeps advancing even if every
/// remaining item is the same publisher. Pass [flush] on the last page to
/// emit everything.
({List<Article> emitted, List<Article> deferred}) interleaveBySource(
  List<Article> incoming, {
  bool flush = false,
}) {
  // Remote switch (Cluster News Control → Features): pass-through when off.
  if (!remote.interleave) {
    return (emitted: incoming, deferred: const <Article>[]);
  }
  final queues = <String, List<Article>>{};
  final order = <String>[];
  for (final a in incoming) {
    queues.putIfAbsent(a.source, () {
      order.add(a.source);
      return <Article>[];
    }).add(a);
  }

  final emitted = <Article>[];
  while (true) {
    final live = order.where((s) => queues[s]!.isNotEmpty).toList();
    if (live.isEmpty) break;
    if (live.length == 1 && !flush) {
      final q = queues[live.first]!;
      final take = q.length < 2 ? q.length : 2;
      emitted.addAll(q.take(take));
      q.removeRange(0, take);
      break;
    }
    for (final s in live) {
      emitted.add(queues[s]!.removeAt(0));
    }
  }

  final deferred = [for (final s in order) ...queues[s]!];
  return (emitted: emitted, deferred: deferred);
}

/// Ids of the video articles allowed to render as inline VIDEO cards — at
/// most one every [gap] items, so autoplaying video is an accent woven into
/// the feed, never a wall. Video articles outside this set render as normal
/// image cards.
Set<String> throttleVideoCards(List<Article> items, {int gap = 10}) {
  final ok = <String>{};
  var last = -gap;
  for (var i = 0; i < items.length; i++) {
    final a = items[i];
    if (a.hasPlayableVideo && a.hasImage && i - last >= gap) {
      ok.add(a.id);
      last = i;
    }
  }
  return ok;
}
