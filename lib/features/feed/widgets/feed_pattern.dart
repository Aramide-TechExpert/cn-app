import 'package:flutter/material.dart';

import '../../../models/article.dart';
import '../../../theme/tokens.dart';
import 'card_variants.dart';
import 'magazine_card.dart';
import 'overlay_card.dart';

/// THE feed template — single source of truth for every story-list surface.
/// ENFORCED consumers (owner ruling 2026-10-27 — never a bespoke card cycle
/// on any story list or notification landing; add new surfaces HERE):
///   • Home "Latest"            → feedCard + planFeedRows + feedFlushBelow
///   • Feed tab (/discover)     → newsFeedCard + planFeedRows + newsFeedFlushBelow
///   • Digest landing (/digest) → newsFeedCard (same as Feed tab)
///   • Full coverage (/cluster) → newsFeedCard (same as Feed tab)
/// Change the rhythm here and every surface follows.
///
/// Cycles the feed through every full-width variant so each card style
/// surfaces as you scroll. Falls back to a text variant when an article has
/// no image (so image-led variants never render an empty box).
Widget feedCard(int i, Article a,
    {bool flushBelow = false, bool videoOk = false}) {
  // Real in-article video renders as the video card only when the throttle
  // allows it (~1 per 10 items) — news sources carry a LOT of video now,
  // and autoplay should be an accent, not the whole feed.
  if (a.hasPlayableVideo && a.hasImage && videoOk) {
    return VideoCard(article: a, flushBelow: flushBelow);
  }
  Widget overlay() => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: OverlayCard(article: a, flushBelow: flushBelow),
      );
  switch (i % 7) {
    case 0:
      return a.hasImage
          ? WideCard(article: a, flushBelow: flushBelow)
          : FeaturedCard(article: a);
    case 1:
      return a.hasImage
          ? DefaultCard(article: a, flushBelow: flushBelow)
          : ListCard(article: a);
    case 2:
      // The News Feed's horizontal row card (thumbnail right) — replaces
      // the plain text ListCard for image-bearing articles.
      return a.hasImage
          ? SplitCard(article: a, imageRight: true)
          : ListCard(article: a);
    case 3:
      return a.hasImage ? overlay() : ListCard(article: a);
    case 4:
      return a.hasImage
          ? MagazineCard(article: a, flushBelow: flushBelow)
          : ListCard(article: a);
    case 5:
      return FeaturedCard(article: a);
    default:
      // Classic ArticleCard (image left, source header, action footer) is
      // retired from the feeds — the horizontal row card replaces it entirely.
      return a.hasImage
          ? SplitCard(article: a, imageRight: true)
          : ListCard(article: a);
  }
}

/// Plan stories into rows — the News Feed's structural rhythm: mostly single
/// full-width cards, with a periodic 2-up compact pair (two small cards
/// side-by-side). Pairs only group plain image cards (not video/text).
List<List<Article>> planFeedRows(List<Article> items) {
  final rows = <List<Article>>[];
  var i = 0, r = 0;
  while (i < items.length) {
    final a = items[i];
    final next = i + 1 < items.length ? items[i + 1] : null;
    final pairable = r > 0 &&
        r % 4 == 1 &&
        a.hasImage &&
        !a.hasPlayableVideo &&
        next != null &&
        next.hasImage &&
        !next.hasPlayableVideo;
    if (pairable) {
      rows.add([a, next]);
      i += 2;
    } else {
      rows.add([a]);
      i += 1;
    }
    r++;
  }
  return rows;
}

/// The News Feed's 2-up compact pair, rendered identically on every surface.
Widget feedPairRow(BuildContext context, List<Article> row) =>
    Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: CompactCard(article: row[0])),
            const SizedBox(width: AppSpace.md),
            Expanded(child: CompactCard(article: row[1])),
          ],
        ),
      ),
      Divider(height: 1, thickness: 1, color: context.colors.border),
    ]);

/// Whether the card at position [i] renders as a big full-bleed image card
/// (used to decide if a band-carrying card above it should drop to a thin line).
bool isBigImageCardAt(int i, Article a, {bool videoOk = false}) {
  if (a.hasPlayableVideo && a.hasImage && videoOk) return true; // VideoCard
  switch (i % 7) {
    case 0: // Wide
    case 1: // Default
    case 3: // Overlay
    case 4: // Magazine
      return a.hasImage;
    default: // 2/5/6 → List / Featured / Article (compact or text)
      return false;
  }
}

/// Band ("grey gap") decision for the single-card row at [i] in [rows]:
/// only between two stacked big image cards.
bool feedFlushBelow(List<List<Article>> rows, int i, Set<String> videoOk) {
  final a = rows[i].first;
  final nextRow = i + 1 < rows.length ? rows[i + 1] : null;
  return nextRow != null &&
      nextRow.length == 1 &&
      isBigImageCardAt(i, a, videoOk: videoOk.contains(a.id)) &&
      isBigImageCardAt(i + 1, nextRow.first,
          videoOk: videoOk.contains(nextRow.first.id));
}

/// The FEED page (news-feed tab) card rhythm — a bold full-bleed Overlay hero
/// leads, then a tight cadence interleaves full-bleed Overlay, panoramic
/// Wide, Split (both directions) and a big Magazine between standard Default
/// cards — variety is obvious every few cards, not once every 7.
/// Video → VideoCard (throttled); image-less → Featured (with "why it
/// matters") else List.
Widget newsFeedCard(int i, Article a,
    {bool flushBelow = false, bool videoOk = false}) {
  // Play icon ONLY for a real, captured, playable video — never the loose
  // hasVideo detector (which fires on ads / embeds / thumbnail players).
  if (a.hasPlayableVideo && a.hasImage && videoOk) {
    return VideoCard(article: a, flushBelow: flushBelow);
  }
  if (!a.hasImage) {
    return (a.whyItMatters ?? '').isNotEmpty
        ? FeaturedCard(article: a)
        : ListCard(article: a);
  }
  if (i == 0) {
    return OverlayCard(
        article: a, height: 300, flushBelow: flushBelow); // bold full-bleed hero
  }
  switch (i % 6) {
    case 0:
      return WideCard(article: a, flushBelow: flushBelow); // panoramic 2:1
    case 2:
      return OverlayCard(article: a, flushBelow: flushBelow); // full-bleed
    case 3:
      return SplitCard(article: a, flushBelow: flushBelow); // image left
    case 4:
      return MagazineCard(article: a, flushBelow: flushBelow); // large image-top
    case 5:
      return SplitCard(
          article: a, imageRight: true, flushBelow: flushBelow); // image right
    default:
      return DefaultCard(article: a, flushBelow: flushBelow); // standard
  }
}

/// Feed-page band decision: grey gap only between two stacked single rows
/// that both carry images (the Feed page's simpler big-image test).
bool newsFeedFlushBelow(List<List<Article>> rows, int i) {
  final row = rows[i];
  final next = i + 1 < rows.length ? rows[i + 1] : null;
  return row.length == 1 &&
      row.first.hasImage &&
      next != null &&
      next.length == 1 &&
      next.first.hasImage;
}
