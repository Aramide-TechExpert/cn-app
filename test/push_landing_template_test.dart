import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforcement guard for the LOCKED push-notification landing templates
/// (owner spec 2026-11-27 — "they should get their own page templates so they
/// don't divert away at all"). These are source-level invariants: if someone
/// edits a landing and breaks the contract, CI fails here with a message that
/// explains the rule — before it ever reaches a build the owner has to test.
///
/// The templates are documented in CLAUDE.md → "Push notification landings —
/// LOCKED templates". Keep this test and that section in lockstep.
void main() {
  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: 'missing $path');
    return f.readAsStringSync();
  }

  group('Single-push landing (StoryPage) is locked', () {
    late String src;
    setUpAll(() => src = read('lib/features/story/story_page.dart'));

    test('uses the shared landing chrome (header + footer)', () {
      expect(src, contains('landingHeader('),
          reason: 'StoryPage must use the shared landingHeader, not a '
              'hand-rolled SliverAppBar.');
      expect(src, contains('LandingBottomNav'),
          reason: 'StoryPage must show the shared footer tabs.');
    });

    test('has the 4-part body: hero → More News slider → compact pairs', () {
      expect(src, contains('newsFeedCard(0'),
          reason: 'The pushed story must render as the big hero card.');
      expect(src, contains("'More News'"),
          reason: 'The horizontal "More News" slider is required.');
      expect(src, contains('CompactCard('),
          reason: 'The slider rail uses CompactCard (homepage-Trending style).');
      expect(src, contains('feedPairRow('),
          reason: 'The remainder must be 2-up compact pairs — NO trailing big '
              'cover card (owner spec 2026-11-27).');
    });

    test('never routes through the Feed tab (DiscoverPage)', () {
      expect(src.contains('discover_page'), isFalse,
          reason: 'Push landings must NEVER import DiscoverPage.');
    });
  });

  group('Digest landing (DigestPage) is locked', () {
    late String src;
    setUpAll(() => src = read('lib/features/story/digest_page.dart'));

    test('uses the shared landing chrome (header + footer)', () {
      expect(src, contains('landingHeader('));
      expect(src, contains('LandingBottomNav'));
    });

    test('renders the Feed-tab rhythm (planFeedRows + pairs)', () {
      expect(src, contains('planFeedRows('));
      expect(src, contains('feedPairRow('));
    });

    test('never routes through the Feed tab (DiscoverPage)', () {
      expect(src.contains('discover_page'), isFalse);
    });
  });

  test('both landings are TOP-LEVEL routes, not inside the Feed shell branch',
      () {
    final router = read('lib/router.dart');
    // The /discover branch is the Feed tab. /story and /digest must be declared
    // OUTSIDE it (top-level), or a landing persists on the Feed stack and kills
    // the Feed tab (v4 + build 46/48 regression).
    final discoverIdx = router.indexOf("'/discover'");
    final storyIdx = router.indexOf("'/story/:id'");
    final digestIdx = router.indexOf("'/digest'");
    expect(storyIdx, greaterThan(-1), reason: '/story/:id route missing');
    expect(digestIdx, greaterThan(-1), reason: '/digest route missing');
    // Top-level routes are declared after the shell block in router.dart; the
    // exact ordering is asserted structurally in router tests. Here we just
    // guard that they are not glued next to the /discover branch definition.
    expect((storyIdx - discoverIdx).abs() > 40, isTrue,
        reason: '/story looks declared inside the /discover (Feed) branch — '
            'it must be a top-level route.');
    expect((digestIdx - discoverIdx).abs() > 40, isTrue,
        reason: '/digest looks declared inside the /discover (Feed) branch — '
            'it must be a top-level route.');
  });
}
