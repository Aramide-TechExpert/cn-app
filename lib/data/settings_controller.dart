import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/remote_settings.dart';

/// Local, device-only app preferences (theme + text size) — the app-side of the
/// web Settings "Appearance" section. Persisted with shared_preferences so the
/// choice survives restarts. (Account/email-digest prefs live in Supabase and
/// are handled in the Settings screen directly.)
class AppSettings {
  // firstRunSeen defaults true so returning users never flash the first-run
  // banner before prefs load; _load() flips it false only for genuinely new
  // users (no stored key).
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.textScale = 0.95, // pre-load flash matches the compiled Default
    this.firstRunSeen = true,
  });
  final ThemeMode themeMode;
  final double textScale;
  final bool firstRunSeen;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    bool? firstRunSeen,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        textScale: textScale ?? this.textScale,
        firstRunSeen: firstRunSeen ?? this.firstRunSeen,
      );
}

const _kThemeMode = 'clustez:themeMode';
const _kTextScale = 'clustez:textScale';
const _kFirstRun = 'clustez:firstRunSeen';

/// The ONLY text scales the app renders — an exact 5% ladder (owner
/// 2026-08-16): Small 0.9, Default 0.95, Large 1.0 (the design's base).
const kTextScalePresets = [0.9, 0.95, 1.0];

/// Snap any stored/incoming value to the nearest preset — enforcement for
/// values written by older ladders (1.0 was Default, 1.15/1.05 were Large)
/// or corrupted prefs. 1.0 stays 1.0 (it is a preset: today's Large).
double snapTextScale(double v) {
  var best = kTextScalePresets.first;
  for (final p in kTextScalePresets) {
    if ((v - p).abs() < (v - best).abs()) best = p;
  }
  return best;
}

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences? _prefs;

  @override
  AppSettings build() {
    // Re-derive when served config applies: a cold start races the config
    // fetch, so without this the COMPILED appearance defaults win over the
    // admin's (check mark on Default instead of the served small). Reload
    // re-reads local picks from disk — only no-pick fallbacks ever move.
    void onRemoteApplied() => _load();
    remoteConfigGeneration.addListener(onRemoteApplied);
    ref.onDispose(() => remoteConfigGeneration.removeListener(onRemoteApplied));
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      // No local pick yet → the Control panel's served default applies.
      themeMode: switch (_prefs!.getString(_kThemeMode) ?? remote.defaultTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      // No local pick yet → the Control panel's served default text size
      // applies (small|default|large mapped to the app presets). Stored
      // picks are SNAPPED to the current ladder — only the three preset
      // scales can ever render, whatever an old build (or bad data) wrote.
      textScale: switch (_prefs!.getDouble(_kTextScale)) {
        null => remote.defaultTextScale,
        final v => snapTextScale(v),
      },
      firstRunSeen: _prefs!.getBool(_kFirstRun) ?? false,
    );
  }

  Future<void> markFirstRunSeen() async {
    state = state.copyWith(firstRunSeen: true);
    await _ensure();
    await _prefs!.setBool(_kFirstRun, true);
  }

  Future<void> _ensure() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _ensure();
    await _prefs!.setString(_kThemeMode, mode.name);
  }

  Future<void> setTextScale(double scale) async {
    scale = snapTextScale(scale); // presets only, ever
    state = state.copyWith(textScale: scale);
    await _ensure();
    await _prefs!.setDouble(_kTextScale, scale);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
