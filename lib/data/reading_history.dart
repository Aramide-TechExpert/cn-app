import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/article.dart';

/// Local "Continue reading" history. Static + ValueNotifier so any tap site can
/// record without threading Riverpod, and the Home rail rebuilds via
/// ValueListenableBuilder. Capped, most-recent-first, deduped by id.
class ReadingHistory {
  ReadingHistory._();

  static const _key = 'reading_history_v1';
  static const _datesKey = 'reading_dates_v1';
  static const _max = 20;
  static SharedPreferences? _prefs;

  static final ValueNotifier<List<Article>> items =
      ValueNotifier<List<Article>>(const []);

  /// Consecutive days (ending today) on which a story was opened.
  static final ValueNotifier<int> streak = ValueNotifier<int>(0);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        items.value = (jsonDecode(raw) as List)
            .map((e) => Article.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // ignore corrupt cache
      }
    }
    streak.value = _computeStreak(_dates());
  }

  static void record(Article a) {
    if (a.id.isEmpty) return;
    final next = <Article>[
      a,
      ...items.value.where((x) => x.id != a.id),
    ].take(_max).toList();
    items.value = next;
    _prefs?.setString(_key, jsonEncode(next.map((x) => x.toJson()).toList()));

    final dates = _dates();
    final today = _dayKey(DateTime.now());
    if (!dates.contains(today)) {
      dates.add(today);
      _prefs?.setStringList(_datesKey, dates.toList());
      streak.value = _computeStreak(dates);
    }
  }

  static void clear() {
    items.value = const [];
    streak.value = 0;
    _prefs?.remove(_key);
    _prefs?.remove(_datesKey);
  }

  static Set<String> _dates() =>
      (_prefs?.getStringList(_datesKey) ?? const <String>[]).toSet();

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int _computeStreak(Set<String> dates) {
    if (dates.isEmpty) return 0;
    var day = DateTime.now();
    var count = 0;
    while (dates.contains(_dayKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }
}
