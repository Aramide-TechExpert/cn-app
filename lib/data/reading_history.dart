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
  static const _max = 20;
  static SharedPreferences? _prefs;

  static final ValueNotifier<List<Article>> items =
      ValueNotifier<List<Article>>(const []);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => Article.fromJson(e as Map<String, dynamic>))
          .toList();
      items.value = list;
    } catch (_) {
      // ignore corrupt cache
    }
  }

  static void record(Article a) {
    if (a.id.isEmpty) return;
    final next = <Article>[
      a,
      ...items.value.where((x) => x.id != a.id),
    ].take(_max).toList();
    items.value = next;
    _prefs?.setString(
        _key, jsonEncode(next.map((x) => x.toJson()).toList()));
  }

  static void clear() {
    items.value = const [];
    _prefs?.remove(_key);
  }
}
