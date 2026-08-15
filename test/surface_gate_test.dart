import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:clustez/data/auth_controller.dart';
import 'package:clustez/data/feed_controller.dart';
import 'package:clustez/models/article.dart';
import 'package:clustez/utils/source_regions.dart';

/// Tests the SHIPPED applySurfaceGate — the admin per-surface switch-off:
///  - STRICT: an excluded source never appears, no fallback, even when
///    exclusion empties the surface or the source is also in the defaults
///  - user preference precedes ABSOLUTELY: any region scope or favorite
///    publishers means the whole gate is skipped

Article art(String source) => Article(
      id: source,
      title: 't',
      excerpt: 'e',
      image: 'https://example.com/i.jpg',
      source: source,
      publishedAt: '2026-08-09T00:00:00Z',
      readingMinutes: 1,
      categories: const [],
      impact: 'Medium',
      isBreaking: false,
      topics: const [],
      likeCount: 0,
      commentCount: 0,
    );

User userWith(Map<String, dynamic> meta) => User(
      id: 'qa-user',
      appMetadata: const {},
      userMetadata: meta,
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

List<String> gate(
  User? user,
  List<String> sources,
  List<String> defaults,
  List<String> excludes,
) {
  late List<Article> out;
  final probe = Provider<void>((ref) {
    out = applySurfaceGate(
        ref, [for (final s in sources) art(s)], defaults, excludes);
  });
  final container = ProviderContainer(
    overrides: [currentUserProvider.overrideWith((ref) => user)],
  );
  container.read(probe);
  container.dispose();
  return [for (final a in out) a.source];
}

void main() {
  const feed = ['The Jerusalem Post', 'CBS News', 'India Today'];

  group('no preference set — gate applies', () {
    final noPref = userWith(const {'email': 'x@y.z'});

    test('excluded source never appears on the surface', () {
      expect(gate(noPref, feed, const [], const ['The Jerusalem Post']),
          ['CBS News', 'India Today']);
    });

    test('signed-out user is also gated', () {
      expect(gate(null, feed, const [], const ['The Jerusalem Post']),
          ['CBS News', 'India Today']);
    });

    test('STRICT: off wins even when the source is in the defaults', () {
      expect(
          gate(noPref, feed, const ['The Jerusalem Post', 'CBS News'],
              const ['The Jerusalem Post']),
          ['CBS News']);
    });

    test('STRICT: no fallback — excluding everything empties the surface',
        () {
      expect(gate(noPref, feed, const [], feed), isEmpty);
    });

    test('STRICT: defaults with zero matches yield empty — no leak-through',
        () {
      expect(gate(noPref, feed, const ['Not In Feed'], const []), isEmpty);
    });

    test('STRICT: defaults show only the picks, never the mix', () {
      expect(gate(noPref, feed, const ['CBS News'], const []), ['CBS News']);
    });
  });

  group('user preference set — preference precedes, gate never runs', () {
    test('region scope skips exclusions entirely', () {
      final regionUser = userWith(const {
        'news_scope': 'region',
        'preferred_region': 'United States',
      });
      expect(gate(regionUser, feed, const [], const ['The Jerusalem Post']),
          feed);
    });

    test('favorite publishers skip exclusions entirely', () {
      final favUser = userWith(const {
        'preferred_sources': ['The Jerusalem Post'],
      });
      expect(gate(favUser, feed, const [], const ['The Jerusalem Post']),
          feed);
    });

    test('preference also overrides defaults + exclusions combined', () {
      final favUser = userWith(const {
        'preferred_sources': ['India Today'],
      });
      expect(gate(favUser, feed, const ['CBS News'], feed), feed);
    });
  });

  group('favorite publishers — STRICT allow-list on the feeds', () {
    List<String> shape(Map<String, dynamic> meta, List<String> sources) => [
          for (final a in shapeArticlesForUser(
              [for (final s in sources) art(s)],
              meta: meta))
            a.source
        ];

    test('ONLY favorited publishers appear — nothing else', () {
      expect(
          shape(const {
            'preferred_sources': ['CBS News']
          }, feed),
          ['CBS News']);
    });

    test('strict inside region scope too', () {
      const meta = {
        'news_scope': 'region',
        'preferred_region': 'United States',
        'preferred_sources': ['reuters'],
      };
      expect(shape(meta, const ['cbs news', 'reuters']), ['reuters']);
    });

    test('the location gate outranks favorites — an out-of-scope favorite '
        'can never surface', () {
      const meta = {
        'news_scope': 'region',
        'preferred_scopes': ['United Kingdom'],
        'preferred_sources': ['ndtv'], // Indian national, outside the scope
      };
      expect(shape(meta, const ['ndtv', 'bbc news']), isEmpty);
    });

    test('no favorites = unchanged scope feed', () {
      expect(shape(const {}, feed), feed);
    });
  });
}
