import 'package:clustez/models/article.dart';
import 'package:clustez/models/cluster.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Article.fromJson', () {
    test('parses a full payload', () {
      final a = Article.fromJson({
        'id': 'ext-1',
        'dbId': 'uuid-1',
        'title': 'Headline',
        'excerpt': 'Lead',
        'image': 'https://img/x.jpg',
        'source': 'Reuters',
        'sourceUrl': 'https://r.com/x',
        'publishedAt': '2026-06-03T10:00:00Z',
        'readingMinutes': 4,
        'categories': ['world-news', 'business'],
        'impact': 'High',
        'isBreaking': true,
        'summary': 'one line',
        'topics': ['a', 'b'],
        'likeCount': 3,
        'commentCount': 2,
      });
      expect(a.id, 'ext-1');
      expect(a.dbId, 'uuid-1');
      expect(a.impact, 'High');
      expect(a.isBreaking, isTrue);
      expect(a.categories, ['world-news', 'business']);
      expect(a.readingMinutes, 4);
      expect(a.hasImage, isTrue);
      expect(a.blurb, 'one line');
    });

    test('applies safe defaults for a minimal payload', () {
      final a = Article.fromJson({'id': 'x', 'title': 'T'});
      expect(a.impact, 'Low');
      expect(a.isBreaking, isFalse);
      expect(a.likeCount, 0);
      expect(a.categories, isEmpty);
      expect(a.hasImage, isFalse);
      expect(a.dbId, isNull);
    });

    test('blurb falls back to excerpt when summary is absent', () {
      final a = Article.fromJson({'id': 'x', 'excerpt': 'ex'});
      expect(a.blurb, 'ex');
    });
  });

  group('FeedPage.fromJson', () {
    test('parses items + cursor', () {
      final p = FeedPage.fromJson({
        'items': [
          {'id': 'a', 'title': 'A'},
          {'id': 'b', 'title': 'B'},
        ],
        'nextCursor': 'k:abc',
      });
      expect(p.items.length, 2);
      expect(p.items.first.id, 'a');
      expect(p.nextCursor, 'k:abc');
    });

    test('handles empty / null cursor', () {
      final p = FeedPage.fromJson({'items': [], 'nextCursor': null});
      expect(p.items, isEmpty);
      expect(p.nextCursor, isNull);
    });
  });

  group('cluster models', () {
    test('StoryCluster.fromJson', () {
      final c = StoryCluster.fromJson({
        'id': 'c1',
        'title': 'Story',
        'summary': 'sum',
        'categories': ['world-news'],
        'articleIds': ['a', 'b', 'c'],
        'tags': ['t'],
        'lastUpdated': '2026-06-03T10:00:00Z',
      });
      expect(c.id, 'c1');
      expect(c.sourceCount, 3);
    });

    test('TrendingTopic.fromJson', () {
      final t = TrendingTopic.fromJson(
          {'topic': 'World', 'slug': 'world-news', 'count': 12});
      expect(t.slug, 'world-news');
      expect(t.count, 12);
    });
  });
}
