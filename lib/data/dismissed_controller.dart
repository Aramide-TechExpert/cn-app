import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locally-dismissed ("not interested") article ids — mirrors the web's
/// localStorage dismissed list. Device-only; filtered out of feeds.
const _kDismissed = 'clusternews:dismissed';

class DismissedController extends Notifier<Set<String>> {
  SharedPreferences? _prefs;

  @override
  Set<String> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    state = (_prefs!.getStringList(_kDismissed) ?? const []).toSet();
  }

  Future<void> _ensure() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> dismiss(String id) async {
    if (id.isEmpty) return;
    state = {...state, id};
    await _ensure();
    await _prefs!.setStringList(_kDismissed, state.toList());
  }

  Future<void> undismiss(String id) async {
    state = {...state}..remove(id);
    await _ensure();
    await _prefs!.setStringList(_kDismissed, state.toList());
  }
}

final dismissedProvider =
    NotifierProvider<DismissedController, Set<String>>(DismissedController.new);
