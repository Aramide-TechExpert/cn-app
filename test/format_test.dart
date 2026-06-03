import 'package:clustez/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

String _ago(Duration d) =>
    DateTime.now().subtract(d).toIso8601String();

void main() {
  group('timeAgo', () {
    test('recent → just now', () {
      expect(timeAgo(_ago(const Duration(seconds: 10))), 'just now');
    });
    test('minutes', () {
      expect(timeAgo(_ago(const Duration(minutes: 5))), '5m');
    });
    test('hours', () {
      expect(timeAgo(_ago(const Duration(hours: 3))), '3h');
    });
    test('days', () {
      expect(timeAgo(_ago(const Duration(days: 2))), '2d');
    });
    test('null / invalid → empty', () {
      expect(timeAgo(null), '');
      expect(timeAgo('not-a-date'), '');
    });
  });

  group('readTime', () {
    test('zero → Quick read', () => expect(readTime(0), 'Quick read'));
    test('n minutes', () => expect(readTime(4), '4 min read'));
  });

  group('initialOf', () {
    test('first letter uppercased', () => expect(initialOf('reuters'), 'R'));
    test('empty / null → bullet', () {
      expect(initialOf(''), '•');
      expect(initialOf(null), '•');
    });
  });

  group('hueFromString', () {
    test('deterministic', () {
      expect(hueFromString('BBC'), hueFromString('BBC'));
    });
    test('within range', () {
      final h = hueFromString('Reuters');
      expect(h, inInclusiveRange(0, 359));
    });
  });
}
