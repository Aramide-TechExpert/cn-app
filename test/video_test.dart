import 'package:clustez/models/article.dart';
import 'package:clustez/utils/video.dart';
import 'package:flutter_test/flutter_test.dart';

Article _a({String source = 'BBC', String? url}) =>
    Article.fromJson({'source': source, 'sourceUrl': url});

void main() {
  group('isVideoArticle', () {
    test('youtube url', () {
      expect(isVideoArticle(_a(url: 'https://youtube.com/watch?v=abc')), isTrue);
    });
    test('youtu.be url', () {
      expect(isVideoArticle(_a(url: 'https://youtu.be/abc')), isTrue);
    });
    test('vimeo url', () {
      expect(isVideoArticle(_a(url: 'https://vimeo.com/123')), isTrue);
    });
    test('(YT) source label', () {
      expect(isVideoArticle(_a(source: 'Reuters (YT)')), isTrue);
    });
    test('plain article → false', () {
      expect(isVideoArticle(_a(url: 'https://bbc.com/news/x')), isFalse);
    });
    test('no url, plain source → false', () {
      expect(isVideoArticle(_a()), isFalse);
    });
  });
}
